#!/usr/bin/env python3
"""Prepare the reviewed community MLX conversion beside the original install."""
import argparse
import hashlib
from pathlib import Path
import subprocess

from huggingface_hub import snapshot_download

CODE_REVISION = "ca1e85fe9430179831e6bc6be790c332190a3866"
MODEL_REVISION = "7a59458c6a193af37a107fc2c0f6e7c03333b118"
PATCH_SHA256 = "abdec0e99f2ca1f610dafc32b255b28874f261d6fd20fa5c5a51ea7d3a565f00"


def digest(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, required=True, help="Original pinned ACE-Step checkout")
    parser.add_argument("--data", type=Path, required=True, help="Existing environment and official models")
    args = parser.parse_args()
    original = args.repo.resolve()
    target = original.with_name(original.name + "-mlx8")
    head = subprocess.check_output(["git", "-C", str(original), "rev-parse", "HEAD"], text=True).strip()
    if head != CODE_REVISION:
        raise SystemExit("The reviewed conversion requires ACE-Step commit " + CODE_REVISION)
    models = args.data.resolve() / "models-mlx8"
    snapshot_download("Audante/ACE-Step-1.5-mlx-8bit", revision=MODEL_REVISION,
                      local_dir=models, max_workers=2,
                      allow_patterns=["acestep-v15-turbo/*", "ace-step-mlx-quant.patch",
                                      "LICENSE*", "SHA256SUMS", "README.md"])
    patch_file = models / "ace-step-mlx-quant.patch"
    if digest(patch_file) != PATCH_SHA256:
        raise SystemExit("Conversion patch checksum mismatch")
    for line in (models / "SHA256SUMS").read_text().splitlines():
        expected, name = line.split(maxsplit=1)
        # Other variants and the planner are not part of this conversion. The
        # original planner is linked solely for ACE-Step's bundle preflight;
        # this audition never loads it.
        if name.startswith(("acestep-5Hz-", "acestep-v15-base/")):
            continue
        path = models / name.lstrip("*")
        # ACE-Step replaces checkpoint Python with code from its own pinned
        # checkout on initialization. Validate that replacement on repeat setup.
        if path.is_file() and path.suffix == ".py":
            canonical = original / "acestep/models/turbo" / path.name
            if digest(path) != expected and path.read_bytes() != canonical.read_bytes():
                raise SystemExit(f"Model code checksum mismatch: {path.name}")
        elif path.is_file() and digest(path) != expected:
            raise SystemExit(f"Checkpoint checksum mismatch: {name}")
    for name in ("vae", "Qwen3-Embedding-0.6B", "acestep-5Hz-lm-1.7B", "config.json"):
        source = args.data.resolve() / "models" / name
        if not source.exists():
            raise SystemExit(f"Official checkpoint component missing: {name}")
        destination = models / name
        if not destination.exists():
            destination.symlink_to(source, target_is_directory=source.is_dir())
    if not target.exists():
        subprocess.run(["git", "clone", "--no-hardlinks", str(original), str(target)], check=True)
    if subprocess.check_output(["git", "-C", str(target), "rev-parse", "HEAD"], text=True).strip() != CODE_REVISION:
        raise SystemExit("Existing MLX checkout has an unexpected revision")
    reverse = subprocess.run(["git", "-C", str(target), "apply", "--reverse", "--check", str(patch_file)],
                             capture_output=True)
    if reverse.returncode:
        subprocess.run(["git", "-C", str(target), "apply", "--check", str(patch_file)], check=True)
        subprocess.run(["git", "-C", str(target), "apply", str(patch_file)], check=True)
    print(f"Prepared {target}\nCheckpoints: {models}")


if __name__ == "__main__":
    main()
