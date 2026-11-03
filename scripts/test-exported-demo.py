#!/usr/bin/env python3
"""Exercise the extracted demo's resources with external acceptance drivers.

Requires an exported package and this exact source revision. Tests never run
against the editor project. Reports distinguish headless checks from rendering.
"""
import argparse
import importlib.util
import hashlib
import json
from pathlib import Path
import plistlib
import re
import subprocess
import tarfile
import time

ROOT = Path(__file__).resolve().parents[1]
SUITES = [
    ("playable_profiles_test", [], "PLAYABLE_PROFILES:"),
    ("flow_presentation_test", [], "FLOW_PRESENTATION:"),
    ("vanguard_presentation_test", [], "VANGUARD_PRESENTATION_TEST:"),
    ("vanguard_aim_test", [], "VANGUARD_AIM_TEST:"),
    ("chapter_route_test", [], "CHAPTER_ROUTE:"),
    ("garden_outcome_test", ["--style=flow"], "GARDEN_OUTCOME flow"),
    ("garden_outcome_test", ["--style=vanguard"], "GARDEN_OUTCOME vanguard"),
]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def classify_errors(log, headless):
    lines = log.splitlines()
    failures, diagnostics = [], []
    for index, line in enumerate(lines):
        if not re.match(r"(?:SCRIPT ERROR|ERROR):", line):
            continue
        # Godot 4.3's dummy mesh storage emits this during skinned-mesh teardown.
        # Keep the exact diagnostic visible; never exempt it on a real renderer.
        if (headless and line.strip() == 'ERROR: Parameter "m" is null.'
                and index + 1 < len(lines)
                and "servers/rendering/dummy/storage/mesh_storage.h:120" in lines[index + 1]):
            diagnostics.append(line + " " + lines[index + 1].strip())
        else:
            failures.append(line)
    return failures, diagnostics


def prepare_driver(name, directory):
    source = ROOT / "godot/tests" / (name + ".gd")
    text = source.read_text(encoding="utf-8")
    for dependency in set(re.findall(r'res://tests/([\w]+)\.gd', text)):
        prepare_driver(dependency, directory)
        text = text.replace("res://tests/" + dependency + ".gd",
                            (directory / (dependency + ".gd")).as_posix())
    # Redirect diagnostic files and any fixture saves to this run's directory.
    text = text.replace("/tmp/", directory.as_posix() + "/")
    text = text.replace("user://", directory.as_posix() + "/")
    if "extends SceneTree" in text:
        # Exercise normal audio teardown before a test-owned SceneTree exits.
        text = re.sub(r'(?m)^(\s*)quit\((1 if failures else 0|0 if failures.is_empty\(\) else 1)\)$',
                      r'\1await _release_test_finish(\2)', text)
        text += '''
func _release_test_finish(code: int) -> void:
\tvar audio = root.get_meta("oathshaper_audio", null)
\tif is_instance_valid(audio): audio._release_playback()
\tawait create_timer(.2).timeout
\tquit(code)
'''
    target = directory / (name + ".gd")
    target.write_text(text, encoding="utf-8")
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--package", type=Path)
    source.add_argument("--archives-dir", type=Path, help="Extract and test the single native archive in this directory")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--rendered", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if args.archives_dir:
        archives = list(args.archives_dir.glob("*.zip")) + list(args.archives_dir.glob("*.tar.gz"))
        if len(archives) != 1:
            raise RuntimeError("Expected exactly one native archive")
        archive = archives[0]
        expected = archive.with_name(archive.name + ".sha256").read_text().split()[0]
        if sha(archive) != expected:
            raise RuntimeError("Archive checksum mismatch")
        extract = output / "extracted"
        if extract.exists():
            raise RuntimeError("Use a new output directory for independent extraction")
        extract.mkdir()
        if archive.name.endswith(".tar.gz"):
            with tarfile.open(archive) as bundle:
                for member in bundle.getmembers():
                    if (Path(member.name).is_absolute() or ".." in Path(member.name).parts
                            or not (member.isfile() or member.isdir())):
                        raise RuntimeError("Unsafe archive member")
                bundle.extractall(extract)
        else:
            spec = importlib.util.spec_from_file_location("release", ROOT / "scripts/export-release.py")
            release = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(release)
            release.extract_zip(archive, extract)
        folders = list(extract.iterdir())
        if len(folders) != 1 or not folders[0].is_dir():
            raise RuntimeError("Expected one package directory")
        package = folders[0]
    else:
        package = args.package.resolve()
    manifest = json.loads((package / "BUILD-MANIFEST.json").read_text())
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    if manifest["source_commit"] != revision:
        raise RuntimeError("Acceptance source differs from the packaged source revision")
    for name, expected in manifest["files"].items():
        path = package / name
        if not path.resolve().is_relative_to(package) or sha(path) != expected:
            raise RuntimeError("Manifest mismatch: " + name)
    platform = manifest["platform"]
    if platform == "macos-universal":
        app = package / "Oathshaper.app"
        with (app / "Contents/Info.plist").open("rb") as stream:
            executable = app / "Contents/MacOS" / plistlib.load(stream)["CFBundleExecutable"]
    else:
        executable = package / ("Oathshaper.exe" if platform.startswith("windows") else "Oathshaper.x86_64")
    results = []
    skipped = []
    for suite, arguments, marker in SUITES:
        if suite == "vanguard_presentation_test" and not args.rendered:
            skipped.append({"suite": suite, "reason": "Pixel assertions require a real renderer"})
            continue
        label = suite + ("-" + arguments[0].split("=")[-1] if arguments else "")
        folder = output / label
        folder.mkdir(exist_ok=True)
        driver = prepare_driver(suite, folder)
        command = [str(executable), "--audio-driver", "Dummy"]
        if not args.rendered:
            command.append("--headless")
        command += ["--script", str(driver), "--", *arguments]
        started = time.monotonic()
        try:
            process = subprocess.run(command, cwd=package, capture_output=True,
                                     text=True, errors="replace", timeout=180)
            log, status = process.stdout + process.stderr, process.returncode
        except subprocess.TimeoutExpired as error:
            log = str(error.stdout or b"") + str(error.stderr or b"")
            status = 124
        (folder / "runtime.log").write_text(log, encoding="utf-8")
        plain = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", log)
        errors, diagnostics = classify_errors(plain, headless=not args.rendered)
        passed = status == 0 and marker in plain and not errors
        results.append({"suite": label, "passed": passed, "exit": status,
                        "seconds": round(time.monotonic() - started, 2), "errors": errors,
                        "headless_engine_diagnostics": diagnostics,
                        "driver_sha256": sha(driver),
                        "summary": [line for line in plain.splitlines() if marker in line]})
        print(label, "PASS" if passed else "FAIL", flush=True)
    report = {"source_commit": revision, "platform": platform,
              "executable_sha256": sha(executable), "manifest_files_verified": len(manifest["files"]),
              "rendered": args.rendered, "physical_controller": False, "audio_driver": "Dummy",
              "scope": "Packaged scene/rules/UI routes with fixture positioning; not a human hardware playtest.",
              "results": results, "skipped": skipped, "passed": all(row["passed"] for row in results)}
    (output / "acceptance.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
