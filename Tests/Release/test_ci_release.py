import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from subprocess import CompletedProcess

spec = importlib.util.spec_from_file_location("ci_release", "Scripts/ci-release.py")
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseMetadataTests(unittest.TestCase):
    def test_targets(self):
        self.assertEqual(release.release_target("refs/tags/v0.2.0", "0.2.0", "12", "1", "abc"),
                         ("v0.2.0", "Capt 0.2.0", False))
        for ref in ["refs/heads/master", "refs/tags/v0.1.0", "refs/tags/v0.2.0-rc1", "refs/heads/feature"]:
            with self.assertRaises(ValueError):
                release.release_target(ref, "0.2.0", "12", "1", "abc")

    def prepare(self, response):
        with tempfile.TemporaryDirectory() as directory:
            previous = os.getcwd()
            # Keep fixtures isolated from the actual version and release notes.
            try:
                os.chdir(directory)
                Path("Resources").mkdir()
                with open("Resources/Info.plist", "wb") as target:
                    release.plistlib.dump({"CFBundleShortVersionString": "0.2.0"}, target)
                env = {"GITHUB_REF": "refs/tags/v0.2.0", "GITHUB_RUN_ID": "12",
                       "GITHUB_RUN_ATTEMPT": "1", "GITHUB_SHA": "abc123",
                       "GITHUB_REPOSITORY": "test/capt", "GITHUB_OUTPUT": "outputs"}
                with patch.dict(os.environ, env), patch.object(release.subprocess, "run", return_value=response):
                    release.main()
                return Path("outputs").read_text(), Path(".release-notes.md").read_text()
            finally:
                os.chdir(previous)

    def test_new_release(self):
        output, body = self.prepare(CompletedProcess([], 1, "", "gh: Not Found (HTTP 404)"))
        self.assertIn("generate_notes=true", output)
        self.assertIn("make_latest=legacy", output)
        self.assertIn("not notarized", body)

    def test_preserves_existing_draft(self):
        existing = {"name": "Custom title", "prerelease": False, "draft": True, "body": "Handwritten notes"}
        output, body = self.prepare(CompletedProcess([], 0, json.dumps(existing), ""))
        self.assertIn("draft=true", output)
        self.assertIn("generate_notes=false", output)
        self.assertNotIn("name=", output)
        self.assertEqual(body, "Handwritten notes")

    def test_api_failure_stops_release(self):
        with self.assertRaises(RuntimeError):
            self.prepare(CompletedProcess([], 1, "", "TLS timeout"))

    def test_immutable_release_stops(self):
        with self.assertRaises(ValueError):
            self.prepare(CompletedProcess([], 0, '{"immutable":true}', ""))


if __name__ == "__main__":
    unittest.main()
