#!/usr/bin/env python3
"""Produce attributed dialogue WAVs with the configured local Kyutai worker.

Does not install software, start a network service, or modify the voice runtime. Only small
voice embeddings are downloaded; model files are read from the runtime's pinned cache.
"""
import argparse
from array import array
from collections import defaultdict
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import queue
import re
import subprocess
import sys
import threading
import time
import urllib.request
import wave

ROOT = Path(__file__).resolve().parents[1]
MODEL = "kyutai/tts-1.6b-en_fr"
MODEL_REVISION = "f65439609986c392cb12df63938abcc550c3fb15"
VOICE_REVISION = "323332d33f997de8394f24a193e1a76df720e01a"
VOICE_SUFFIX = ".1e68beda@240.safetensors"
SAMPLE_RATE = 24000
VOICE_CARD = f"https://huggingface.co/kyutai/tts-voices/blob/{VOICE_REVISION}/README.md"
CAST = {
    "Crimson Raider": {"voice": "voice-donations/dwp_enhanced.wav", "label": "Voice donation - dwp (AU, m)", "license": "CC0-1.0"},
    "Corsair": {"voice": "vctk/p228_023.wav", "label": "Anna (f, conversation)", "license": "CC-BY-4.0"},
    "Mara": {"voice": "vctk/p339_023.wav", "label": "Jane (f, conversation)", "license": "CC-BY-4.0"},
    "Clerk": {"voice": "vctk/p231_023.wav", "label": "VCTK 231 (UK, f)", "license": "CC-BY-4.0"},
    "Ivo": {"voice": "vctk/p226_023.wav", "label": "VCTK 226 (UK, m)", "license": "CC-BY-4.0"},
    "Vendor": {"voice": "voice-donations/dwp_enhanced.wav", "label": "Voice donation - dwp (AU, m)", "license": "CC0-1.0"},
    "Filing Cabinet": {"voice": "vctk/p255_023.wav", "label": "VCTK 255 (UK, m)", "license": "CC-BY-4.0"},
    "Narrator": {"voice": "vctk/p255_023.wav", "label": "VCTK 255 (UK, m)", "license": "CC-BY-4.0"},
}
AUDITION_TEXT = "The harbor lights will hold until morning. I'll meet you by the garden gate."
WORKER_ADAPTER = "reset-language-model-cache-before-each-utterance-v1"


def run_worker():
    """Reset model-owned context without changing the existing worker."""
    import runpy
    from moshi_mlx.models.tts import TTSModel
    generate = TTSModel.generate

    def generate_fresh(self, *args, **kwargs):
        # LmGen owns a new sequence, but these caches live on the shared Lm.
        # Mimi's separate stream reset is already performed by voice runtime.
        for cache in self.lm.transformer_cache:
            cache.reset()
        return generate(self, *args, **kwargs)

    TTSModel.generate = generate_fresh
    worker = sys.argv[2]
    sys.argv = [worker, *sys.argv[3:]]
    runpy.run_path(worker, run_name="__main__")


def file_hash(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".partial")
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    temporary.replace(path)


def split_text(text):
    """Keep every word while honoring the worker's 500-character input bound."""
    text = text.strip()
    if "\n\n" in text:
        return [chunk for phrase in text.split("\n\n") for chunk in split_text(phrase)]
    chunks = []
    while len(text) > 500:
        boundary = max(text.rfind(mark, 0, 490) for mark in (". ", "! ", "? ", "; "))
        boundary = boundary + 1 if boundary >= 100 else text.rfind(" ", 0, 490)
        if boundary <= 0:
            raise ValueError("A word exceeds the worker's input bound")
        chunks.append(text[:boundary].strip())
        text = text[boundary:].strip()
    if text:
        chunks.append(text)
    if not chunks:
        raise ValueError("Empty spoken text")
    return chunks


def prepare_cache(runtime_root, work):
    source = runtime_root / "tmp/hf-cache/hub" / "models--kyutai--tts-1.6b-en_fr/snapshots" / MODEL_REVISION
    destination = work / "hf-cache/hub/models--kyutai--tts-1.6b-en_fr/snapshots" / MODEL_REVISION
    if not source.is_dir():
        raise RuntimeError("Pinned voice runtime model snapshot is unavailable; no model download attempted")
    destination.mkdir(parents=True, exist_ok=True)
    hashes = {}
    for item in sorted(source.iterdir()):
        if item.is_file():
            target = destination / item.name
            if not target.exists():
                target.symlink_to(item.resolve())
            if target.resolve() != item.resolve():
                raise RuntimeError("Unexpected model cache target")
            hashes[item.name] = file_hash(item)
    expected_names = {"config.json", "dsm_tts_1e68beda@240.safetensors", "tokenizer_spm_8k_en_fr_audio.model", "tokenizer-e351c8d8-checkpoint125.safetensors"}
    if not expected_names.issubset(hashes):
        raise RuntimeError("Pinned model snapshot is incomplete")
    metadata_path = work / "voice-repository.json"
    if not metadata_path.exists():
        url = f"https://huggingface.co/api/models/kyutai/tts-voices/revision/{VOICE_REVISION}?blobs=true"
        with urllib.request.urlopen(url, timeout=30) as response:
            write_json(metadata_path, json.load(response))
    metadata = json.loads(metadata_path.read_text())
    if metadata["sha"] != VOICE_REVISION:
        raise RuntimeError("Voice repository revision mismatch")
    files = {entry["rfilename"]: entry for entry in metadata["siblings"]}
    embeddings = {}
    for voice in sorted({entry["voice"] for entry in CAST.values()}):
        name = voice + VOICE_SUFFIX
        expected = files[name]["lfs"]["sha256"]
        target = work / "hf-cache/hub/models--kyutai--tts-voices/snapshots" / VOICE_REVISION / name
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists():
            print("Downloading voice embedding", voice, flush=True)
            with urllib.request.urlopen(f"https://huggingface.co/kyutai/tts-voices/resolve/{VOICE_REVISION}/{name}", timeout=60) as response:
                target.write_bytes(response.read())
        if file_hash(target) != expected:
            raise RuntimeError("Voice embedding checksum mismatch: " + voice)
        embeddings[voice] = expected
    return {"model_files_sha256": hashes, "voice_embeddings_sha256": embeddings}


class Worker:
    def __init__(self, runtime_root, work, voice):
        self.runtime_root, self.work, self.voice = runtime_root, work, voice
        self.events = queue.Queue()
        self.process = None
        self.log = None

    def __enter__(self):
        self.work.joinpath("logs").mkdir(parents=True, exist_ok=True)
        self.log = (self.work / "logs" / (self.voice.replace("/", "-") + ".log")).open("a")
        env = dict(os.environ, HF_HOME=str(self.work / "hf-cache"), HF_HUB_OFFLINE="1", PYTHONDONTWRITEBYTECODE="1")
        self.process = subprocess.Popen([
            str(self.runtime_root / "tmp/kyutai-venv/bin/python"), "-u",
            str(Path(__file__).resolve()), "_worker",
            str(self.runtime_root / "src/providers/kyutai_mlx_worker.py"),
            "--repo", MODEL, "--model-revision", MODEL_REVISION,
            "--voice", self.voice, "--voice-revision", VOICE_REVISION, "--quantize", "8",
        ], cwd=self.work, env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=self.log, text=True)
        def collect():
            for line in self.process.stdout:
                try:
                    self.events.put(json.loads(line))
                except json.JSONDecodeError:
                    continue
            self.events.put({"type": "worker_exit"})
        threading.Thread(target=collect, daemon=True).start()
        try:
            event = self.events.get(timeout=180)
            if event.get("type") != "ready" or event.get("sampleRateHz") != SAMPLE_RATE:
                raise RuntimeError("Worker did not become ready: " + repr(event))
        except Exception:
            self.__exit__(None, None, None)
            raise
        print("Ready", self.voice, flush=True)
        return self

    def synthesize(self, identity, text):
        import base64
        self.process.stdin.write(json.dumps({"id": identity, "text": text}) + "\n")
        self.process.stdin.flush()
        frames = []
        deadline = time.monotonic() + 300
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError("Synthesis exceeded five minutes")
            event = self.events.get(timeout=remaining)
            if event.get("type") in {"worker_exit", "error"}:
                raise RuntimeError("Worker failed: " + repr(event))
            if event.get("id") != identity:
                raise RuntimeError("Unexpected worker response identity")
            if event.get("type") == "frame":
                if event["seq"] != len(frames):
                    raise RuntimeError("Missing or reordered PCM frame")
                frame = base64.b64decode(event["pcm16le"], validate=True)
                if len(frame) != 3840:
                    raise RuntimeError("Unexpected 80 ms PCM frame size")
                frames.append(frame)
            elif event.get("type") == "done":
                if event["frames"] != len(frames):
                    raise RuntimeError("Frame count mismatch")
                return b"".join(frames)

    def __exit__(self, *_):
        if self.process is not None:
            self.process.stdin.close()
            try:
                self.process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                self.process.terminate()
                try:
                    self.process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    self.process.kill()
                    self.process.wait()
            self.process.stdout.close()
        if self.log is not None:
            self.log.close()


def finish_pcm(raw):
    samples = array("h", raw)
    if sys.byteorder != "little":
        samples.byteswap()
    if not samples:
        raise RuntimeError("No PCM samples generated")
    frame_samples = SAMPLE_RATE // 50
    rms = [math.sqrt(sum(x * x for x in samples[i:i + frame_samples]) / len(samples[i:i + frame_samples]))
           for i in range(0, len(samples), frame_samples)]
    audible = [i for i, value in enumerate(rms) if value >= 200]
    if len(audible) < 15:
        raise RuntimeError("Insufficient non-silent speech")
    first = max(0, audible[0] * frame_samples - int(SAMPLE_RATE * .12))
    last = min(len(samples), (audible[-1] + 1) * frame_samples + int(SAMPLE_RATE * .18))
    trimmed = samples[first:last]
    duration = len(trimmed) / SAMPLE_RATE
    if not .4 <= duration <= 180:
        raise RuntimeError("Implausible output duration")
    peak = max(abs(x) for x in trimmed)
    clipped_fraction = sum(abs(x) >= 32760 for x in trimmed) / len(trimmed)
    if clipped_fraction > .001:
        raise RuntimeError("Generated PCM is clipped")
    gain = min(4.0, 0.85 * 32767 / peak)
    output = array("h", (round(x * gain) for x in trimmed))
    fade = min(int(SAMPLE_RATE * .008), len(output) // 2)
    for i in range(fade):
        output[i] = round(output[i] * i / fade)
        output[-1 - i] = round(output[-1 - i] * i / fade)
    stats = {"sample_rate_hz": SAMPLE_RATE, "channels": 1, "sample_width_bytes": 2,
             "duration_seconds": round(duration, 3), "raw_duration_seconds": round(len(samples) / SAMPLE_RATE, 3),
             "raw_sha256": hashlib.sha256(raw).hexdigest(), "raw_peak": peak,
             "raw_clipped_fraction": clipped_fraction, "gain": round(gain, 5),
             "trim_start_samples": first, "trim_end_samples": len(samples) - last,
             "active_20ms_frames": len(audible), "raw_20ms_frames": len(rms),
             "objective_qc": "passed", "human_listening": "not_performed"}
    if sys.byteorder != "little":
        output.byteswap()
    return output.tobytes(), stats


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["auditions", "batch"])
    parser.add_argument("--update-script", action="store_true", help="Reuse verified unchanged clips after a script revision; archive previous provenance")
    parser.add_argument("--runtime-root", type=Path, help="Existing local Kyutai runtime checkout; required for synthesis")
    parser.add_argument("--work-dir", type=Path, default=Path("/tmp/oathshaper-voice-production"))
    args = parser.parse_args()
    if args.runtime_root is None:
        parser.error("--runtime-root is required; see docs/voice-production.md")
    runtime_root, work = args.runtime_root.resolve(), args.work_dir.resolve()
    work.mkdir(parents=True, exist_ok=True)
    source_path = ROOT / "godot/content/voice_script.json"
    source_hash = file_hash(source_path)
    script = json.loads(source_path.read_text())
    output = ROOT / "godot/assets/audio/generated"
    output.mkdir(parents=True, exist_ok=True)
    record_path = output / ("audition-provenance.json" if args.mode == "auditions" else "production-provenance.json")
    entries = []
    if args.mode == "auditions":
        for speaker, voice in CAST.items():
            if speaker == "Narrator":
                continue
            entries.append({"key": "audition-" + speaker.lower().replace(" ", "-"), "speaker": speaker,
                            "spoken_text": AUDITION_TEXT,
                            "path": "res://assets/audio/generated/auditions/" + speaker.lower().replace(" ", "-") + ".wav"})
    else:
        entries = script["lines"]
        audition = json.loads((output / "audition-provenance.json").read_text())
        for speaker in CAST:
            if speaker == "Narrator":
                continue
            # A new role may share an already auditioned voice embedding.
            matches = [x for x in audition["clips"].values() if x["voice"] == CAST[speaker]["voice"]]
            if not matches or not all(x["objective_qc"] == "passed" for x in matches):
                raise RuntimeError("Current cast needs objective audition QC before batch")
    for entry in entries:
        if entry["speaker"] not in CAST:
            raise RuntimeError("Unmapped speaker: " + entry["speaker"])
        split_text(entry["spoken_text"])
        if args.mode == "batch":
            key = hashlib.sha256((entry["speaker"] + "\n" + entry["lookup_text"]).encode()).hexdigest()
            asset = hashlib.sha256((entry["speaker"] + "\n" + entry["lookup_text"] + "\n" + entry["spoken_text"]).encode()).hexdigest()
            if entry["key"] != key or entry["path"] != f"res://assets/audio/generated/{asset}.wav":
                raise RuntimeError("Voice manifest text identity mismatch")
    cache_evidence = prepare_cache(runtime_root, work)
    record = {"schema": 1, "model": MODEL, "model_revision": MODEL_REVISION, "model_license": "CC-BY-4.0",
              "voice_revision": VOICE_REVISION, "voice_license_source": VOICE_CARD,
              "cast_label_source": "https://kyutai.org/tts/", "cast": CAST,
              "runtime": "moshi-mlx 0.2.12; MLX 0.26.5", "quantization_bits": 8, "seed": 299792458,
              "worker_sha256": file_hash(runtime_root / "src/providers/kyutai_mlx_worker.py"),
              "generator_sha256": file_hash(Path(__file__)), "worker_adapter": WORKER_ADAPTER,
              "voice_script_sha256": source_hash, "created_utc": datetime.now(timezone.utc).isoformat(),
              "assessment": "Objective PCM checks only; human listening and performance acceptance not performed.",
              **cache_evidence, "clips": {}}
    if record_path.exists():
        previous = json.loads(record_path.read_text())
        stable = ("model_revision", "voice_revision", "worker_sha256", "worker_adapter")
        if any(record["cast"].get(role) != voice for role, voice in previous["cast"].items()):
            raise RuntimeError("An existing role's voice changed; regenerate its audition first")
        for key in stable:
            if previous[key] != record[key]:
                raise RuntimeError("Existing provenance belongs to different inputs: " + key)
        if previous["voice_script_sha256"] == source_hash and previous["generator_sha256"] == record["generator_sha256"]:
            record = previous
        elif args.update_script and args.mode == "batch":
            prior_hash = file_hash(record_path)
            archive = output / "history" / (prior_hash + ".json")
            archive.parent.mkdir(exist_ok=True)
            if not archive.exists():
                archive.write_bytes(record_path.read_bytes())
            record["previous_provenance_sha256"] = prior_hash
            for entry in entries:
                old = previous["clips"].get(entry["key"])
                if old and all(old.get(k) == entry[k] for k in ("speaker", "spoken_text", "lookup_text", "path")):
                    destination = ROOT / "godot" / entry["path"].removeprefix("res://")
                    if file_hash(destination) != old["sha256"]:
                        raise RuntimeError("Existing audio differs from provenance")
                    record["clips"][entry["key"]] = {**old, "reused_from_provenance_sha256": prior_hash}
            write_json(record_path, record)
        else:
            raise RuntimeError("Voice script or generator changed; use --update-script to reconcile verified clips")
    groups = defaultdict(list)
    for entry in entries:
        groups[CAST[entry["speaker"]]["voice"]].append(entry)
    for voice, lines in groups.items():
        pending = []
        for entry in lines:
            previous = record["clips"].get(entry["key"])
            destination = ROOT / "godot" / entry["path"].removeprefix("res://")
            if previous is not None:
                if file_hash(destination) != previous["sha256"]:
                    raise RuntimeError("Existing audio differs from provenance")
            elif destination.exists():
                raise RuntimeError("Refusing to overwrite audio without matching provenance")
            else:
                pending.append((entry, destination))
        if not pending:
            continue
        with Worker(runtime_root, work, voice) as worker:
            for entry, destination in pending:
                began = time.monotonic()
                chunks = split_text(entry["spoken_text"])
                pcm_chunks = [worker.synthesize(entry["key"] + f"-{i}", chunk) for i, chunk in enumerate(chunks)]
                pause = .55 if "\n\n" in entry["spoken_text"] else .12
                raw = (b"\0\0" * int(SAMPLE_RATE * pause)).join(pcm_chunks)
                pcm, stats = finish_pcm(raw)
                word_count = len(entry["spoken_text"].split())
                if word_count >= 8 and word_count / stats["duration_seconds"] > 8:
                    raise RuntimeError("Audio is too short for the requested text")
                destination.parent.mkdir(parents=True, exist_ok=True)
                temporary = destination.with_suffix(".partial.wav")
                with wave.open(str(temporary), "wb") as stream:
                    stream.setnchannels(1)
                    stream.setsampwidth(2)
                    stream.setframerate(SAMPLE_RATE)
                    stream.writeframes(pcm)
                temporary.replace(destination)
                record["clips"][entry["key"]] = {**entry, "voice": voice, "voice_license": CAST[entry["speaker"]]["license"],
                    "sha256": file_hash(destination), "chunks": chunks,
                    "generation_seconds": round(time.monotonic() - began, 3), **stats}
                write_json(record_path, record)
                print(entry["speaker"], entry["key"][:16], stats["duration_seconds"], "seconds; QC passed", flush=True)
    if file_hash(source_path) != source_hash:
        raise RuntimeError("Voice script changed during generation; reconcile before use")
    print(f"Completed {len(record['clips'])} {args.mode} clips", flush=True)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "_worker":
        run_worker()
    else:
        main()
