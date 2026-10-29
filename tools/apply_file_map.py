#!/usr/bin/env python3
"""
apply_file_map.py - move files out of _inbox according to the approved file map (ORG-06).

Usage (from the repo root):
    python tools/apply_file_map.py                 # dry run: shows what would move
    python tools/apply_file_map.py --apply         # moves files, logs every move

Rules
  - final_disposition / final_dest override the proposed_* columns when filled.
  - Rows still marked REVIEW stop the run (nothing moves) until they are decided.
  - DATA and DUPLICATE files may only go under archive/ (git-ignored).
  - Nothing is ever deleted. Name clashes get a __<id> suffix.
  - Every move is appended to docs/inventory/moves_log.csv immediately after it completes.
  - Resumable: rows already in moves_log.csv are verified (destination + hash) then skipped.
  - Crash recovery: if source is missing and destination (plain or __<id>) has the expected
    hash, the move is recovered and logged; otherwise the row is blocked.
  - Source hash is verified against inventory.csv before each move.
  - Destinations outside legacy/, docs/reference/, or archive/ (or containing ..) are rejected.
  - Blocked/failed rows are written to --exceptions-out (default docs/inventory/apply_exceptions.csv).
  - Exit non-zero when any row is blocked.
"""
import argparse
import csv
import datetime as dt
import hashlib
import os
import shutil
import sys

VALID = {"KEEP", "ARCHIVE", "DUPLICATE", "DATA", "REVIEW"}
ALLOWED_ROOTS = ("legacy/", "docs/reference/", "archive/")


def sha256(path, chunk=1 << 20):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            b = f.read(chunk)
            if not b:
                break
            h.update(b)
    return h.hexdigest()


def dest_allowed(dest):
    """Return True if dest is within an allowed destination root and has no path traversal."""
    if ".." in dest:
        return False, "path traversal"
    norm = dest.replace("\\", "/").lstrip("/")
    for root in ALLOWED_ROOTS:
        if norm.startswith(root) or norm == root.rstrip("/"):
            return True, ""
    return False, "dest outside allowed tree"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", default="_inbox")
    ap.add_argument("--map", default="docs/inventory/file_map.csv")
    ap.add_argument("--log", default="docs/inventory/moves_log.csv")
    ap.add_argument("--inventory", default="docs/inventory/inventory.csv",
                    help="inventory.csv produced by inventory.py (for expected SHA-256 values)")
    ap.add_argument("--exceptions-out", default="docs/inventory/apply_exceptions.csv",
                    dest="exceptions_out",
                    help="Output path for blocked/failed rows (default: docs/inventory/apply_exceptions.csv)")
    ap.add_argument("--apply", action="store_true")
    a = ap.parse_args()

    # Load expected hashes from inventory.csv.
    expected = {}
    if os.path.exists(a.inventory):
        with open(a.inventory, newline="", encoding="utf-8") as f:
            for row in csv.DictReader(f):
                expected[row["id"]] = row["sha256"]

    # Load already-completed moves from log.
    completed = {}  # id -> destination path
    if os.path.exists(a.log):
        with open(a.log, newline="", encoding="utf-8") as f:
            for row in csv.DictReader(f):
                completed[row["id"]] = row["to"]
    completed_ids = set(completed.keys())

    with open(a.map, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    plan = []
    problems = []
    blocked = []  # (id, src, reason)

    for r in rows:
        disp = (r.get("final_disposition") or r["proposed_disposition"]).strip().upper()
        dest = (r.get("final_dest") or r["proposed_dest"]).strip().strip("/")
        src = os.path.join(a.root, r["rel_path"])

        if disp not in VALID:
            problems.append(f"id {r['id']}: unknown disposition '{disp}'")
            continue
        if disp == "REVIEW":
            problems.append(f"id {r['id']}: still REVIEW -> {r['rel_path']}")
            continue
        if disp in ("DATA", "DUPLICATE") and not dest.startswith("archive"):
            problems.append(f"id {r['id']}: {disp} file must go under archive/, not '{dest}'")
            continue
        if not dest:
            problems.append(f"id {r['id']}: no destination")
            continue

        # Path-traversal / allowed-tree guard.
        ok, reason = dest_allowed(dest)
        if not ok:
            blocked.append((r["id"], src, reason))
            continue

        target = os.path.join(dest, os.path.basename(r["rel_path"]))
        plan.append((r["id"], src, target, disp))

    if problems:
        print("Fix these rows in the file map first (nothing moved):")
        for p in problems:
            print("  -", p)
        sys.exit(1)

    # Handle already-logged rows: verify destination exists with expected hash.
    skipped = 0
    verified_plan = []
    for rid, src, target, disp in plan:
        if rid in completed_ids:
            logged_dest = completed[rid]
            exp_hash = expected.get(rid, "")
            if os.path.exists(logged_dest):
                if exp_hash and sha256(logged_dest) != exp_hash:
                    blocked.append((rid, logged_dest, "logged destination hash mismatch"))
                    print(f"BLOCKED (logged destination hash mismatch) id={rid}")
                else:
                    print(f"SKIP (already moved, verified) id={rid}")
                    skipped += 1
            else:
                blocked.append((rid, logged_dest, "logged destination missing"))
                print(f"BLOCKED (logged destination missing) id={rid}")
            continue
        verified_plan.append((rid, src, target, disp))

    # Resolve name clashes for remaining rows (with existing files and within the plan).
    taken = set()
    final = []
    for rid, src, target, disp in verified_plan:
        t = target
        if os.path.exists(t) or t.lower() in taken:
            stem, ext = os.path.splitext(target)
            t = f"{stem}__{rid}{ext}"
        taken.add(t.lower())
        final.append((rid, src, t, disp))

    # Print plan.
    for rid, src, t, disp in final:
        print(f"{'MOVE' if a.apply else 'would move'} [{disp}] {src} -> {t}")

    total = len(plan)  # total eligible rows

    if not a.apply:
        print(f"\nDry run: {len(final)} files would move, {skipped} already done, "
              f"{len(blocked)} blocked. Re-run with --apply to move them.")
        if blocked:
            _write_exceptions(a.exceptions_out, blocked)
            sys.exit(1)
        return

    # Apply moves.
    moved = 0
    moved_this_run = []  # (rid, dest_path)

    new_log = not os.path.exists(a.log)
    log_fh = open(a.log, "a", newline="", encoding="utf-8")
    try:
        log_writer = csv.writer(log_fh)
        if new_log:
            log_writer.writerow(["timestamp", "id", "disposition", "from", "to"])

        for rid, src, t, disp in final:
            # Check for crash recovery: source missing but no log entry.
            if not os.path.exists(src):
                exp_hash = expected.get(rid, "")
                recovered = None
                stem, ext = os.path.splitext(t)
                alt = f"{stem}__{rid}{ext}"
                for candidate in (t, alt):
                    if os.path.exists(candidate) and exp_hash and sha256(candidate) == exp_hash:
                        recovered = candidate
                        break
                if recovered:
                    # Write the recovery log row.
                    log_writer.writerow([
                        dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                        rid, disp,
                        src.replace("\\", "/"),
                        recovered.replace("\\", "/"),
                    ])
                    log_fh.flush()
                    print(f"RECOVERED (unlogged move) id={rid} at {recovered}")
                    skipped += 1
                    continue
                else:
                    blocked.append((rid, src, "source missing, no verified destination"))
                    print(f"BLOCKED (source missing, no verified destination) id={rid}")
                    continue

            # Verify source hash before moving.
            exp_hash = expected.get(rid, "")
            if exp_hash:
                actual_hash = sha256(src)
                if actual_hash != exp_hash:
                    blocked.append((rid, src, "hash mismatch"))
                    print(f"BLOCKED (hash mismatch) id={rid}")
                    continue

            # Perform the move.
            os.makedirs(os.path.dirname(t), exist_ok=True)
            shutil.move(src, t)
            moved += 1
            moved_this_run.append((rid, t))

            # Write + flush log row immediately after each successful move.
            log_writer.writerow([
                dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                rid, disp,
                src.replace("\\", "/"),
                t.replace("\\", "/"),
            ])
            log_fh.flush()

    finally:
        log_fh.close()

    # Post-run verification: every file moved this run exists at its destination with expected hash.
    for rid, dest_path in moved_this_run:
        exp_hash = expected.get(rid, "")
        if not os.path.exists(dest_path):
            blocked.append((rid, dest_path, "post-run: destination missing"))
        elif exp_hash and sha256(dest_path) != exp_hash:
            blocked.append((rid, dest_path, "post-run: destination hash mismatch"))

    # Remove now-empty folders inside the inbox (folders only, never files).
    for dirpath, dirnames, filenames in os.walk(a.root, topdown=False):
        if dirpath != a.root and not os.listdir(dirpath):
            os.rmdir(dirpath)

    # Reconciliation.
    print(f"\nmoved={moved} skipped={skipped} blocked={len(blocked)} total={total}")
    assert moved + skipped + len(blocked) == total, (
        f"Reconciliation failed: {moved}+{skipped}+{len(blocked)} != {total}"
    )

    _write_exceptions(a.exceptions_out, blocked)
    print(f"Exceptions: {a.exceptions_out}")

    if blocked:
        print(f"ERROR: {len(blocked)} row(s) blocked or failed. See {a.exceptions_out}")
        sys.exit(1)


def _write_exceptions(path, blocked):
    """Write blocked/failed rows to the exceptions file (header always written)."""
    os.makedirs(os.path.dirname(path) if os.path.dirname(path) else ".", exist_ok=True)
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["id", "source", "reason"])
        for rid, src, reason in blocked:
            w.writerow([rid, src, reason])


if __name__ == "__main__":
    main()
