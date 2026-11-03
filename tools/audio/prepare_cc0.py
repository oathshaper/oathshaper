#!/usr/bin/env python3
"""Curate previously downloaded CC0 packs; ffmpeg is required for loop encoding."""
import argparse
import array
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "godot/assets/audio/cc0"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def loop(source, destination, start, seconds):
    rate, channels, overlap = 44100, 2, 2 * 44100
    raw = subprocess.check_output([
        "ffmpeg", "-v", "error", "-ss", str(start), "-i", str(source),
        "-t", str(seconds), "-ar", str(rate), "-ac", str(channels),
        "-f", "f32le", "pipe:1",
    ])
    samples = array.array("f", raw)
    n = overlap * channels
    seam = array.array("f", (samples[-n + i] * (1 - (i // 2) / overlap)
                             + samples[i] * ((i // 2) / overlap) for i in range(n)))
    result = samples[n:-n] + seam
    # Both recordings become comparable quiet beds; runtime supplies mix gain.
    gain = 0.75 / max(abs(x) for x in result)
    result = array.array("f", (x * gain for x in result))
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(rate),
                    "-ac", "2", "-i", "pipe:0", "-c:a", "libvorbis", "-q:a", "5",
                    str(destination)], input=result.tobytes(), check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cache", type=Path)
    cache = parser.parse_args().cache
    packs = {
        "interface-sounds": ["click_001", "select_001", "error_001", "maximize_001", "minimize_001"],
        "rpg-audio": ["knifeSlice", "knifeSlice2", "drawKnife1", "doorOpen_1", "doorClose_1"],
        "sci-fi-sounds": [f"laserSmall_{i:03}" for i in range(3)],
        "impact-sounds": [f"impactMetal_light_{i:03}" for i in range(3)]
        + [f"impactBell_heavy_{i:03}" for i in range(2)]
        + [f"footstep_{surface}_{i:03}" for surface in ("wood", "concrete") for i in range(4)],
    }
    sources = {s["id"]: s for s in json.loads((cache / "sources.json").read_text())}
    manifest = {"license": "CC0-1.0", "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
                "retrieved": "2026-10-28", "assets": []}
    OUT.mkdir(parents=True, exist_ok=True)
    for pack, names in packs.items():
        folder = OUT / pack
        folder.mkdir(exist_ok=True)
        license_text = (cache / pack / "License.txt").read_text()
        (folder / "License.txt").write_text("\n".join(line.rstrip() for line in license_text.splitlines()) + "\n")
        for name in names:
            src, dst = cache / pack / "Audio" / (name + ".ogg"), folder / (name + ".ogg")
            shutil.copy2(src, dst)
            manifest["assets"].append({"file": str(dst.relative_to(OUT)), "source": sources[pack],
                                       "source_file": "Audio/" + src.name, "sha256": digest(dst), "processing": "unchanged"})
    for sid, name, start, duration in [("573192", "gentle_water", 10, 64), ("254125", "harbor", 0, 60)]:
        dst = OUT / (name + ".ogg")
        loop(cache / (sid + ".mp3"), dst, start, duration)
        manifest["assets"].append({"file": dst.name, "source": sources[sid], "sha256": digest(dst),
            "processing": {"trim_start_seconds": start, "input_seconds": duration, "wrap_crossfade_seconds": 2,
                           "peak": 0.75, "sample_rate": 44100, "codec": "Vorbis q5", "channels": 2}})
    (OUT / "provenance.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Prepared {len(manifest['assets'])} CC0 assets in {OUT}")


if __name__ == "__main__":
    main()
