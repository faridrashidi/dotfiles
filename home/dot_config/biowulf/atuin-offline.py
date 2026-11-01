#!/usr/bin/env python3
"""Exchange Atuin history through atomic snapshots, never a shared live SQLite DB."""

import argparse
import contextlib
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import socket
import sqlite3
import subprocess
import sys
import tempfile
import time
import uuid


def connect(path, readonly=False):
    if readonly:
        return sqlite3.connect(path.resolve().as_uri() + "?immutable=1", uri=True)
    connection = sqlite3.connect(str(path), timeout=5)
    connection.execute("PRAGMA busy_timeout=5000")
    return connection


def private_dir(path):
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    if path.is_symlink() or path.stat().st_uid != os.getuid():
        raise RuntimeError("Not a private directory: " + str(path))
    path.chmod(0o700)
    return path


def local_base():
    candidates = [os.environ.get("ATUIN_OFFLINE_RUNTIME_BASE")]
    if not candidates[0]:
        job = os.environ.get("SLURM_JOB_ID", "")
        candidates = ["/lscratch/" + job if job else None,
                      os.environ.get("TMPDIR"), "/tmp"]
    for candidate in filter(None, candidates):
        path = Path(candidate)
        if not path.is_dir():
            continue
        if sys.platform == "linux":
            kind = subprocess.check_output(
                ["stat", "-f", "-c", "%T", str(path)], text=True
            ).strip()
            if kind not in {"ext2/ext3", "ext4", "xfs", "tmpfs", "btrfs",
                            "zfs", "overlayfs"}:
                continue
        return private_dir(path / ("atuin-offline-" + str(os.getuid())))
    raise RuntimeError("No local runtime directory available; shared SQLite is disabled")


def rows(connection):
    cursor = connection.execute("SELECT * FROM history")
    names = [column[0] for column in cursor.description]
    return {row[0]: dict(zip(names, row)) for row in cursor.fetchall()}


def combine(current, incoming):
    """Completed commands beat unfinished copies; deletion always propagates."""
    if current is None:
        return incoming.copy()
    merged = current.copy()
    if incoming["duration"] > current["duration"]:
        merged.update(incoming)
    for name, value in incoming.items():
        if merged.get(name) is None and value is not None:
            merged[name] = value
    deleted = [row.get("deleted_at") for row in (current, incoming)
               if row.get("deleted_at") is not None]
    if deleted:
        merged["deleted_at"] = max(deleted)
    return merged


def merge(connection, incoming):
    columns = {row[1] for row in connection.execute("PRAGMA table_info(history)")}
    with connection:
        # Read under the write lock so a finishing shell hook cannot be replaced
        # by a stale, unfinished command imported from another session.
        connection.execute("BEGIN IMMEDIATE")
        existing = rows(connection)
        for identifier, row in incoming.items():
            if set(row) - columns:
                raise RuntimeError("A history snapshot needs a newer Atuin schema")
            current = existing.get(identifier)
            merged = combine(current, row)
            if merged == current:
                continue
            names = list(merged)
            quoted = ",".join('"' + name + '"' for name in names)
            values = [merged[name] for name in names]
            if current is None:
                # Preserve Atuin's unique(timestamp, cwd, command) constraint.
                connection.execute(
                    "INSERT OR IGNORE INTO history (" + quoted + ") VALUES (" +
                    ",".join("?" for _ in names) + ")", values)
            else:
                assignments = ",".join('"' + name + '"=?' for name in names)
                connection.execute("UPDATE history SET " + assignments + " WHERE id=?",
                                   values + [identifier])


def copied_rows(snapshot, runtime):
    # Readers copy complete, closed files. SQLite only ever opens the local copy.
    with tempfile.TemporaryDirectory(prefix="read-", dir=str(runtime)) as temporary:
        local = Path(temporary) / "snapshot.db"
        shutil.copyfile(str(snapshot), str(local))
        with contextlib.closing(connect(local, readonly=True)) as connection:
            if connection.execute("PRAGMA quick_check").fetchall() != [("ok",)]:
                raise RuntimeError("Invalid history snapshot: " + snapshot.name)
            return rows(connection)


def refresh(runtime, archive):
    state_path = runtime / "seen.json"
    seen = json.loads(state_path.read_text()) if state_path.exists() else {}
    own_name = (runtime / "snapshot-name").read_text().strip()
    with contextlib.closing(connect(runtime / "history.db")) as history:
        with contextlib.closing(connect(runtime / "baseline.db")) as baseline:
            for snapshot in sorted((archive / "snapshots").glob("*.db")):
                if snapshot.name == own_name:
                    continue
                stat = snapshot.stat()
                signature = [stat.st_mtime_ns, stat.st_size, stat.st_ino]
                if seen.get(snapshot.name) == signature:
                    continue
                # A failed read is retried, and cannot replace a good backup.
                incoming = copied_rows(snapshot, runtime)
                merge(history, incoming)
                merge(baseline, incoming)
                seen[snapshot.name] = signature
    temporary = state_path.with_suffix(".tmp")
    temporary.write_text(json.dumps(seen))
    temporary.replace(state_path)


def write_snapshot(path, schema, entries):
    with contextlib.closing(connect(path)) as connection:
        connection.execute(schema)
        merge(connection, entries)
        if connection.execute("PRAGMA integrity_check").fetchall() != [("ok",)]:
            raise RuntimeError("Snapshot integrity check failed")
    path.chmod(0o600)


def publish(runtime, archive):
    with contextlib.closing(connect(runtime / "history.db")) as history:
        current = rows(history)
        schema = history.execute(
            "SELECT sql FROM sqlite_master WHERE type='table' AND name='history'"
        ).fetchone()[0]
    with contextlib.closing(connect(runtime / "baseline.db")) as baseline:
        imported = rows(baseline)
    previous_path = runtime / "published.db"
    previous = copied_rows(previous_path, runtime) if previous_path.exists() else {}
    outgoing = previous.copy()
    for identifier, row in current.items():
        if imported.get(identifier) != row:
            outgoing[identifier] = combine(outgoing.get(identifier), row)
    destination = archive / "snapshots" / (runtime / "snapshot-name").read_text().strip()
    if not outgoing or (outgoing == previous and destination.exists()):
        return
    with tempfile.TemporaryDirectory(prefix="write-", dir=str(runtime)) as temporary:
        local = Path(temporary) / "snapshot.db"
        write_snapshot(local, schema, outgoing)
        # Each shell owns one filename. No NFS lock or shared SQLite writer.
        partial = destination.with_name("." + destination.name + "." + uuid.uuid4().hex)
        try:
            with local.open("rb") as source, partial.open("xb") as target:
                os.chmod(str(partial), 0o600)
                shutil.copyfileobj(source, target)
                target.flush()
                os.fsync(target.fileno())
            partial.replace(destination)
            shutil.copyfile(str(local), str(previous_path))
            previous_path.chmod(0o600)
        finally:
            if partial.exists():
                partial.unlink()


def checkpoint(runtime, archive):
    # This lock is on the local disk, and only coordinates this shell's workers.
    with (runtime / "checkpoint.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        # Save local changes before importing snapshots from other sessions.
        publish(runtime, archive)
        refresh(runtime, archive)


def prepare(archive, executable):
    private_dir(archive)
    private_dir(archive / "snapshots")
    legacy = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "atuin/history.db"
    if legacy.exists() and not any((archive / "snapshots").glob("*.db")):
        raise RuntimeError("Export existing history to snapshots/seed.db before enabling offline history")
    runtime = Path(tempfile.mkdtemp(prefix="session-", dir=str(local_base())))
    try:
        name = re.sub(r"[^a-zA-Z0-9_.-]", "_", socket.gethostname())
        (runtime / "snapshot-name").write_text(name + "-" + uuid.uuid4().hex + ".db")
        env = os.environ.copy()
        env.update(ATUIN_DATA_DIR=str(runtime), ATUIN_DB_PATH=str(runtime / "history.db"),
                   ATUIN_RECORD_STORE_PATH=str(runtime / "records.db"),
                   ATUIN_KEY_PATH=str(runtime / "key"), ATUIN_LOGS__DIR=str(runtime / "logs"),
                   ATUIN_AUTO_SYNC="false", ATUIN_UPDATE_CHECK="false",
                   ATUIN_DAEMON__ENABLED="false", ATUIN_DAEMON__AUTOSTART="false")
        subprocess.run([executable, "info"], env=env, check=True,
                       stdout=subprocess.DEVNULL, timeout=30)
        with contextlib.closing(connect(runtime / "history.db")) as history:
            with contextlib.closing(connect(runtime / "baseline.db")) as baseline:
                history.backup(baseline)
        refresh(runtime, archive)
        return runtime
    except BaseException:
        shutil.rmtree(str(runtime))
        raise


def watch(runtime, archive, parent, interval):
    while True:
        try:
            checkpoint(runtime, archive)
        except Exception as error:
            print("Atuin offline backup: " + str(error), file=sys.stderr, flush=True)
        try:
            os.kill(parent, 0)
        except ProcessLookupError:
            # Keep the local files if the final backup fails.
            checkpoint(runtime, archive)
            shutil.rmtree(str(runtime))
            return
        time.sleep(interval)


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("prepare", "checkpoint", "watch"))
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--runtime", type=Path)
    parser.add_argument("--atuin", default="atuin")
    parser.add_argument("--parent", type=int)
    parser.add_argument("--interval", type=float, default=30)
    args = parser.parse_args()
    archive = private_dir(args.archive)
    if args.command == "prepare":
        print(prepare(archive, args.atuin))
    elif args.command == "checkpoint":
        checkpoint(args.runtime, archive)
    else:
        if not args.parent or args.parent < 2 or args.interval < 1:
            parser.error("watch requires a parent PID and an interval of at least one second")
        watch(args.runtime, archive, args.parent, args.interval)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print("Atuin offline: " + str(error), file=sys.stderr)
        sys.exit(1)
