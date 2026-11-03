import gzip
import importlib.util
import io
from pathlib import Path
import tarfile
import unittest

SPEC = importlib.util.spec_from_file_location("public_tree", Path(__file__).with_name("check-public-tree.py"))
guard = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(guard)


class PublicTreeTests(unittest.TestCase):
    def scan(self, path, data):
        found = []
        guard.inspect(path, data, found, {"binary_payloads_excluded": 0, "text_or_metadata_checked": 0})
        return found

    def test_paths_hosts_and_networks_are_reported_without_values(self):
        values = ["/" + "Users/example/work/", "https://" + "example." + "LOCAL/service",
                  ".".join(["192", "168", "1", "20"]), ".".join(["100", "80", "1", "2"])]
        for value in values:
            findings = self.scan("notes.md", value.encode())
            self.assertTrue(findings)
            self.assertNotIn(value, str(findings))

    def test_public_and_loopback_examples_pass(self):
        self.assertEqual(self.scan("README.md", b"https://godotengine.org 127.0.0.1 localhost ./assets"), [])

    def test_case_insensitive_private_file(self):
        self.assertEqual(self.scan("godot/assets/.PRIVATE/plan.md", b"planning")[0]["category"], "private_file")

    def test_example_environment_never_exempts_a_private_directory(self):
        for name in [".PRIVATE/.env.example", ".secrets/.env.sample", ".env.production/.env.example"]:
            self.assertEqual(self.scan(name, b"placeholder")[0]["category"], "private_file")
        for name in [".env.example", "docs/.env.sample"]:
            self.assertEqual(self.scan(name, b"placeholder"), [])

    def test_compressed_evidence_is_checked(self):
        data = ("https://" + "example." + "local").encode()
        self.assertTrue(self.scan("evidence.json.gz", gzip.compress(data)))
        buffer = io.BytesIO()
        with tarfile.open(fileobj=buffer, mode="w:gz") as archive:
            member = tarfile.TarInfo("notes.txt")
            member.size = len(data)
            archive.addfile(member, io.BytesIO(data))
        self.assertTrue(self.scan("evidence.tar.gz", buffer.getvalue()))

    def test_archive_escape_fails(self):
        buffer = io.BytesIO()
        with tarfile.open(fileobj=buffer, mode="w:gz") as archive:
            member = tarfile.TarInfo("../outside.txt")
            archive.addfile(member, io.BytesIO())
        with self.assertRaisesRegex(ValueError, "Unsafe archive"):
            self.scan("evidence.tar.gz", buffer.getvalue())


if __name__ == "__main__":
    unittest.main()
