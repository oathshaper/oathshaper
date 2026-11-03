#!/usr/bin/env python3
"""Run with ACE-Step's Python environment; models/cache live outside the game."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import resource
import subprocess
import sys
import time


def main():
    if os.environ.get("OATH_AUDIO_GUARDED") != "1":
        raise SystemExit("Use guarded_ace_step.py so resource checks and persistent logging run first.")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--data", type=Path, required=True)
    parser.add_argument("--seconds", type=float, default=30)
    parser.add_argument("--checkpoint-dir", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--quantized-mlx", action="store_true")
    args = parser.parse_args()
    args.data.mkdir(parents=True, exist_ok=True)
    checkpoints = args.checkpoint_dir or args.data / "models"
    os.environ["ACESTEP_CHECKPOINTS_DIR"] = str(checkpoints)
    os.environ["HF_HOME"] = str(args.data / "cache/huggingface")
    os.environ["TOKENIZERS_PARALLELISM"] = "false"
    os.environ["ACESTEP_SAVE_MEMORY"] = "1"
    os.environ["ACESTEP_NO_DOWNLOAD"] = "1"
    os.environ["HF_HUB_OFFLINE"] = "1"
    os.environ["ACESTEP_MLX_CACHE_GB"] = "0.125"
    if args.quantized_mlx:
        # The automatic 512-frame VAE window exhausted headroom on the 30 s
        # audition. Upstream supports smaller overlap/discard windows and fp16.
        os.environ["ACESTEP_MLX_VAE_CHUNK"] = "192"
        os.environ["ACESTEP_MLX_VAE_FP16"] = "1"
    # The venv's editable installation points at the original checkout. Select
    # the explicitly requested, pinned checkout before importing any ACE code.
    sys.path.insert(0, str(args.repo.resolve()))
    from acestep.handler import AceStepHandler
    from acestep.inference import GenerationParams, GenerationConfig, generate_music
    import mlx.core as mx
    import torch
    torch.set_num_threads(4)
    mps_fraction = .45 if args.quantized_mlx else .30
    mlx_gib = 6 if args.quantized_mlx else 4
    torch.mps.set_per_process_memory_fraction(mps_fraction)
    mx.set_memory_limit(mlx_gib * 1024 ** 3)
    mx.set_cache_limit(128 * 1024 ** 2)
    mx.set_wired_limit(512 * 1024 ** 2)
    output = args.output or args.data / "outputs"
    output.mkdir(exist_ok=True)
    report = {"upstream_commit": subprocess.check_output(["git", "-C", str(args.repo), "rev-parse", "HEAD"], text=True).strip(),
              "platform": platform.platform(), "torch": torch.__version__, "mps_available": torch.backends.mps.is_available(),
              "model": "acestep-v15-turbo", "lm_enabled": False, "seed": 20261028,
              "checkpoint_dir": str(checkpoints), "quantized_mlx": args.quantized_mlx,
              "limits": {"mps_recommended_fraction": mps_fraction, "mlx_gib": mlx_gib, "mlx_cache_mib": 128, "mlx_wired_mib": 512}}
    if args.quantized_mlx:
        spec = json.loads((checkpoints / "acestep-v15-turbo/mlx_dit.json").read_text())
        if spec.get("bits") != 8:
            raise RuntimeError("This trial expects the reviewed 8-bit MLX decoder")
        report["quantization"] = spec
        patch = checkpoints / "ace-step-mlx-quant.patch"
        report["patch_sha256"] = hashlib.sha256(patch.read_bytes()).hexdigest()
        if report["patch_sha256"] != "abdec0e99f2ca1f610dafc32b255b28874f261d6fd20fa5c5a51ea7d3a565f00":
            raise RuntimeError("Unexpected MLX conversion patch; review it before running")
        subprocess.run(["git", "-C", str(args.repo), "apply", "--reverse", "--check", str(patch)], check=True)
        report["conversion_revision"] = "7a59458c6a193af37a107fc2c0f6e7c03333b118"
        report["vae"] = {"mlx_chunk_frames": 192, "dtype": "float16"}
    # MLX supports the diffusion/VAE path with CPU conditioning. This avoids
    # copying the remaining PyTorch weights to Metal on a busy unified-memory
    # Mac; CPU/GPU placement otherwise still duplicates buffers during loading.
    torch_device = "cpu" if args.quantized_mlx else "mps"
    report["torch_device"] = torch_device
    handler = AceStepHandler()
    start = time.perf_counter()
    status, ok = handler.initialize_service(project_root=str(args.repo), config_path="acestep-v15-turbo",
                                            device=torch_device, use_mlx_dit=True, offload_to_cpu=not args.quantized_mlx)
    report.update(initialization_seconds=time.perf_counter() - start, initialization_ok=ok, initialization_status=status)
    if ok:
        params = GenerationParams(caption=(
            "Instrumental acoustic fantasy harbor exploration music at dusk. Gentle wooden flute melody, "
            "warm bowed cello, delicate plucked lute and sparse hand percussion. Small intimate ensemble, "
            "quiet reflective mood with a hopeful resolution, restrained dynamics, clear space for dialogue, "
            "no vocals, no choir, no electronic drums."),
            instrumental=True, lyrics="[Instrumental]", bpm=84, keyscale="D minor", timesignature="4",
            duration=args.seconds, seed=20261028, thinking=False, use_cot_caption=False,
            use_cot_language=False, use_cot_metas=False, inference_steps=8)
        report["parameters"] = params.to_dict()
        start = time.perf_counter()
        result = generate_music(handler, None, params, GenerationConfig(batch_size=1, use_random_seed=False, audio_format="wav"), str(output))
        report.update(generation_seconds=time.perf_counter() - start, success=result.success, error=result.error,
                      status=result.status_message, audios=[])
        for item in result.audios:
            path = Path(item["path"])
            import numpy as np
            import soundfile as sf
            samples, sample_rate = sf.read(path, always_2d=True)
            finite = bool(np.isfinite(samples).all())
            rms = float(np.sqrt(np.mean(samples ** 2)))
            report["audios"].append({"path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                                     "seconds": len(samples) / sample_rate, "sample_rate": sample_rate,
                                     "channels": samples.shape[1], "finite": finite, "rms": rms,
                                     "peak": float(np.max(np.abs(samples))),
                                     "clipped_samples": int((np.abs(samples) >= 1).sum())})
            if not finite or rms < 1e-6:
                report.update(success=False, error="Generated audio contains invalid samples or silence")
    report.update(mlx_dit=handler.use_mlx_dit, mlx_vae=handler.use_mlx_vae,
                  peak_process_rss_bytes=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
                  mlx_peak_bytes=mx.get_peak_memory())
    (output / "trial.json").write_text(json.dumps(report, indent=2, default=str) + "\n")
    print(json.dumps(report, indent=2, default=str))
    if not ok or not report.get("success"):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
