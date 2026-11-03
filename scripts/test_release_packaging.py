"""Offline checks of release contents; no engine build, download or upload."""
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("export_release", Path(__file__).with_name("export-release.py"))
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)


class ReleasePackagingTests(unittest.TestCase):
    def test_release_flags_preserve_space_paths_and_windows_crt(self):
        import json
        work = Path("/tmp/release build")
        for target in ["aarch64-apple-darwin", "x86_64-pc-windows-msvc"]:
            flags = release.release_rust_flags(work, target)
            self.assertEqual(json.loads(json.dumps(flags)), flags)
            self.assertIn(f"--remap-path-prefix={work.resolve()}=/build", flags)
            self.assertIn(f"--remap-path-prefix={release.ROOT.resolve()}=.", flags)
            self.assertEqual("target-feature=+crt-static" in flags, target.endswith("windows-msvc"))
            self.assertEqual("link-arg=/DEBUG:NONE" in flags, target.endswith("windows-msvc"))

    def test_tracked_project_staging_excludes_local_outputs(self):
        with tempfile.TemporaryDirectory() as temp:
            root, stage = Path(temp) / "source", Path(temp) / "stage"
            paths = [Path(p) for p in ["godot/content/chapter.json", "godot/.godot/export_credentials.cfg",
                                      "godot/bin/old.dylib", "godot/user-data/save.json", "docs/private.md"]]
            for path in paths:
                (root / path).parent.mkdir(parents=True, exist_ok=True)
                (root / path).write_text("fixture")
            (root / "godot/untracked.json").write_text("not in the tracked path list")
            with patch.object(release, "ROOT", root):
                release.stage_project(paths, stage)
            self.assertEqual([p.relative_to(stage).as_posix() for p in stage.rglob("*") if p.is_file()],
                             ["content/chapter.json"])

    def test_private_files_are_rejected_even_if_tracked(self):
        for name in [".env", ".env.production", ".secrets/README.md", ".private/plan.md",
                     ".ARTIFACTS/README.md", ".agent-worktrees/source.gd", "export_credentials.cfg",
                     "signing.key", "signing.p12", "signing.pfx", "signing.jks",
                     "signing.keystore", "signing.mobileprovision", ".ENV", ".Env.production",
                     ".SECRETS/README.md", "EXPORT_CREDENTIALS.CFG", "SIGNING.P12"]:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temp:
                root, stage = Path(temp) / "source", Path(temp) / "stage"
                path = Path("godot/assets") / name
                (root / path).parent.mkdir(parents=True, exist_ok=True)
                (root / path).write_text("fixture")
                with patch.object(release, "ROOT", root), self.assertRaisesRegex(RuntimeError, "Private configuration"):
                    release.stage_project([path], stage)
                self.assertFalse(stage.exists())

    def test_notices_reject_private_paths(self):
        for name in [".ENV.LICENSE", "godot/assets/.SECRETS/NOTICE.md",
                     "godot/assets/.PRIVATE/README.md", "godot/assets/.artifacts/NOTICE.md"]:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                path = Path(name)
                (root / path).parent.mkdir(parents=True, exist_ok=True)
                (root / path).write_text("fixture")
                with patch.object(release, "ROOT", root), self.assertRaisesRegex(RuntimeError, "Private configuration"):
                    list(release.local_notice_paths([path]))

    @unittest.skipIf(os.name == "nt", "POSIX filesystem permission/symlink fixture; staging checks still run")
    def test_notice_symlinks_are_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / "source"
            root.mkdir()
            outside = Path(temp) / "outside.txt"
            outside.write_text("fixture")
            (root / "LICENSE").symlink_to(outside)
            with patch.object(release, "ROOT", root), self.assertRaisesRegex(RuntimeError, "symlink"):
                list(release.local_notice_paths([Path("LICENSE")]))

    @unittest.skipIf(os.name == "nt", "POSIX filesystem permission/symlink fixture; staging checks still run")
    def test_unreadable_game_source_fails(self):
        with tempfile.TemporaryDirectory() as temp:
            root, stage = Path(temp) / "source", Path(temp) / "stage"
            path = Path("godot/content/chapter.json")
            source = root / path
            source.parent.mkdir(parents=True)
            source.write_text("fixture")
            source.chmod(0)
            try:
                with patch.object(release, "ROOT", root), self.assertRaises(PermissionError):
                    release.stage_project([path], stage)
            finally:
                source.chmod(0o600)

    @unittest.skipIf(os.name == "nt", "POSIX filesystem permission/symlink fixture; staging checks still run")
    def test_symlink_does_not_copy_private_source(self):
        with tempfile.TemporaryDirectory() as temp:
            root, stage = Path(temp) / "source", Path(temp) / "stage"
            external = Path(temp) / "outside.txt"
            external.write_text("fixture")
            path = Path("godot/assets/reference.txt")
            (root / path).parent.mkdir(parents=True)
            (root / path).symlink_to(external)
            with patch.object(release, "ROOT", root), self.assertRaisesRegex(RuntimeError, "symlink"):
                release.stage_project([path], stage)
            self.assertFalse(stage.exists())
            self.assertEqual(external.read_text(), "fixture")

    def test_actual_notices_include_sound_licenses_and_animation_donors(self):
        selected = set(release.local_notice_paths(release.tracked_paths()))
        required = {Path("LICENSE"), Path("godot/assets/fonts/OFL-LibreBaskerville.txt"),
                    Path("godot/assets/audio/generated/ATTRIBUTION.md"),
                    Path("tools/rigging/sources/quaternius/LICENSE.txt"),
                    Path("tools/rigging/sources/quaternius/manifest.json"),
                    Path("godot/assets/meshes/equipment/manifest.json"),
                    Path("godot/assets/meshes/adversaries/manifest.json")}
        kenney = set(Path("godot/assets/audio/cc0").glob("*/License.txt"))
        self.assertEqual(len(kenney), 4)
        self.assertTrue((required | kenney).issubset(selected))
        with tempfile.TemporaryDirectory() as temp:
            package = Path(temp)
            for path in selected:
                release.copy_file(release.ROOT / path, package / path)
            for path in required | kenney:
                self.assertEqual((package / path).read_bytes(), (release.ROOT / path).read_bytes())
        self.assertFalse(any(p.suffix in {".glb", ".wav", ".png"} for p in selected))


if __name__ == "__main__":
    unittest.main()
