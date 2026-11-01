"""Data preservation checks using real Atuin schemas and independent sessions."""

import contextlib
import importlib.util
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import unittest
import uuid
from unittest import mock

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "home/dot_config/biowulf/atuin-offline.py"
spec = importlib.util.spec_from_file_location("atuin_offline", HELPER)
offline = importlib.util.module_from_spec(spec)
spec.loader.exec_module(offline)
ATUIN = os.environ.get("TEST_ATUIN", str(ROOT / ".tools/pixi/bin/atuin"))


class OfflineHistoryTests(unittest.TestCase):
    def setUp(self):
        (ROOT / ".tools/tests").mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(dir=str(ROOT / ".tools/tests"))
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.archive = self.root / "archive"
        if sys.platform == "linux":
            local = tempfile.TemporaryDirectory(prefix="atuin-offline-test-", dir="/tmp")
            self.addCleanup(local.cleanup)
            self.base = Path(local.name) / "runtime"
        else:
            self.base = self.root / "runtime"
        self.base.mkdir()
        self.environment = mock.patch.dict(os.environ, {
            "ATUIN_OFFLINE_RUNTIME_BASE": str(self.base),
            "XDG_DATA_HOME": str(self.root / "data"),
            "ATUIN_AUTO_SYNC": "false", "ATUIN_UPDATE_CHECK": "false",
            "https_proxy": "http://127.0.0.1:9", "http_proxy": "http://127.0.0.1:9",
        })
        self.environment.start()
        self.addCleanup(self.environment.stop)

    def session(self):
        return offline.prepare(self.archive, ATUIN)

    def entries(self, runtime):
        with contextlib.closing(offline.connect(runtime / "history.db")) as connection:
            return {row["command"][len("offline-test-"):]: row
                    for row in offline.rows(connection).values()}

    def insert(self, runtime, identifier, duration=-1, deleted=None):
        with contextlib.closing(offline.connect(runtime / "history.db")) as connection:
            connection.execute(
                "INSERT INTO history (id,timestamp,duration,exit,command,cwd,session,hostname,deleted_at) "
                "VALUES (?,?,?,?,?,?,?,?,?)",
                (uuid.uuid5(uuid.NAMESPACE_DNS, identifier).hex,
                 1700000000000000000 + len(identifier), duration,
                 0 if duration >= 0 else -1, "offline-test-" + identifier,
                 "/offline-test", uuid.uuid5(uuid.NAMESPACE_DNS, "test-session").hex,
                 "test-node:test-user", deleted))
            connection.commit()

    def test_concurrent_sessions_keep_both_histories_and_restore(self):
        a, b = self.session(), self.session()
        self.insert(a, "command-a", 10)
        self.insert(b, "command-b", 20)
        processes = [subprocess.Popen([
            sys.executable, str(HELPER), "checkpoint", "--runtime", str(runtime),
            "--archive", str(self.archive)]) for runtime in (a, b)]
        self.assertEqual([p.wait(timeout=30) for p in processes], [0, 0])
        # Replacing one session's snapshot must not replace the other's.
        self.insert(a, "command-c", 30)
        offline.checkpoint(a, self.archive)
        self.assertEqual(len(list((self.archive / "snapshots").glob("*.db"))), 2)
        shutil.rmtree(a)
        shutil.rmtree(b)
        restored = self.session()
        self.assertEqual(set(self.entries(restored)), {"command-a", "command-b", "command-c"})
        offline.checkpoint(restored, self.archive)
        # An idle session must not republish the entire imported history.
        self.assertEqual(len(list((self.archive / "snapshots").glob("*.db"))), 2)

    def test_unfinished_command_cannot_replace_completed_or_deleted_command(self):
        a = self.session()
        self.insert(a, "shared-command")
        offline.checkpoint(a, self.archive)
        b = self.session()
        with contextlib.closing(offline.connect(a / "history.db")) as connection:
            connection.execute("UPDATE history SET duration=100,exit=0,deleted_at=123")
            connection.commit()
        offline.checkpoint(a, self.archive)
        offline.checkpoint(b, self.archive)
        entry = self.entries(b)["shared-command"]
        self.assertEqual((entry["duration"], entry["exit"], entry["deleted_at"]), (100, 0, 123))
        incoming = dict(entry, duration=-1, exit=-1, deleted_at=None)
        self.assertEqual(offline.combine(entry, incoming), entry)

    def test_failed_publish_preserves_previous_snapshot_and_retries(self):
        a = self.session()
        self.insert(a, "first-command", 10)
        offline.checkpoint(a, self.archive)
        snapshot = next((self.archive / "snapshots").glob("*.db"))
        previous = snapshot.read_bytes()
        self.insert(a, "second-command", 20)
        with mock.patch.object(offline.os, "fsync", side_effect=OSError("simulated storage failure")):
            with self.assertRaises(OSError):
                offline.checkpoint(a, self.archive)
        self.assertEqual(snapshot.read_bytes(), previous)
        self.assertEqual(list((self.archive / "snapshots").glob(".*")), [])
        offline.checkpoint(a, self.archive)
        restored = self.session()
        self.assertEqual(set(self.entries(restored)), {"first-command", "second-command"})

    def test_network_unavailable_and_inherited_paths_do_not_reuse_parent_data(self):
        a = self.session()
        self.insert(a, "parent-command", 10)
        with mock.patch.dict(os.environ, {
            "ATUIN_DATA_DIR": str(a), "ATUIN_DB_PATH": str(a / "history.db"),
            "ATUIN_RECORD_STORE_PATH": str(a / "records.db"),
        }):
            b = self.session()
        self.assertNotEqual(a, b)
        self.assertEqual(self.entries(b), {})
        env = dict(os.environ, ATUIN_DATA_DIR=str(a), ATUIN_SESSION="offline-test",
                   ATUIN_DAEMON__ENABLED="false")
        result = subprocess.run([ATUIN, "search", "--limit", "1", "--cmd-only",
                                 "--filter-mode", "global"],
                                env=env, capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("offline-test-parent-command", result.stdout)

    def test_deleted_parent_gets_final_backup_and_runtime_cleanup(self):
        a = self.session()
        self.insert(a, "final-command", 10)
        offline.watch(a, self.archive, 99999999, 1)
        self.assertFalse(a.exists())
        self.assertIn("final-command", self.entries(self.session()))

    def test_shared_files_remain_closed_and_unchanged_when_read(self):
        a = self.session()
        self.insert(a, "seed-command", 10)
        offline.checkpoint(a, self.archive)
        before = {p.name: p.read_bytes() for p in (self.archive / "snapshots").iterdir()}
        b = self.session()
        self.assertIn("seed-command", self.entries(b))
        after = {p.name: p.read_bytes() for p in (self.archive / "snapshots").iterdir()}
        self.assertEqual(before, after)
        self.assertEqual(self.archive.stat().st_mode & 0o777, 0o700)
        self.assertTrue(all(p.stat().st_mode & 0o777 == 0o600
                            for p in (self.archive / "snapshots").iterdir()))

    def test_local_base_rejects_nfs(self):
        with mock.patch.object(offline.sys, "platform", "linux"):
            with mock.patch.object(offline.subprocess, "check_output", return_value="nfs\n"):
                with self.assertRaisesRegex(RuntimeError, "No local runtime"):
                    offline.local_base()

    def test_existing_history_requires_explicit_migration(self):
        legacy = self.root / "data/atuin/history.db"
        legacy.parent.mkdir(parents=True)
        legacy.touch()
        with self.assertRaisesRegex(RuntimeError, "Export existing history"):
            self.session()


if __name__ == "__main__":
    unittest.main()
