#!/usr/bin/env python3
"""Build a native demo candidate without changing the working Godot project.

Uses only Python's standard library, Rust/rustup, and platform build tools.
Downloads are pinned to Godot 4.3's published SHA512-SUMS.txt.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import plistlib
import re
import shutil
import subprocess
import tarfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
GODOT_COMMIT = "77dcf97d82cbfe4e4615475fa52ca03da645dbd8"
RELEASE_URL = "https://github.com/godotengine/godot-builds/releases/download/4.3-stable/"
TEMPLATES = "Godot_v4.3-stable_export_templates.tpz"
DOWNLOADS = {
    TEMPLATES: "476366caf0fd45a8f24136cf9cf1dc0bc2b96f7c82d53e5f82200b55aefd07b286d283fd6f1ce29e0de70648c5a51d3b12f96c6d4fafd4e8c4878ecda6406d6a",
    "Godot_v4.3-stable_linux.x86_64.zip": "fd52bb4ba8acc30ca5accd1c566d470ad7282f891ccc0995dfafabcf92bcf76280ce182bf9d80ebd885f3ed2165d01e1fc3f2928436b15498dfbd98656c2a45a",
    "Godot_v4.3-stable_macos.universal.zip": "8a556637aa6b83a60473decdb43a448b214f31fd13318b6f7ba2ebc4cca4e40d1f7a933330ce40afa8d72273ef6a6f3a0e3b0f0abf8e1be3fe4f03119cae62c2",
    "Godot_v4.3-stable_win64.exe.zip": "ad09b7e19949327700dfbe64e35880a2a08091c0751277f5cc21b915e5df9b4fe93fb43c50d6bdfb9d16b46168592491aa698e0d2dbe9f92132e163dd77b97e1",
}
PLATFORMS = {
    "linux": {
        "host": "Linux", "label": "linux-x86_64", "preset": "Linux x86_64",
        "targets": ["x86_64-unknown-linux-gnu"], "lib": "liboathshaper_godot.so",
        "editor_zip": "Godot_v4.3-stable_linux.x86_64.zip",
        "editor": "Godot_v4.3-stable_linux.x86_64", "template": "linux_release.x86_64",
        "export": "Oathshaper.x86_64",
    },
    "windows": {
        "host": "Windows", "label": "windows-x86_64", "preset": "Windows x86_64",
        "targets": ["x86_64-pc-windows-msvc"], "lib": "oathshaper_godot.dll",
        "editor_zip": "Godot_v4.3-stable_win64.exe.zip",
        "editor": "Godot_v4.3-stable_win64_console.exe", "template": "windows_release_x86_64.exe",
        "export": "Oathshaper.exe",
    },
    "macos": {
        "host": "Darwin", "label": "macos-universal", "preset": "macOS Universal",
        "targets": ["aarch64-apple-darwin", "x86_64-apple-darwin"], "lib": "liboathshaper_godot.dylib",
        "editor_zip": "Godot_v4.3-stable_macos.universal.zip",
        "editor": "Godot.app/Contents/MacOS/Godot", "template": "macos.zip",
        "export": "Oathshaper.app",
    },
}


def run(args, *, godot=False, env=None, timeout=1800):
    print("+", " ".join(str(arg) for arg in args), flush=True)
    result = subprocess.run([str(arg) for arg in args], cwd=ROOT, env=env,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, errors="replace", timeout=timeout)
    print(result.stdout, end="", flush=True)
    result.check_returncode()
    # Godot can report script/import failures while returning exit status zero.
    plain_output = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", result.stdout)
    if godot and re.search(r"^(?:SCRIPT ERROR|ERROR):", plain_output, re.MULTILINE):
        raise RuntimeError("Godot reported an error; see output above")
    return result.stdout.strip()


def digest(path, algorithm="sha256"):
    value = hashlib.new(algorithm)
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def download(url, destination, expected, algorithm="sha512"):
    destination.parent.mkdir(parents=True, exist_ok=True)
    if not destination.exists():
        print("Downloading", destination.name, flush=True)
        temporary = destination.with_suffix(destination.suffix + ".partial")
        with urllib.request.urlopen(url, timeout=120) as response, temporary.open("wb") as output:
            shutil.copyfileobj(response, output)
        temporary.replace(destination)
    if digest(destination, algorithm) != expected:
        raise RuntimeError(f"Checksum mismatch: {destination}; remove it before retrying")


def extract_zip(archive, destination, members=None):
    with zipfile.ZipFile(archive) as source:
        for member in members or source.namelist():
            info = source.getinfo(member)
            target = (destination / member).resolve()
            if not target.is_relative_to(destination.resolve()):
                raise RuntimeError("Archive path escaped extraction directory")
            source.extract(info, destination)
            mode = (info.external_attr >> 16) & 0o777
            if mode and os.name != "nt":
                target.chmod(mode)


def install_godot(config, work):
    tools = work / "tools"
    editor_archive = tools / config["editor_zip"]
    download(RELEASE_URL + editor_archive.name, editor_archive, DOWNLOADS[editor_archive.name])
    editor_dir = tools / "editor"
    extract_zip(editor_archive, editor_dir)
    editor = editor_dir / config["editor"]
    if os.name != "nt":
        editor.chmod(0o755)
    templates_archive = tools / TEMPLATES
    download(RELEASE_URL + TEMPLATES, templates_archive, DOWNLOADS[TEMPLATES])
    template_dir = tools / "export"
    extract_zip(templates_archive, template_dir, ["templates/" + config["template"]])
    return editor, template_dir / "templates" / config["template"]


def tracked_paths():
    data = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT)
    return [Path(name.decode()) for name in data.split(b"\0") if name]


def clean_source_revision(expected=None):
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    changes = subprocess.check_output(["git", "status", "--porcelain", "--untracked-files=normal"], cwd=ROOT)
    if changes or (expected is not None and revision != expected):
        raise RuntimeError("Release source must remain clean at the captured revision; use an isolated checkout")
    return revision


def release_rust_flags(work, target):
    """Keep panic/source locations useful without embedding builder home paths."""
    prefixes = [(Path.home(), "/local"),
                (Path(os.environ.get("CARGO_HOME", Path.home() / ".cargo")), "/cargo"),
                (work, "/build"), (ROOT, ".")]
    flags = [f"--remap-path-prefix={path.resolve()}={replacement}" for path, replacement in prefixes]
    if target == "x86_64-pc-windows-msvc":
        flags += ["-C", "target-feature=+crt-static"]
    return flags


def copy_file(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)


def checked_release_source(path):
    """Apply the same source boundary to game files and bundled notices."""
    if path.is_absolute() or ".." in path.parts:
        raise RuntimeError(f"Release source must be project-relative: {path}")
    parts = [part.lower() for part in path.parts]
    if (any(part == ".env" or part.startswith(".env.") or part in
            {".secrets", ".private", ".artifacts", ".agent-worktrees"} for part in parts)
            or path.name.lower() == "export_credentials.cfg"
            or path.suffix.lower() in {".key", ".p12", ".pfx", ".jks", ".keystore", ".mobileprovision"}):
        raise RuntimeError(f"Private configuration must not be staged: {path}")
    source = ROOT / path
    if source.resolve() != ROOT.resolve() / path:
        raise RuntimeError(f"Release source must not be a symlink: {path}")
    return source


def stage_project(paths, project):
    """Copy tracked game sources, rejecting local credentials and symlinks."""
    for path in paths:
        if path.parts[0] != "godot" or any(part.lower() in {".godot", "bin", "user-data"} for part in path.parts):
            continue
        copy_file(checked_release_source(path), project / path.relative_to("godot"))


def local_notice_paths(paths):
    """Keep licenses and asset provenance beside the binary, including donors."""
    for path in paths:
        name = path.name.upper()
        license_name = name.startswith(("LICENSE", "LICENCE", "COPYING", "COPYRIGHT", "NOTICE", "OFL"))
        root_notice = len(path.parts) == 1 and any(word in name for word in ("LICENSE", "NOTICE", "ATTRIBUTION", "CREDITS"))
        asset_scope = path.parts[:2] == ("godot", "assets")
        donor_scope = path.parts[:4] == ("tools", "rigging", "sources", "quaternius")
        provenance = name.endswith(("PROVENANCE.JSON", "MANIFEST.JSON"))
        history = path.parts[:5] == ("godot", "assets", "audio", "generated", "history") and path.suffix == ".json"
        if root_notice or ((asset_scope or donor_scope) and (license_name or name.endswith(".MD") or provenance or history)):
            checked_release_source(path)
            yield path


def legal_notices(package, paths, env, target):
    notices = package / "licenses"
    for path in local_notice_paths(paths):
        copy_file(ROOT / path, notices / path)
    for name, expected in {
        "LICENSE.txt": "b0435e3b3e4e55238f05f4b306f30524a1b2e20147810d436eaa554fa6855c80",
        "COPYRIGHT.txt": "7d27f1b25c53ccf2304e3dd05ed8e6fc957d3e9be079512fac784b1b6441aecd",
    }.items():
        download(f"https://raw.githubusercontent.com/godotengine/godot/{GODOT_COMMIT}/{name}",
                 notices / "godot-engine" / name, expected, "sha256")
    metadata = json.loads(subprocess.check_output(
        ["cargo", "+1.95.0", "metadata", "--locked", "--format-version", "1", "--filter-platform", target],
        cwd=ROOT, env=env))
    nodes = {node["id"]: node for node in metadata["resolve"]["nodes"]}
    runtime = {crate["id"] for crate in metadata["packages"] if crate["name"] == "oathshaper-godot"}
    pending = list(runtime)
    while pending:
        for dep in nodes[pending.pop()]["deps"]:
            if any(kind["kind"] is None for kind in dep["dep_kinds"]) and dep["pkg"] not in runtime:
                runtime.add(dep["pkg"])
                pending.append(dep["pkg"])
    dependencies = []
    for crate in metadata["packages"]:
        entry = {key: crate.get(key) for key in ("name", "version", "license", "source", "repository")}
        entry["normal_dependency"] = crate["id"] in runtime
        dependencies.append(entry)
        godot_mpl = crate["license"] == "MPL-2.0" and crate["repository"] == "https://github.com/godot-rust/gdext"
        if crate["source"] is None or (crate["id"] not in runtime and not godot_mpl):
            continue
        crate_root = Path(crate["manifest_path"]).parent
        if godot_mpl:
            download("https://raw.githubusercontent.com/godot-rust/gdext/v0.2.4/License.txt",
                     notices / "rust" / f"{crate['name']}-{crate['version']}" / "License.txt",
                     "66a3107d5ad6a058aab753eaac2047ccb2ed0e39465dd0fe5844da3e300d5172", "sha256")
            # Supply the exact unmodified crate source alongside MPL-covered binaries.
            crate_archive = crate_root.parent.parent.parent / "cache" / crate_root.parent.name / f"{crate['name']}-{crate['version']}.crate"
            copy_file(crate_archive, notices / "rust-source" / crate_archive.name)
            continue
        license_files = set()
        for candidate in crate_root.iterdir():
            if candidate.name.lower().startswith(("license", "licence", "copying", "copyright", "notice")):
                if candidate.is_file():
                    license_files.add(candidate)
                elif candidate.is_dir():
                    license_files.update(p for p in candidate.rglob("*") if p.is_file())
        if crate.get("license_file"):
            license_files.add(crate_root / crate["license_file"])
        if not license_files:
            raise RuntimeError(f"Missing bundled license text for {crate['name']} {crate['version']}")
        for source in license_files:
            copy_file(source, notices / "rust" / f"{crate['name']}-{crate['version']}" / source.relative_to(crate_root))
    (notices / "rust-dependencies.json").write_text(json.dumps(dependencies, indent=2) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=PLATFORMS, required=True)
    parser.add_argument("--work-dir", type=Path, required=True, help="Dedicated disposable build directory outside the repository")
    parser.add_argument("--output", type=Path, required=True, help="Directory for archives and checksums")
    args = parser.parse_args()
    config = PLATFORMS[args.platform]
    if platform.system() != config["host"]:
        parser.error("Build on the matching native OS; cross-platform export alone does not compile the extension")
    work, output = args.work_dir.resolve(), args.output.resolve()
    if work.is_relative_to(ROOT) or ROOT.is_relative_to(work):
        parser.error("--work-dir must be outside the repository and must not contain it")
    if output.is_relative_to(work / "package") or output.is_relative_to(work / "project"):
        parser.error("--output must not be inside the staged project or package")
    work.mkdir(parents=True, exist_ok=True)
    output.mkdir(parents=True, exist_ok=True)
    revision = clean_source_revision()
    editor, template = install_godot(config, work)
    version = run([editor, "--version"])
    if version != "4.3.stable.official.77dcf97d8":
        raise RuntimeError(f"Unexpected Godot version: {version}")
    env = dict(os.environ, CARGO_TARGET_DIR=str(work / "cargo-target"))
    run(["rustup", "target", "add", "--toolchain", "1.95.0", *config["targets"]])
    run(["cargo", "+1.95.0", "test", "--locked", "-p", "oathshaper-core"], env=env)
    # Flags belong to the release recipe, not the builder's interactive shell.
    for key in ("RUSTFLAGS", "CARGO_ENCODED_RUSTFLAGS", "CARGO_BUILD_RUSTFLAGS"):
        env.pop(key, None)
    libraries = []
    for target in config["targets"]:
        env.pop("CARGO_TARGET_" + target.upper().replace("-", "_") + "_RUSTFLAGS", None)
        # A TOML array preserves paths containing spaces. Target-scoped flags
        # keep Windows static CRT settings off host-side proc-macro builds.
        flags = f"target.{target}.rustflags=" + json.dumps(release_rust_flags(work, target))
        run(["cargo", "+1.95.0", "build", "--locked", "--release", "-p", "oathshaper-godot", "--target", target,
             "--config", flags], env=env)
        libraries.append(work / "cargo-target" / target / "release" / config["lib"])
    project, package = work / "project", work / "package"
    for directory in (project, package):
        if directory.exists():
            shutil.rmtree(directory)
        directory.mkdir()
    paths = tracked_paths()
    stage_project(paths, project)
    presets = project / "export_presets.cfg"
    preset_text = presets.read_text(encoding="utf-8")
    for mode in ("debug", "release"):
        preset_text = preset_text.replace(f'custom_template/{mode}=""',
                                          f'custom_template/{mode}="{template.as_posix()}"')
    presets.write_text(preset_text, encoding="utf-8")
    if args.platform == "macos":
        # The universal exporter requires Apple Silicon's texture import variant.
        settings = project / "project.godot"
        settings.write_text(settings.read_text(encoding="utf-8").replace(
            "[rendering]", "[rendering]\ntextures/vram_compression/import_etc2_astc=true"), encoding="utf-8")
    staged_library = project / "bin" / config["lib"]
    staged_library.parent.mkdir()
    if args.platform == "macos":
        run(["lipo", "-create", *libraries, "-output", staged_library])
        # The linker stores the output path in LC_ID_DYLIB independently of
        # Rust source-path remapping. Use a portable ID before import/signing.
        run(["install_name_tool", "-id", "@rpath/" + config["lib"], staged_library])
        run(["codesign", "--force", "--sign", "-", staged_library])
        run(["lipo", staged_library, "-verify_arch", "arm64", "x86_64"])
    else:
        shutil.copy2(libraries[0], staged_library)
    run([editor, "--headless", "--path", project, "--import"], godot=True)
    exported = package / config["export"]
    run([editor, "--headless", "--path", project, "--export-release", config["preset"], exported], godot=True)
    bundled_libraries = list(package.rglob(config["lib"]))
    if len(bundled_libraries) != 1 or digest(bundled_libraries[0]) != digest(staged_library):
        # macOS export re-signs the copied dylib, changing its digest.
        if args.platform != "macos" or len(bundled_libraries) != 1:
            raise RuntimeError("Export did not include the compiled native extension")
    executable = exported
    if args.platform == "macos":
        with (exported / "Contents/Info.plist").open("rb") as stream:
            executable = exported / "Contents/MacOS" / plistlib.load(stream)["CFBundleExecutable"]
        run(["lipo", bundled_libraries[0], "-verify_arch", "arm64", "x86_64"])
    if os.name != "nt":
        executable.chmod(0o755)
    smoke = work / "startup-smoke.gd"
    smoke.write_text('''extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var scene = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
    root.add_child(scene)
    for frame in 5: await process_frame
    var audio = root.get_meta("oathshaper_audio", null)
    if audio == null:
        push_error("Application audio lifecycle did not start")
        quit(1)
        return
    print("EXPORTED_STARTUP: main scene and audio lifecycle ready")
    # Exercise the same graceful close used by the native window.
    audio.quit_game()
''', encoding="utf-8")
    run([executable, "--headless", "--audio-driver", "Dummy", "--script", smoke], godot=True, timeout=120)
    legal_notices(package, paths, env, config["targets"][0])
    clean_source_revision(revision)
    (package / "README.txt").write_text(
        "Oathshaper: Lantern Quay demo\n\n"
        "Keep all extracted files together. Start Oathshaper from this folder.\n"
        "Windows: run Oathshaper.exe. Linux: run ./Oathshaper.x86_64.\n"
        "macOS: open Oathshaper.app. This candidate is ad-hoc signed, not notarized;\n"
        "macOS may require Open Anyway in System Settings > Privacy & Security.\n"
        "Native startup smoke checks do not establish full gameplay acceptance.\n"
        "See licenses/ for code, engine, dependency, font, and asset provenance.\n", encoding="utf-8")
    manifest = {"source_commit": revision, "tracked_worktree_dirty": False, "platform": config["label"],
                "godot": version, "rust": run(["rustc", "+1.95.0", "--version"]), "godot_rust": "0.2.4",
                "windows_static_crt": args.platform == "windows",
                "native_targets": config["targets"], "native_smoke": "passed", "signed_for_distribution": False,
                "files": {str(p.relative_to(package)).replace(os.sep, "/"): digest(p) for p in sorted(package.rglob("*")) if p.is_file()}}
    (package / "BUILD-MANIFEST.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    stem = f"oathshaper-demo-{config['label']}-{revision[:12]}"
    if args.platform == "linux":
        archive = output / (stem + ".tar.gz")
        with tarfile.open(archive, "w:gz") as bundle:
            bundle.add(package, arcname=stem)
    else:
        archive = output / (stem + ".zip")
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
            for path in sorted(package.rglob("*")):
                if path.is_file():
                    bundle.write(path, str(Path(stem) / path.relative_to(package)))
    (output / (archive.name + ".sha256")).write_text(f"{digest(archive)}  {archive.name}\n", encoding="utf-8")
    print(f"Candidate: {archive} ({archive.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
