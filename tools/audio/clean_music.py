#!/usr/bin/env python3
"""Make a conservative, loudness-matched music EQ audition without inference."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess
import tempfile

import numpy as np
import soundfile as sf


EQ = ("highpass=f=30:p=2:r=f64,"
      "equalizer=f=240:t=q:w=0.7:g=-2.5:r=f64,"
      "equalizer=f=1900:t=q:w=0.7:g=2:r=f64,"
      "highshelf=f=5000:t=q:w=0.707:g=2.5:r=f64")


def measure(path):
    result = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-i", str(path),
         "-af", "loudnorm=I=-20:TP=-2:LRA=11:print_format=json", "-f", "null", "-"],
        capture_output=True, text=True, check=True)
    # Only input measurements are used; loudnorm's dynamically processed output
    # is discarded. Audition files receive fixed gain, never dynamic compression.
    raw = json.loads(result.stderr[result.stderr.rfind("{"):result.stderr.rfind("}") + 1])
    numbers = {"lufs": float(raw["input_i"]), "true_peak_db": float(raw["input_tp"]),
               "loudness_range_lu": float(raw["input_lra"])}
    if not all(math.isfinite(v) for v in numbers.values()):
        raise ValueError("Source is silent or has invalid loudness measurements")
    return numbers


def render(source, destination, filters, codec="pcm_s24le"):
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-nostdin", "-n",
                    "-i", str(source), "-af", filters, "-c:a", codec, str(destination)], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--output", type=Path, required=True, help="New audition directory")
    args = parser.parse_args()
    source = args.source.resolve()
    before = hashlib.sha256(source.read_bytes()).hexdigest()
    args.output.mkdir(parents=True, exist_ok=False)
    original = args.output / "01-original-matched.wav"
    cleaned = args.output / "02-clarity.wav"
    comparison = args.output / "03-original-then-clarity.wav"
    input_metrics = measure(source)
    with tempfile.TemporaryDirectory(prefix="eq-", dir=args.output) as temporary:
        raw = Path(temporary) / "eq-float.wav"
        render(source, raw, EQ, "pcm_f32le")
        eq_metrics = measure(raw)
        target = min(-20.0, *(m["lufs"] - 2.0 - m["true_peak_db"]
                             for m in (input_metrics, eq_metrics)))
        render(source, original, f"volume={target - input_metrics['lufs']:.4f}dB:precision=double")
        render(raw, cleaned, f"volume={target - eq_metrics['lufs']:.4f}dB:precision=double")
    report = {"source_name": source.name, "source_sha256": before, "eq": EQ,
              "target_lufs": target, "input": input_metrics, "outputs": [],
              "processing": "Fixed EQ and gain only; no denoising, compression, exciter or model generation.",
              "listening_status": "Awaiting user comparison; EQ cannot reconstruct missing detail or undo all generated distortion."}
    source_info = sf.info(source)
    clips = []
    for path in (original, cleaned):
        samples, rate = sf.read(path, always_2d=True)
        if (not np.isfinite(samples).all() or len(samples) != source_info.frames
                or rate != source_info.samplerate or samples.shape[1] != source_info.channels):
            raise ValueError("Output format, duration or samples failed verification")
        metrics = measure(path)
        if abs(metrics["lufs"] - target) > .1 or metrics["true_peak_db"] > -1.9:
            raise ValueError("Loudness matching or headroom check failed")
        report["outputs"].append(dict(name=path.name, sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                                     seconds=len(samples) / rate, sample_rate=rate,
                                     channels=samples.shape[1], subtype=sf.info(path).subtype, **metrics))
        # Same 10 s passage in both halves. Five ms edge ramps prevent the
        # comparison edit itself from introducing a click; full files are intact.
        clip = samples[:min(len(samples), rate * 10)].copy()
        fade = min(round(rate * .005), len(clip) // 2)
        clip[:fade] *= np.linspace(0, 1, fade)[:, None]
        clip[-fade:] *= np.linspace(1, 0, fade)[:, None]
        clips.append(clip)
    silence = np.zeros((rate, source_info.channels))
    sf.write(comparison, np.concatenate((clips[0], silence, clips[1])), rate, subtype="PCM_24")
    report["comparison"] = {"file": comparison.name, "order": "Original 10 s, silence 1 s, clarity 10 s"}
    if hashlib.sha256(source.read_bytes()).hexdigest() != before:
        raise ValueError("Source file changed during audition preparation")
    (args.output / "cleanup.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
