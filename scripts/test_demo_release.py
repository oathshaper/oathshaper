"""Offline publication gates, including bad artifacts and interrupted uploads."""
import copy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import plistlib
import tarfile
import tempfile
import unittest
from unittest.mock import patch
import zipfile

spec = importlib.util.spec_from_file_location("release", Path(__file__).with_name("demo-release.py"))
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)
SHA = "a" * 40


def checksum(data):
    return hashlib.sha256(data).hexdigest()


def fixture(root, platform, *, extra=None, bad_file=False, manifest_revision=SHA, omit_notice=False):
    label, extension, executable = release.PLATFORMS[platform]
    stem = f"oathshaper-demo-{label}-{SHA[:12]}"
    folder = root / f"oathshaper-demo-{platform}-{SHA}"
    folder.mkdir(parents=True, exist_ok=True)
    if platform == "macos":
        executable = "Oathshaper.app/Contents/MacOS/Oathshaper"
    files = {executable: b"fixture executable", "licenses/LICENSE": b"fixture notice",
             "licenses/godot/assets/audio/generated/ATTRIBUTION.md": b"fixture credits"}
    if platform == "macos":
        files["Oathshaper.app/Contents/Info.plist"] = plistlib.dumps({"CFBundleExecutable": "Oathshaper"})
    if omit_notice:
        del files["licenses/godot/assets/audio/generated/ATTRIBUTION.md"]
    manifest = {"source_commit": manifest_revision, "platform": label, "tracked_worktree_dirty": False,
                "native_smoke": "passed", "files": {n: checksum(b) for n, b in files.items()}}
    package = {stem + "/" + n: b for n, b in files.items()}
    package[stem + "/BUILD-MANIFEST.json"] = json.dumps(manifest).encode()
    if extra:
        package[extra] = b"unexpected"
    if bad_file:
        package[stem + "/" + executable] = b"changed"
    archive = folder / (stem + extension)
    if extension == ".zip":
        with zipfile.ZipFile(archive, "w") as bundle:
            for name, data in package.items():
                bundle.writestr(name, data)
    else:
        with tarfile.open(archive, "w:gz") as bundle:
            for name, data in package.items():
                member = tarfile.TarInfo(name)
                member.size = len(data)
                bundle.addfile(member, io.BytesIO(data))
    archive.with_name(archive.name + ".sha256").write_text(release.digest(archive) + "  " + archive.name + "\n")
    skipped = {"vanguard_presentation_test"} if platform == "windows" else set()
    report = {"source_commit": SHA, "platform": label, "executable_sha256": checksum(files[executable]),
              "manifest_files_verified": len(files), "passed": True, "rendered": platform != "windows",
              "skipped": [{"suite": s} for s in skipped],
              "results": [{"suite": s, "passed": True, "exit": 0, "errors": [], "summary": ["fixture PASS"]}
                          for s in sorted(release.SUITES - skipped)]}
    evidence = root / f"oathshaper-acceptance-{platform}-{SHA}"
    evidence.mkdir(exist_ok=True)
    (evidence / "acceptance.json").write_text(json.dumps(report))
    return archive, report


def prepared_fixture(root):
    for platform in release.PLATFORMS:
        fixture(root, platform)
    output = root / "ready"
    release.prepare(root, SHA, "demo-test", "https://github.com/example/game/actions/runs/1", output)
    return output, json.loads((output / "publish-plan.json").read_text())


class ReleaseGateTests(unittest.TestCase):
    def test_macos_renderer_claim_requires_the_pixel_suite(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive, report = fixture(Path(temporary), "macos")
            package = release.verify_archive(archive, "macos", SHA)
            pixel = "vanguard_presentation_test"
            report["results"] = [row for row in report["results"] if row["suite"] != pixel]
            report["skipped"] = [{"suite": pixel}]
            with self.assertRaises(RuntimeError):
                release.verify_acceptance(report, "macos", SHA, package)
            report["rendered"] = False
            checked = release.verify_acceptance(report, "macos", SHA, package)
            self.assertFalse(checked["rendered"])
            self.assertEqual(checked["skipped"], [pixel])

    def test_all_native_archive_formats_and_reports(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for platform in release.PLATFORMS:
                archive, report = fixture(root, platform)
                package = release.verify_archive(archive, platform, SHA)
                release.verify_acceptance(report, platform, SHA, package)
            release.prepare(root, SHA, "milestone-1", "https://github.com/example/game/actions/runs/1", root / "ready")
            plan = json.loads((root / "ready/publish-plan.json").read_text())
            self.assertEqual(len(plan["files"]), 9)
            self.assertTrue(all(release.digest(root / "ready" / n) == sha for n, sha in plan["files"].items()))

    def test_corrupt_archive_or_manifest_and_missing_notices_rejected(self):
        for kind in ["checksum", "payload", "source", "extra", "traversal", "notice"]:
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as temporary:
                options = {"bad_file": kind == "payload", "manifest_revision": "b" * 40 if kind == "source" else SHA}
                options["omit_notice"] = kind == "notice"
                if kind == "extra": options["extra"] = f"oathshaper-demo-windows-x86_64-{SHA[:12]}/private.txt"
                if kind == "traversal": options["extra"] = "../escaped"
                archive, _ = fixture(Path(temporary), "windows", **options)
                if kind == "checksum": archive.write_bytes(archive.read_bytes() + b"changed")
                with self.assertRaises(RuntimeError): release.verify_archive(archive, "windows", SHA)

    def test_acceptance_failure_cannot_be_hidden_by_top_level_pass(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive, original = fixture(Path(temporary), "windows")
            package = release.verify_archive(archive, "windows", SHA)
            for kind in ["revision", "executable", "missing", "duplicate", "errors", "exit", "skip", "rendered", "passed"]:
                report = copy.deepcopy(original)
                if kind == "revision": report["source_commit"] = "b" * 40
                if kind == "executable": report["executable_sha256"] = "b" * 64
                if kind == "missing": report["results"].pop()
                if kind == "duplicate": report["results"][-1] = report["results"][0]
                if kind == "errors": report["results"][0]["errors"] = ["ERROR: resources still in use at exit"]
                if kind == "exit": report["results"][0]["exit"] = 1
                if kind == "skip": report["skipped"].append({"suite": "flow_presentation_test"})
                if kind == "rendered": report["rendered"] = True
                if kind == "passed": report["passed"] = False
                with self.subTest(kind=kind), self.assertRaises(RuntimeError):
                    release.verify_acceptance(report, "windows", SHA, package)

    def test_missing_platform_never_produces_publish_plan(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            fixture(root, "linux")
            with self.assertRaises(FileNotFoundError):
                release.prepare(root, SHA, "demo-test", "https://github.com/example/game/actions/runs/1", root / "ready")
            self.assertFalse((root / "ready").exists())

    def test_existing_assets_are_verified_never_clobbered(self):
        existing = {"assets": [{"name": "demo.zip", "digest": "sha256:abc", "state": "uploaded"}]}
        self.assertEqual(release.pending_assets(existing, {"demo.zip": "abc", "TESTING.md": "def"}), ["TESTING.md"])
        for digest in ["different", None]:
            with self.subTest(digest=digest):
                existing["assets"][0]["digest"] = digest
                with self.assertRaises(RuntimeError): release.pending_assets(existing, {"demo.zip": "abc"})
        with self.assertRaises(RuntimeError):
            release.pending_assets({"assets": [], "immutable": True}, {"demo.zip": "abc"})

    def test_moved_tag_stops_before_release_mutations(self):
        with tempfile.TemporaryDirectory() as temporary:
            root, _ = prepared_fixture(Path(temporary))
            with patch.object(release, "remote_revision", return_value="b" * 40), patch.object(release, "gh") as gh:
                with self.assertRaisesRegex(RuntimeError, "tag moved"):
                    release.publish(root, "example/game")
                gh.assert_not_called()

    def test_interrupted_upload_keeps_release_draft(self):
        with tempfile.TemporaryDirectory() as temporary:
            root, _ = prepared_fixture(Path(temporary))
            draft = {"assets": [], "draft": True}
            with patch.object(release, "remote_revision", return_value=SHA), \
                    patch.object(release, "release_for_tag", return_value=draft), \
                    patch.object(release, "gh", side_effect=RuntimeError("upload interrupted")) as gh:
                with self.assertRaisesRegex(RuntimeError, "interrupted"):
                    release.publish(root, "example/game")
                self.assertEqual(gh.call_count, 1)
                self.assertEqual(gh.call_args.args[:2], ("release", "upload"))

    def test_new_draft_publishes_only_after_every_asset_is_verified(self):
        with tempfile.TemporaryDirectory() as temporary:
            root, plan = prepared_fixture(Path(temporary))
            state = {"release": None, "commands": []}

            def execute(*args):
                state["commands"].append(args)
                if args[:2] == ("release", "create"):
                    self.assertIn("--draft", args)
                    state["release"] = {"assets": [], "draft": True, "html_url": "https://github.com/example/game/releases/tag/demo-test"}
                elif args[:2] == ("release", "upload"):
                    self.assertTrue(state["release"]["draft"])
                    self.assertNotIn("--clobber", args)
                    name = Path(args[3]).name
                    state["release"]["assets"].append({"name": name, "digest": "sha256:" + plan["files"][name], "state": "uploaded"})
                elif args[:2] == ("release", "edit"):
                    self.assertEqual(len(state["release"]["assets"]), 9)
                    state["release"]["draft"] = False

            with patch.object(release, "remote_revision", return_value=SHA), \
                    patch.object(release, "release_for_tag", side_effect=lambda *a: copy.deepcopy(state["release"])), \
                    patch.object(release, "gh", side_effect=execute):
                release.publish(root, "example/game")
            self.assertFalse(state["release"]["draft"])
            self.assertEqual(state["commands"][-1][:2], ("release", "edit"))

    def test_identical_published_assets_need_no_mutation(self):
        with tempfile.TemporaryDirectory() as temporary:
            root, plan = prepared_fixture(Path(temporary))
            current = {"assets": [{"name": n, "digest": "sha256:" + sha, "state": "uploaded"} for n, sha in plan["files"].items()],
                       "draft": False, "immutable": True, "html_url": "https://github.com/example/game/releases/tag/demo-test"}
            with patch.object(release, "remote_revision", return_value=SHA), \
                    patch.object(release, "release_for_tag", return_value=current), patch.object(release, "gh") as gh:
                release.publish(root, "example/game")
                gh.assert_not_called()

    def test_incomplete_plan_or_changed_payload_never_reaches_github(self):
        for kind in ["plan", "payload"]:
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as temporary:
                root, plan = prepared_fixture(Path(temporary))
                if kind == "plan":
                    plan["files"].pop("TESTING.md")
                    (root / "publish-plan.json").write_text(json.dumps(plan))
                else:
                    (root / "TESTING.md").write_text("changed")
                with patch.object(release, "remote_revision") as remote:
                    with self.assertRaises(RuntimeError): release.publish(root, "example/game")
                    remote.assert_not_called()


if __name__ == "__main__":
    unittest.main()
