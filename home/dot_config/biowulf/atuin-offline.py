#!/usr/bin/env python3
"""Share Atuin history between Biowulf nodes without a shared live database.

Shells on one node share a runtime on local disk, where Atuin keeps all of its
files. The shells save the node's changes to /data as a closed SQLite snapshot
and import the snapshots of other nodes. Shared files are replaced atomically,
copied before they are read, and compacted when old.
"""

import argparse
import contextlib
import fcntl
import getpass
import json
import os
from pathlib import Path
import shlex
import shutil
import socket
import sqlite3
import subprocess
import sys
import tempfile
import time
import uuid

COMPACT_AGE = 24 * 3600  # snapshots unchanged this long can be compacted
COMPACT_MIN = 20         # compact once this many of them exist
COMPACT_EVERY = 3600     # seconds between compaction checks on a node
LOCAL_FILESYSTEMS = {"ext2/ext3", "ext4", "xfs", "tmpfs", "btrfs", "zfs", "overlayfs"}
RUNTIME_FILES = ("history.db", "baseline.db", "snapshot-name")


class SchemaError(Exception):
    pass


def log(message):
    stamp = "" if sys.stderr.isatty() else time.strftime("%Y-%m-%d %H:%M:%S ")
    print("%sAtuin offline: %s" % (stamp, message), file=sys.stderr, flush=True)


# Paths and locks

def default_archive():
    if os.environ.get("ATUIN_OFFLINE_ARCHIVE_DIR"):
        return Path(os.environ["ATUIN_OFFLINE_ARCHIVE_DIR"])
    data = os.environ.get("DATA") or "/data/" + getpass.getuser()
    return Path(data, ".local/share/atuin-offline")


def private_dir(path):
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    if path.is_symlink() or path.stat().st_uid != os.getuid():
        raise RuntimeError("not a private directory: %s" % path)
    path.chmod(0o700)
    return path


def node_dir():
    """Private directory on this node's local disk."""
    base = os.environ.get("ATUIN_OFFLINE_RUNTIME_BASE")
    job = os.environ.get("SLURM_JOB_ID")
    candidates = [base] if base else [job and "/lscratch/" + job, os.environ.get("TMPDIR"), "/tmp"]
    for candidate in filter(None, candidates):
        path = Path(candidate)
        if path.is_dir() and is_local(path):
            return private_dir(path / ("atuin-offline-%d" % os.getuid()))
    raise RuntimeError("no local disk for Atuin's databases")


def is_local(path):
    if sys.platform != "linux":
        return True
    result = subprocess.run(["stat", "-f", "-c", "%T", str(path)], capture_output=True, text=True)
    return result.stdout.strip() in LOCAL_FILESYSTEMS


@contextlib.contextmanager
def locked(path):
    with open(str(path), "a") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        yield


def try_lock(path):
    """Return the locked file, or None if another process holds the lock."""
    handle = open(str(path), "a")
    try:
        fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        handle.close()
        return None
    return handle


# SQLite

def uri(path, mode="rw"):
    """SQLite URI; unlike a plain path, mode=rw never creates a missing file."""
    return "%s?mode=%s" % (Path(os.path.abspath(str(path))).as_uri(), mode)


def rows(cursor):
    names = [column[0] for column in cursor.description]
    return {row["id"]: row for row in (dict(zip(names, values)) for values in cursor)}


def columns(db, schema="main"):
    return [row[1] for row in db.execute("PRAGMA %s.table_info(history)" % schema)]


def table_sql(db, schema="main"):
    row = db.execute("SELECT sql FROM %s.sqlite_master WHERE type = 'table' AND name = 'history'"
                     % schema).fetchone()
    if row is None:
        raise RuntimeError("Atuin's history table is missing")
    return row[0]


def fetch(db, keys, schema="main"):
    """Rows with the given ids."""
    keys, found = list(keys), {}
    for start in range(0, len(keys), 500):
        chunk = keys[start:start + 500]
        found.update(rows(db.execute("SELECT * FROM %s.history WHERE id IN (%s)"
                                     % (schema, ",".join("?" * len(chunk))), chunk)))
    return found


def combine(current, incoming):
    """The latest deletion wins, then a finished command; gaps come from the other copy."""
    if current is None:
        return dict(incoming)

    def rank(row):
        return row.get("deleted_at") or 0, row["duration"]

    first, second = (incoming, current) if rank(incoming) > rank(current) else (current, incoming)
    merged = dict(first)
    for name, value in second.items():
        if merged.get(name) is None:
            merged[name] = value
    return merged


def merge(db, incoming, schema="main"):
    """Merge rows into a history table, reading the existing rows under the write lock."""
    known = set(columns(db, schema))
    if any(set(row) - known for row in incoming.values()):
        raise SchemaError("snapshot needs a newer Atuin")
    with db:
        db.execute("BEGIN IMMEDIATE")
        existing = fetch(db, incoming, schema)
        for key, new in incoming.items():
            current = existing.get(key)
            row = combine(current, new)
            if row == current:
                continue
            names = ",".join('"%s"' % name for name in row)
            values = ",".join("?" * len(row))
            if current is None:
                # OR IGNORE keeps Atuin's unique (timestamp, cwd, command) rule.
                db.execute("INSERT OR IGNORE INTO %s.history (%s) VALUES (%s)"
                           % (schema, names, values), list(row.values()))
            else:
                db.execute("UPDATE OR IGNORE %s.history SET (%s) = (%s) WHERE id = ?"
                           % (schema, names, values), list(row.values()) + [key])


@contextlib.contextmanager
def runtime_db(runtime):
    """History with the baseline attached as "base". The baseline first gets any
    column that an Atuin upgrade added to history."""
    with contextlib.closing(sqlite3.connect(uri(runtime / "history.db"), uri=True,
                                            timeout=10)) as db:
        db.execute("ATTACH DATABASE ? AS base", (uri(runtime / "baseline.db"),))
        known = set(columns(db, "base"))
        with db:
            for name in columns(db):
                if name not in known:
                    db.execute('ALTER TABLE base.history ADD COLUMN "%s"' % name)
                    db.execute('UPDATE base.history SET "%s" = (SELECT h."%s" FROM main.history h'
                               ' WHERE h.id = base.history.id)' % (name, name))
        yield db


def load(path, scratch):
    """Read a snapshot from a local copy; SQLite never opens a shared file."""
    with tempfile.TemporaryDirectory(dir=str(scratch)) as temporary:
        local = Path(temporary, "snapshot.db")
        shutil.copyfile(str(path), str(local))
        with contextlib.closing(sqlite3.connect(local.as_uri() + "?immutable=1", uri=True)) as db:
            if db.execute("PRAGMA quick_check").fetchone() != ("ok",):
                raise sqlite3.DatabaseError("damaged database")
            return rows(db.execute("SELECT * FROM history"))


def write(path, schema, entries):
    with contextlib.closing(sqlite3.connect(str(path))) as db:
        db.execute(schema)
        merge(db, entries)


def install(local, target):
    """Atomically replace a shared file with a local one."""
    partial = target.with_name(".%s.%s" % (target.name, uuid.uuid4().hex))
    try:
        with open(str(local), "rb") as source, open(str(partial), "xb") as sink:
            shutil.copyfileobj(source, sink)
            sink.flush()
            os.fsync(sink.fileno())
        os.replace(str(partial), str(target))
    finally:
        with contextlib.suppress(FileNotFoundError):
            os.unlink(str(partial))


# Exchange

def signature(path):
    stat = path.stat()
    return [stat.st_mtime_ns, stat.st_size, stat.st_ino]


def snapshots(archive):
    return sorted((archive / "snapshots").glob("*.db"))


def own_snapshot(runtime):
    return (runtime / "snapshot-name").read_text().strip()


def published(runtime):
    """Rows of this node's last snapshot."""
    path = runtime / "published.db"
    try:
        return load(path, runtime) if path.exists() else {}
    except sqlite3.DatabaseError:
        path.unlink()  # damaged; saving everything again is harmless
        return {}


def keep_deletions(runtime):
    """Atuin removes deleted rows outright. Rows that vanished from history become
    deletion markers, so other nodes drop them and imports can't restore them.
    If more rows vanished than remain, history.db was reset: restore them all."""
    previous = published(runtime)
    with runtime_db(runtime) as db:
        missing = rows(db.execute(
            "SELECT b.* FROM base.history b"
            " WHERE NOT EXISTS (SELECT 1 FROM main.history h WHERE h.id = b.id)"
            " AND NOT EXISTS (SELECT 1 FROM main.history h WHERE h.timestamp = b.timestamp"
            " AND h.cwd = b.cwd AND h.command = b.command)"))
        present = fetch(db, previous)
        for key, row in previous.items():
            if key not in present:
                missing[key] = combine(missing.get(key), row)
        gone = {key: row for key, row in missing.items() if row.get("deleted_at") is None}
        if not gone:
            return
        remaining = db.execute("SELECT count(*) FROM main.history").fetchone()[0]
        if len(gone) > remaining:
            log("history.db lost %d commands but kept %d; restoring them" % (len(gone), remaining))
            merge(db, missing)
        else:
            now = time.time_ns()
            merge(db, {key: dict(row, deleted_at=now, command=uuid.uuid4().hex)
                       for key, row in gone.items()})


def publish(runtime, archive):
    """Save the rows changed on this node to its snapshot."""
    previous = published(runtime)
    with runtime_db(runtime) as db:
        changed = " OR ".join('h."%s" IS NOT b."%s"' % (name, name) for name in columns(db))
        changes = rows(db.execute("SELECT h.* FROM main.history h LEFT JOIN base.history b"
                                  " ON b.id = h.id WHERE b.id IS NULL OR " + changed))
        schema = table_sql(db)
    target = archive / "snapshots" / own_snapshot(runtime)
    if changes == previous and (target.exists() or not changes):
        return
    with tempfile.TemporaryDirectory(dir=str(runtime)) as temporary:
        local = Path(temporary, "snapshot.db")
        write(local, schema, changes)
        install(local, target)
        os.replace(str(local), str(runtime / "published.db"))


def refresh(runtime, archive):
    """Import new or changed snapshots of other nodes."""
    state = runtime / "seen.json"
    try:
        seen = json.loads(state.read_text())
    except (OSError, ValueError):
        seen = {}  # missing or damaged; importing again is harmless
    own = own_snapshot(runtime)
    current = {}
    with runtime_db(runtime) as db:
        for path in snapshots(archive):
            if path.name == own:
                continue
            try:
                mark = signature(path)
                incoming = None if seen.get(path.name) == mark else load(path, runtime)
            except FileNotFoundError:
                continue  # compacted away
            except sqlite3.DatabaseError as error:
                quarantine(path, archive, error)
                continue
            except OSError as error:
                log("will retry %s: %s" % (path.name, error))
                continue
            if incoming is not None:
                try:
                    merge(db, incoming)
                    merge(db, incoming, "base")
                except SchemaError as error:
                    log("will retry %s: %s" % (path.name, error))
                    continue
            current[path.name] = mark
    temporary = state.with_suffix(".tmp")
    temporary.write_text(json.dumps(current))
    temporary.replace(state)


def quarantine(path, archive, error):
    """Move a damaged shared file aside, so that it cannot block other nodes."""
    bad = private_dir(archive / "bad")
    try:
        path.rename(bad / ("%s.%d" % (path.name, time.time())))
    except OSError:
        return
    log("moved damaged %s to %s (%s)" % (path.name, bad, error))


def compact(runtime, archive):
    """Fold old snapshots into a new base file, then remove what was folded in."""
    cutoff = time.time() - COMPACT_AGE
    for path in (archive / "snapshots").glob(".*"):  # left behind by killed writers
        with contextlib.suppress(FileNotFoundError):
            if path.stat().st_mtime < cutoff:
                path.unlink()
    own = own_snapshot(runtime)
    old = []
    for path in snapshots(archive):
        with contextlib.suppress(FileNotFoundError):
            if path.name != own and path.stat().st_mtime < cutoff:
                old.append(path)
    if len(old) < COMPACT_MIN:
        return
    folded = {}
    with tempfile.TemporaryDirectory(dir=str(runtime)) as temporary:
        base = Path(temporary, "base.db")
        with contextlib.closing(sqlite3.connect(uri(base, "rwc"), uri=True)) as db:
            db.execute("ATTACH DATABASE ? AS local", (uri(runtime / "history.db", "ro"),))
            db.execute(table_sql(db, "local"))
            for path in old:
                try:
                    mark = signature(path)
                    merge(db, load(path, temporary))
                except (OSError, sqlite3.DatabaseError, SchemaError):
                    continue  # refresh reports these files
                folded[path] = mark
            # Apply the deletions known here; their markers may be in snapshots too new to fold.
            merge(db, rows(db.execute("SELECT l.* FROM local.history l JOIN main.history b"
                                      " ON b.id = l.id WHERE l.deleted_at IS NOT NULL")))
        if not folded:
            return
        stamp = time.strftime("%Y%m%d%H%M%S", time.gmtime())
        install(base, archive / "snapshots" / ("base-%s-%s.db" % (stamp, uuid.uuid4().hex[:8])))
    for path, mark in folded.items():
        # Rename before checking: on NFS a plain stat can be stale.
        claimed = path.with_name(".%s.%s" % (path.name, uuid.uuid4().hex))
        try:
            os.rename(str(path), str(claimed))
            if signature(claimed) != mark:  # republished meanwhile; put it back
                with contextlib.suppress(FileExistsError):
                    os.link(str(claimed), str(path))
            claimed.unlink()
        except FileNotFoundError:
            continue  # already gone


def sync(runtime, archive):
    """Save and import, unless another shell on this node is doing it already."""
    lock = try_lock(runtime / "checkpoint.lock")
    if lock is None:
        return
    with lock:
        (runtime / "synced").touch()
        for name in RUNTIME_FILES:  # keeps age-based /tmp cleaners away
            os.utime(str(runtime / name))
        keep_deletions(runtime)  # before imports can restore deleted rows
        refresh(runtime, archive)
        publish(runtime, archive)
        compacted = runtime / "compacted"
        if not compacted.exists() or time.time() - compacted.stat().st_mtime > COMPACT_EVERY:
            compacted.touch()
            compact(runtime, archive)


def checkpoint(runtime, archive):
    """Save before a shell exits. Shells from the previous version use it too."""
    with locked(runtime / "checkpoint.lock"):
        keep_deletions(runtime)
        publish(runtime, archive)


# Setup

def environment(runtime, archive):
    """Variables that keep every Atuin file in the node-local runtime."""
    config = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config", "atuin")
    return {
        "ATUIN_HOME": str(runtime),
        "ATUIN_CONFIG_DIR": str(config),
        # Explicit paths also replace values that older setups exported.
        "ATUIN_DATA_DIR": str(runtime),
        "ATUIN_DB_PATH": str(runtime / "history.db"),
        "ATUIN_RECORD_STORE_PATH": str(runtime / "records.db"),
        "ATUIN_KEY_PATH": str(runtime / "key"),
        "ATUIN_LOGS__DIR": str(runtime / "logs"),
        "ATUIN_AUTO_SYNC": "false",
        "ATUIN_UPDATE_CHECK": "false",
        "ATUIN_DAEMON__ENABLED": "false",
        "ATUIN_DAEMON__AUTOSTART": "false",
        "ATUIN_OUTPUT__ENABLED": "false",
        "ATUIN_OFFLINE_ARCHIVE_DIR": str(archive),
    }


def intact(runtime):
    """False if a /tmp cleaner removed or emptied part of the runtime."""
    return all((runtime / name).exists() and (runtime / name).stat().st_size
               for name in RUNTIME_FILES)


def build(node, archive):
    """Create the node's runtime and fill it from the shared history."""
    private_dir(archive)
    private_dir(archive / "snapshots")
    if not snapshots(archive):
        data = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")
        for legacy in (data / "atuin/history.db", Path.home() / ".atuin/data/history.db"):
            if legacy.exists():
                raise RuntimeError("found history in %s; add it with `python3 %s seed %s`, "
                                   "or move it away to start fresh" % (legacy, __file__, legacy))
    atuin = shutil.which("atuin")
    if atuin is None:
        raise RuntimeError("atuin not found")
    temporary = Path(tempfile.mkdtemp(prefix="build-", dir=str(node)))
    try:
        env = dict(os.environ, ATUIN_SESSION=uuid.uuid4().hex, **environment(temporary, archive))
        # Any history command makes Atuin create and migrate its database.
        subprocess.run([atuin, "history", "list"], env=env, check=True,
                       stdout=subprocess.DEVNULL, timeout=60)
        host = socket.gethostname().split(".")[0]
        (temporary / "snapshot-name").write_text("%s-%s.db" % (host, uuid.uuid4().hex))
        with contextlib.closing(sqlite3.connect(str(temporary / "history.db"))) as history, \
                contextlib.closing(sqlite3.connect(str(temporary / "baseline.db"))) as baseline:
            baseline.execute(table_sql(history))
        refresh(temporary, archive)
        temporary.rename(node / "runtime")
    except BaseException:
        shutil.rmtree(str(temporary), ignore_errors=True)
        raise


def prepare(archive):
    """Make sure this node has a runtime, and return the variables that select it."""
    node = node_dir()
    runtime = node / "runtime"
    with locked(node / "setup.lock"):
        for leftover in node.glob("build-*"):
            shutil.rmtree(str(leftover), ignore_errors=True)
        if runtime.exists() and not intact(runtime):
            try:  # keep its commands before starting over
                seed(runtime / "history.db", archive)
            except Exception as error:
                log("could not keep the commands in %s: %s" % (runtime, error))
            shutil.rmtree(str(runtime))
        if not runtime.exists():
            build(node, archive)
    return environment(runtime, archive)


def seed(database, archive):
    """Add an existing Atuin database, including its WAL, to the shared history."""
    private_dir(archive)
    private_dir(archive / "snapshots")
    with tempfile.TemporaryDirectory(dir=str(node_dir())) as temporary:
        copy = Path(temporary, "history.db")
        shutil.copyfile(str(database), str(copy))
        if Path(str(database) + "-wal").exists():
            shutil.copyfile(str(database) + "-wal", str(copy) + "-wal")
        try:
            with contextlib.closing(sqlite3.connect(str(copy))) as db:  # replays the WAL
                if db.execute("PRAGMA integrity_check").fetchone() != ("ok",):
                    raise sqlite3.DatabaseError("integrity check failed")
                schema, entries = table_sql(db), rows(db.execute("SELECT * FROM history"))
        except sqlite3.DatabaseError as error:
            raise RuntimeError("%s is damaged (%s); try an older copy from ~/.snapshot"
                               % (database, error))
        snapshot = Path(temporary, "seed.db")
        write(snapshot, schema, entries)
        name = "seed-%s.db" % uuid.uuid4().hex
        install(snapshot, archive / "snapshots" / name)
    return len(entries), name


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("command", choices=("prepare", "sync", "checkpoint", "seed"))
    parser.add_argument("database", nargs="?", type=Path, help="Atuin history.db to add (seed)")
    parser.add_argument("--runtime", type=Path, default=os.environ.get("ATUIN_HOME"),
                        help="node runtime (default: $ATUIN_HOME)")
    parser.add_argument("--archive", type=Path, default=default_archive(),
                        help="shared directory (default: %(default)s)")
    args = parser.parse_args()
    if args.command == "prepare":
        for name, value in prepare(args.archive).items():
            print("export %s=%s" % (name, shlex.quote(value)))
    elif args.command == "seed" and args.database:
        print("Added %d commands as %s" % seed(args.database, args.archive))
    elif args.command == "sync" and args.runtime:
        sync(args.runtime, args.archive)
    elif args.command == "checkpoint" and args.runtime:
        checkpoint(args.runtime, args.archive)
    else:
        parser.error("missing argument for " + args.command)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
    except Exception as error:
        log(error)
        sys.exit(1)
