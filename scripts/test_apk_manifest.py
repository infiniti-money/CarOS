import json
import tempfile
import unittest
from pathlib import Path
from apk_manifest import create, verify, validate, rollback_plan, load_manifest

class ManifestTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.apk = self.root / "app-debug.apk"
        self.apk.write_bytes(b"synthetic APK fixture, not installable")
        self.pubspec = self.root / "pubspec.yaml"
        self.pubspec.write_text("version: 2.5.0+6\n")
        self.data = create(self.apk, self.pubspec, "a"*40)

    def test_roundtrip(self):
        path = self.root / "manifest.json"
        path.write_text(json.dumps(self.data))
        self.assertEqual(verify(self.apk, load_manifest(path)), self.data)

    def test_modified_bytes_rejected_even_same_size(self):
        self.apk.write_bytes(b"X" + self.apk.read_bytes()[1:])
        with self.assertRaises(ValueError):
            verify(self.apk, self.data)

    def test_truncated_or_renamed_artifact_rejected(self):
        other = self.root / "different.apk"
        other.write_bytes(self.apk.read_bytes())
        with self.assertRaises(ValueError):
            verify(other, self.data)
        self.apk.write_bytes(b"")
        with self.assertRaises(ValueError):
            verify(self.apk, self.data)

    def test_untrusted_fields(self):
        for field, value in [("artifact", "../app.apk"), ("commit", "main"), ("sha256", "bad"),
                ("package", "other"), ("channel", "release"), ("build", True), ("schema", True)]:
            with self.subTest(field=field), self.assertRaises(ValueError):
                validate(dict(self.data, **{field: value}))

    def test_rollback_is_plan_only(self):
        current = dict(self.data, build=7, commit="b"*40)
        plan = rollback_plan(current, self.data)
        self.assertFalse(plan["install_allowed"])
        self.assertEqual(plan["to_build"], 6)

    def test_same_newer_build_or_same_commit_refused(self):
        for current in [dict(self.data, commit="b"*40), dict(self.data, build=5, commit="b"*40),
                        dict(self.data, build=7)]:
            with self.assertRaises(ValueError):
                rollback_plan(current, self.data)

    def test_duplicate_keys_refused(self):
        path = self.root / "manifest.json"
        path.write_text(json.dumps(self.data)[:-1] + ', "build": 7}')
        with self.assertRaises(ValueError):
            load_manifest(path)
