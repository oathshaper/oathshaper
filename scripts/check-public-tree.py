#!/usr/bin/env python3
"""Check distributable source for local paths, private hosts and private files.

This is a hygiene guard, not a credential scanner. Run Gitleaks separately.
Binary payloads require the release audit; GLB JSON and compressed text are read.
Reports contain file/line/category only, never matching values.
"""
import argparse
import gzip
import io
import json
from pathlib import Path
import re
import struct
import subprocess
import tarfile

RULES = {
    "workstation_path": re.compile(r"/(?:Users|home)/[^/\s\"<>]+/|/Vol" r"umes/[^/\s\"<>]+/"),
    "private_hostname": re.compile(r"\b[\w-]+\.(?:local|internal|lan|ts\.net)\b", re.I),
    "private_network": re.compile(r"(?<![\d.])(?:10(?:\.\d{1,3}){3}|192\.168(?:\.\d{1,3}){2}|172\.(?:1[6-9]|2\d|3[01])(?:\.\d{1,3}){2}|100\.(?:6[4-9]|[7-9]\d|1[01]\d|12[0-7])(?:\.\d{1,3}){2})(?![\d.])"),
}
PRIVATE_PARTS = {".private", ".secrets", ".artifacts", ".agent-worktrees", ".git"}


def inspect(path, data, findings, coverage):
    lower = path.lower()
    parts = Path(lower).parts
    private_directory = any(p in PRIVATE_PARTS for p in parts)
    private_environment = any((p == ".env" or p.startswith(".env."))
                              and p not in {".env.example", ".env.sample"} for p in parts)
    if private_directory or private_environment:
        findings.append({"path": path, "line": 0, "category": "private_file"})
    if lower.endswith(".glb"):
        if data[:4] != b"glTF" or len(data) < 20:
            raise ValueError("Invalid GLB: " + path)
        length, kind = struct.unpack_from("<II", data, 12)
        if kind != 0x4e4f534a or length > len(data) - 20:
            raise ValueError("Invalid GLB JSON chunk: " + path)
        data = data[20:20 + length]
    elif lower.endswith(".tar.gz"):
        with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as archive:
            for member in archive:
                if Path(member.name).is_absolute() or ".." in Path(member.name).parts or not (member.isfile() or member.isdir()):
                    raise ValueError("Unsafe archive member in " + path)
                if member.isfile():
                    inspect(path + "!" + member.name, archive.extractfile(member).read(), findings, coverage)
        return
    elif lower.endswith(".gz"):
        data = gzip.decompress(data)
    if b"\0" in data:
        coverage["binary_payloads_excluded"] += 1
        return
    text = data.decode("utf-8", errors="replace")
    coverage["text_or_metadata_checked"] += 1
    for number, line in enumerate(text.splitlines(), 1):
        for category, pattern in RULES.items():
            if pattern.search(line):
                findings.append({"path": path, "line": number, "category": category})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    raw = subprocess.check_output(["git", "ls-files", "-co", "--exclude-standard", "-z"], cwd=root)
    paths = sorted({name.decode() for name in raw.split(b"\0") if name})
    findings = []
    coverage = {"text_or_metadata_checked": 0, "binary_payloads_excluded": 0}
    for name in paths:
        path = root / name
        if path.is_symlink():
            raise ValueError("Review source symlink before publication: " + name)
        if path.exists():
            inspect(name, path.read_bytes(), findings, coverage)
    report = {"files": len(paths), "coverage": coverage, "findings": findings}
    if args.report:
        args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    return bool(findings)


if __name__ == "__main__":
    raise SystemExit(main())
