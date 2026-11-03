#!/usr/bin/env python3
"""Verify native CI downloads, then publish only those bytes to an existing tag.

prepare is offline. publish uses gh/GH_TOKEN, never moves tags or replaces assets.
"""
import argparse
import contextlib
import hashlib
import json
from pathlib import Path, PurePosixPath
import plistlib
import re
import shutil
import stat
import subprocess
import tarfile
from urllib.parse import quote
import zipfile

PLATFORMS = {
    "linux": ("linux-x86_64", ".tar.gz", "Oathshaper.x86_64"),
    "windows": ("windows-x86_64", ".zip", "Oathshaper.exe"),
    "macos": ("macos-universal", ".zip", None),
}
SUITES = {"playable_profiles_test", "flow_presentation_test", "vanguard_presentation_test",
          "vanguard_aim_test", "chapter_route_test", "garden_outcome_test-flow",
          "garden_outcome_test-vanguard"}


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def digest_stream(stream):
    result = hashlib.sha256()
    for block in iter(lambda: stream.read(1024 * 1024), b""):
        result.update(block)
    return result.hexdigest()


def digest(path):
    with path.open("rb") as stream:
        return digest_stream(stream)


def relative(name):
    path = PurePosixPath(name)
    require(bool(name) and not path.is_absolute() and ".." not in path.parts
            and "\\" not in name and ":" not in name and str(path) == name,
            "Unsafe or noncanonical archive path")
    return path


def verify_archive(archive, platform, revision):
    label, extension, executable = PLATFORMS[platform]
    stem = f"oathshaper-demo-{label}-{revision[:12]}"
    require(archive.name == stem + extension, "Unexpected archive name")
    checksum = archive.with_name(archive.name + ".sha256")
    fields = checksum.read_text().split()
    actual = digest(archive)
    require(fields == [actual, archive.name], "Archive checksum/name mismatch")
    with contextlib.ExitStack() as stack:
        if extension == ".zip":
            bundle = stack.enter_context(zipfile.ZipFile(archive))
            members = bundle.infolist()
            names = [m.filename for m in members if not m.is_dir()]
            for member in members:
                relative(member.filename.rstrip("/"))
                kind = stat.S_IFMT(member.external_attr >> 16)
                require(kind in (0, stat.S_IFREG, stat.S_IFDIR), "Archive links/devices are forbidden")
            read = bundle.open
        else:
            bundle = stack.enter_context(tarfile.open(archive))
            members = bundle.getmembers()
            names = [m.name for m in members if m.isfile()]
            for member in members:
                relative(member.name.rstrip("/"))
                require(member.isfile() or member.isdir(), "Archive links/devices are forbidden")
            read = bundle.extractfile
        require(len(names) == len(set(names)), "Duplicate archive member")
        require(all(n.startswith(stem + "/") for n in names), "Unexpected package root")
        with read(stem + "/BUILD-MANIFEST.json") as stream:
            manifest = json.load(stream)
        require(manifest["source_commit"] == revision and manifest["platform"] == label,
                "Manifest source/platform mismatch")
        require(manifest["tracked_worktree_dirty"] is False and manifest["native_smoke"] == "passed",
                "Dirty or untested export")
        files = manifest["files"]
        require(isinstance(files, dict) and files, "Empty manifest")
        for name in files:
            relative(name)
        expected = {stem + "/" + n for n in files} | {stem + "/BUILD-MANIFEST.json"}
        require(set(names) == expected, "Unmanifested or missing archive files")
        require({"licenses/LICENSE", "licenses/ASSET-LICENSE.md",
                 "licenses/godot/assets/audio/generated/ATTRIBUTION.md"} <= files.keys(),
                "Required code/voice notices missing")
        for name, sha in files.items():
            with read(stem + "/" + name) as stream:
                require(digest_stream(stream) == sha, "Packaged file hash mismatch: " + name)
        if platform == "macos":
            with read(stem + "/Oathshaper.app/Contents/Info.plist") as stream:
                executable = "Oathshaper.app/Contents/MacOS/" + plistlib.load(stream)["CFBundleExecutable"]
        require(executable in files, "Native executable is missing")
    return {"platform": label, "archive": archive.name, "sha256": actual,
            "bytes": archive.stat().st_size, "executable_sha256": files[executable],
            "manifest_files": len(files)}


def verify_acceptance(report, platform, revision, package):
    require(report["source_commit"] == revision and report["platform"] == package["platform"],
            "Acceptance source/platform mismatch")
    require(report["executable_sha256"] == package["executable_sha256"], "Different executable was tested")
    require(report["manifest_files_verified"] == package["manifest_files"], "Incomplete manifest verification")
    require(report["passed"] is True, "Acceptance failed")
    rendered = report["rendered"]
    require(isinstance(rendered, bool), "Invalid renderer coverage")
    # Hosted macOS uses headless checks; a matching local rendered receipt is
    # also valid. Linux must retain its Mesa pixel checks.
    require(platform == "macos" or rendered is (platform == "linux"), "Unexpected renderer coverage")
    skipped = set() if rendered else {"vanguard_presentation_test"}
    require({r["suite"] for r in report["skipped"]} == skipped, "Unexpected skipped suites")
    expected = SUITES - skipped
    results = report["results"]
    require({r["suite"] for r in results} == expected and len(results) == len(expected),
            "Missing or duplicate acceptance suites")
    require(all(r["passed"] is True and r["exit"] == 0 and not r["errors"] for r in results),
            "A suite failed or reported engine errors")
    return {"rendered": report["rendered"], "skipped": sorted(skipped),
            "summaries": [line for r in results for line in r["summary"]],
            "headless_engine_diagnostics": sum(len(r.get("headless_engine_diagnostics", [])) for r in results)}


def prepare(artifacts, revision, tag, run_url, output):
    require(re.fullmatch(r"[0-9a-f]{40}", revision), "Expected a full Git commit ID")
    subprocess.run(["git", "check-ref-format", "refs/tags/" + tag], check=True)
    require(not output.exists(), "Use a fresh release output directory")
    packages, paths = [], []
    for platform, (label, extension, _) in PLATFORMS.items():
        folder = artifacts / f"oathshaper-demo-{platform}-{revision}"
        archive = folder / f"oathshaper-demo-{label}-{revision[:12]}{extension}"
        package = verify_archive(archive, platform, revision)
        evidence = artifacts / f"oathshaper-acceptance-{platform}-{revision}" / "acceptance.json"
        package["acceptance"] = verify_acceptance(json.loads(evidence.read_text()), platform, revision, package)
        packages.append(package)
        paths += [archive, archive.with_name(archive.name + ".sha256")]
    output.mkdir(parents=True)
    for path in paths:
        shutil.copy2(path, output / path.name)
    receipt = {"source_commit": revision, "tag": tag, "workflow_run": run_url, "packages": packages}
    (output / "release-manifest.json").write_text(json.dumps(receipt, indent=2) + "\n")
    testing = [f"# Demo {tag}", "", f"Source: `{revision}`", "", f"CI run: {run_url}", "",
               "| Download | Automated acceptance |", "| --- | --- |"]
    for package in packages:
        mode = "rendered scene/UI routes" if package["acceptance"]["rendered"] else "headless scene/rules routes; pixel suite skipped"
        testing.append(f"| {package['platform']} | {mode} |")
    testing += ["", "Linux uses Mesa software rendering on Ubuntu 22.04. Windows runs on Server 2022.",
                "macOS builds both CPU slices; only the runner's host architecture executes tests.",
                "Test audio uses the Dummy driver. Physical controllers, Steam Deck hardware,",
                "clean consumer Windows installs, and listening quality are not certified by these jobs.",
                "", "macOS is ad-hoc signed, not notarized. Windows is unsigned.",
                "Keep extracted files together and preserve the bundled licenses and voice credits.",
                "See docs/install.md in the tagged source for installation and controls.", ""]
    (output / "TESTING.md").write_text("\n".join(testing))
    (output / "SHA256SUMS").write_text("".join(f"{p['sha256']}  {p['archive']}\n" for p in packages))
    payloads = {p.name: digest(p) for p in sorted(output.iterdir())}
    (output / "publish-plan.json").write_text(json.dumps({"tag": tag, "revision": revision, "files": payloads}, indent=2) + "\n")
    print(f"Verified {len(packages)} native archives and acceptance receipts at {revision}")


def gh(*args):
    return subprocess.check_output(["gh", *args], text=True).strip()


def release_for_tag(repository, tag):
    result = subprocess.run(["gh", "api", f"repos/{repository}/releases/tags/{quote(tag, safe='')}"],
                            capture_output=True, text=True)
    if result.returncode and "(HTTP 404)" in result.stderr:
        return None
    require(result.returncode == 0, "Could not read release metadata")
    return json.loads(result.stdout)


def remote_revision(repository, tag):
    node = json.loads(gh("api", f"repos/{repository}/git/ref/tags/{quote(tag, safe='')}"))["object"]
    for _ in range(8):
        if node["type"] == "commit":
            return node["sha"]
        require(node["type"] == "tag", "Release tag does not resolve to a commit")
        node = json.loads(gh("api", f"repos/{repository}/git/tags/{node['sha']}"))["object"]
    raise RuntimeError("Too many nested tags")


def pending_assets(release, files):
    existing = {asset["name"]: asset for asset in release["assets"]}
    pending = []
    for name, sha in files.items():
        if name not in existing:
            pending.append(name)
        else:
            require(existing[name].get("digest") == "sha256:" + sha and existing[name]["state"] == "uploaded",
                    "Existing asset differs or has no verifiable digest; refusing replacement: " + name)
    require(not pending or not release.get("immutable", False), "Published release is immutable; use a new tag")
    return pending


def publish(prepared, repository):
    require(re.fullmatch(r"[\w.-]+/[\w.-]+", repository), "Invalid repository")
    plan = json.loads((prepared / "publish-plan.json").read_text())
    tag, revision, files = plan["tag"], plan["revision"], plan["files"]
    require(re.fullmatch(r"[0-9a-f]{40}", revision), "Invalid source revision")
    subprocess.run(["git", "check-ref-format", "refs/tags/" + tag], check=True)
    expected = {"release-manifest.json", "TESTING.md", "SHA256SUMS"}
    for label, extension, _ in PLATFORMS.values():
        name = f"oathshaper-demo-{label}-{revision[:12]}{extension}"
        expected.update((name, name + ".sha256"))
    require(set(files) == expected, "Incomplete publication plan")
    for name, sha in files.items():
        require(len(relative(name).parts) == 1 and digest(prepared / name) == sha, "Prepared payload changed")
    receipt = json.loads((prepared / "release-manifest.json").read_text())
    require(receipt["source_commit"] == revision and receipt["tag"] == tag, "Publication identity mismatch")
    require(remote_revision(repository, tag) == revision, "Remote tag moved; refusing publication")
    release = release_for_tag(repository, tag)
    if release is None:
        gh("release", "create", tag, "--repo", repository, "--verify-tag", "--draft", "--prerelease",
           "--title", "Oathshaper demo: " + tag, "--notes-file", str(prepared / "TESTING.md"))
        release = release_for_tag(repository, tag)
        require(release is not None, "Draft release creation was not confirmed")
    pending = pending_assets(release, files)
    for name in pending:
        # No --clobber: existing bytes are never removed or replaced.
        gh("release", "upload", tag, str(prepared / name), "--repo", repository)
    release = release_for_tag(repository, tag)
    require(release is not None and not pending_assets(release, files), "Uploaded assets were not verified")
    require(remote_revision(repository, tag) == revision, "Remote tag moved during upload")
    if release["draft"]:
        gh("release", "edit", tag, "--repo", repository, "--draft=false")
    final = release_for_tag(repository, tag)
    require(final is not None and not final["draft"] and not pending_assets(final, files), "Publication not confirmed")
    print(final["html_url"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    check = commands.add_parser("prepare")
    check.add_argument("--artifacts", type=Path, required=True)
    check.add_argument("--revision", required=True)
    check.add_argument("--tag", required=True)
    check.add_argument("--run-url", required=True)
    check.add_argument("--output", type=Path, required=True)
    upload = commands.add_parser("publish")
    upload.add_argument("--prepared", type=Path, required=True)
    upload.add_argument("--repository", required=True)
    args = vars(parser.parse_args())
    globals()[args.pop("command")](**args)


if __name__ == "__main__":
    main()
