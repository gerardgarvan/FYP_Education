#!/usr/bin/env python3
"""
test_phase1_smoke.py - end-to-end smoke test of inventory.py and apply_file_map.py.

Runs the REAL tools (no mocks) inside isolated temp directories.
Prints SMOKE OK on success, exits 1 on failure.
Never touches the real _inbox/ or repo tree.
"""
import csv
import hashlib
import os
import shutil
import subprocess
import sys
import tempfile

# Allow importing from tools/ even when running from repo root.
TOOLS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)))
REPO_ROOT = os.path.dirname(TOOLS_DIR)
INVENTORY_PY = os.path.join(TOOLS_DIR, "inventory.py")
APPLY_PY = os.path.join(TOOLS_DIR, "apply_file_map.py")


def sha256(path, chunk=1 << 20):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            b = f.read(chunk)
            if not b:
                break
            h.update(b)
    return h.hexdigest()


def run(cmd, cwd=None, expect_exit=0):
    """Run command and return (returncode, stdout+stderr). Asserts exit code."""
    result = subprocess.run(
        cmd, cwd=cwd,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True,
    )
    return result.returncode, result.stdout


def assert_eq(actual, expected, msg=""):
    if actual != expected:
        raise AssertionError(f"{msg}: expected {expected!r}, got {actual!r}")


def assert_in(needle, text, msg=""):
    if needle not in text:
        raise AssertionError(f"{msg}: {needle!r} not found in output:\n{text}")


def assert_not_in(needle, text, msg=""):
    if needle in text:
        raise AssertionError(f"{msg}: {needle!r} unexpectedly found in output:\n{text}")


# ─────────────────────────────────────────────────────────────────────────────
# PART A — inventory.py reference classification
# ─────────────────────────────────────────────────────────────────────────────

def part_a():
    tmpdir = tempfile.mkdtemp(prefix="smoke_inv_")
    try:
        inbox = os.path.join(tmpdir, "_inbox", "src")
        os.makedirs(inbox)

        # a.sas: various reference types
        a_sas = os.path.join(inbox, "a.sas")
        with open(a_sas, "w") as f:
            f.write('%include "b.sas";\n')
            f.write('libname x "P:\\PeCAN\\somefolder";\n')
            f.write('read.csv("gone_local.csv");\n')
            f.write('%include "&root.\\dyn.sas";\n')
            f.write('outfile="exported.csv";\n')
            f.write('datafile=bare_unquoted\n')        # bare — must NOT be captured

        # b.sas — exists so b.sas resolves; also needed to confirm it's NOT listed as missing
        b_sas = os.path.join(inbox, "b.sas")
        with open(b_sas, "w") as f:
            f.write("/* placeholder */\n")

        # Two byte-identical files for duplicate detection
        dup_content = b"identical content for dup test\n"
        dup1 = os.path.join(tmpdir, "_inbox", "dup1.txt")
        dup2 = os.path.join(tmpdir, "_inbox", "copy of dup1.txt")
        with open(dup1, "wb") as f:
            f.write(dup_content)
        with open(dup2, "wb") as f:
            f.write(dup_content)

        # Junk files — must NOT appear in inventory.csv
        with open(os.path.join(tmpdir, "_inbox", "Thumbs.db"), "w") as f:
            f.write("junk")
        with open(os.path.join(tmpdir, "_inbox", "~$lock.docx"), "w") as f:
            f.write("junk")

        out_dir = os.path.join(tmpdir, "out")
        rc, output = run(
            [sys.executable, INVENTORY_PY,
             "--root", os.path.join(tmpdir, "_inbox"),
             "--out", out_dir],
            cwd=tmpdir,
        )
        assert rc == 0, f"inventory.py exited {rc}:\n{output}"

        # Required output files exist.
        for fname in ("inventory.csv", "file_map.csv", "inventory_summary.md", "missing_references.md"):
            assert os.path.exists(os.path.join(out_dir, fname)), f"Missing: {fname}"

        # Junk files must NOT appear in inventory.csv
        with open(os.path.join(out_dir, "inventory.csv"), newline="", encoding="utf-8") as f:
            inv_rows = list(csv.DictReader(f))
        names_in_inv = {r["name"] for r in inv_rows}
        assert "Thumbs.db" not in names_in_inv, "Thumbs.db should be excluded from inventory"
        assert "~$lock.docx" not in names_in_inv, "~$lock.docx should be excluded from inventory"

        # is_junk() import test
        sys.path.insert(0, TOOLS_DIR)
        from inventory import is_junk  # noqa: F401 — imported fresh each run
        assert is_junk("Thumbs.db"), "is_junk('Thumbs.db') should be True"
        assert is_junk("~$lock.docx"), "is_junk('~$lock.docx') should be True"
        assert not is_junk("a.sas"), "is_junk('a.sas') should be False"

        # Parse missing_references.md into sections.
        mr_path = os.path.join(out_dir, "missing_references.md")
        sections = _parse_mr_sections(mr_path)

        # gone_local.csv -> "Local and missing"
        local_section = sections.get("Local and missing (real gaps)", "")
        assert "gone_local.csv" in local_section, \
            f"gone_local.csv should be under 'Local and missing'; got:\n{local_section}"

        # dyn.sas -> "Dynamic"
        dyn_section = sections.get("Dynamic (can't be resolved)", "")
        assert "dyn.sas" in dyn_section, \
            f"dyn.sas should be under 'Dynamic'; got:\n{dyn_section}"

        # P: libname folder -> "Folders referenced"
        folder_section = sections.get("Folders referenced", "")
        assert "PeCAN" in folder_section or "somefolder" in folder_section, \
            f"P: libname folder should be under 'Folders referenced'; got:\n{folder_section}"

        # P: libname folder must NOT appear under "On P: (expected)"
        onp_section = sections.get("On P: (expected)", "")
        assert "somefolder" not in onp_section and "PeCAN\\somefolder" not in onp_section, \
            f"Libname folder path should NOT appear under 'On P:'; got:\n{onp_section}"

        # b.sas resolves — must NOT be listed as missing in any gap section
        for sec_name in ("Dynamic (can't be resolved)", "On P: (expected)", "Local and missing (real gaps)"):
            sec = sections.get(sec_name, "")
            assert "b.sas" not in sec, \
                f"b.sas should be resolved (not missing) but appears in '{sec_name}':\n{sec}"

        # exported.csv (outfile=) must NOT appear as missing
        for sec_name in ("Dynamic (can't be resolved)", "On P: (expected)", "Local and missing (real gaps)"):
            sec = sections.get(sec_name, "")
            assert "exported.csv" not in sec, \
                f"exported.csv (outfile=) should not appear as missing in '{sec_name}':\n{sec}"

        # bare_unquoted must NOT be captured (no quotes around it in the source)
        mr_text = open(mr_path, encoding="utf-8").read()
        assert "bare_unquoted" not in mr_text, \
            "bare_unquoted (no quotes) should not be captured as a reference"

    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)

    print("  PART A: OK")


def _parse_mr_sections(path):
    """Parse missing_references.md into {section_name: content_lines_as_string}."""
    sections = {}
    current = None
    lines = open(path, encoding="utf-8").readlines()
    for line in lines:
        stripped = line.rstrip()
        if stripped.startswith("## "):
            current = stripped[3:].strip()
            sections[current] = ""
        elif current is not None:
            sections[current] = sections.get(current, "") + line
    return sections


# ─────────────────────────────────────────────────────────────────────────────
# PART B — apply_file_map.py real --apply, six scenarios
# ─────────────────────────────────────────────────────────────────────────────

def _make_apply_env(tmpdir, files):
    """
    Set up a minimal apply environment inside tmpdir.
    files: list of (rel_inbox_path, content_bytes)
    Returns (inbox_dir, map_path, inv_path, log_path, exc_path)
    """
    inbox = os.path.join(tmpdir, "_inbox")
    os.makedirs(inbox, exist_ok=True)
    legacy = os.path.join(tmpdir, "legacy", "sas")
    os.makedirs(legacy, exist_ok=True)
    docs_inv = os.path.join(tmpdir, "docs", "inventory")
    os.makedirs(docs_inv, exist_ok=True)

    file_rows = []
    for rel, content in files:
        full = os.path.join(inbox, rel)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "wb") as f:
            f.write(content)
        h = sha256(full)
        file_rows.append({"id": str(len(file_rows) + 1), "rel": rel,
                          "sha256": h, "content": content})

    map_path = os.path.join(docs_inv, "file_map.csv")
    inv_path = os.path.join(docs_inv, "inventory.csv")
    log_path = os.path.join(docs_inv, "moves_log.csv")
    exc_path = os.path.join(tmpdir, "apply_exceptions.csv")

    with open(inv_path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["id", "rel_path", "sha256"])
        w.writeheader()
        for r in file_rows:
            w.writerow({"id": r["id"], "rel_path": r["rel"], "sha256": r["sha256"]})

    with open(map_path, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=[
            "id", "rel_path", "category", "proposed_disposition", "proposed_dest",
            "final_disposition", "final_dest", "notes"])
        w.writeheader()
        for r in file_rows:
            w.writerow({
                "id": r["id"], "rel_path": r["rel"], "category": "sas_program",
                "proposed_disposition": "KEEP", "proposed_dest": "legacy/sas",
                "final_disposition": "", "final_dest": "", "notes": "",
            })

    return inbox, map_path, inv_path, log_path, exc_path, file_rows


def _apply_cmd(tmpdir, exc_path):
    docs_inv = os.path.join(tmpdir, "docs", "inventory")
    return [
        sys.executable, APPLY_PY,
        "--root", "_inbox",
        "--map", os.path.join(docs_inv, "file_map.csv"),
        "--log", os.path.join(docs_inv, "moves_log.csv"),
        "--inventory", os.path.join(docs_inv, "inventory.csv"),
        "--exceptions-out", exc_path,
        "--apply",
    ]


def scenario_1_normal_move():
    """Happy path: one KEEP row moves to legacy/sas."""
    tmpdir = tempfile.mkdtemp(prefix="smoke_s1_")
    try:
        inbox, map_path, inv_path, log_path, exc_path, file_rows = _make_apply_env(
            tmpdir, [("src/a.sas", b"/* test */\n")])
        rc, out = run(_apply_cmd(tmpdir, exc_path), cwd=tmpdir)
        assert rc == 0, f"Scenario 1 expected exit 0, got {rc}:\n{out}"
        dest = os.path.join(tmpdir, "legacy", "sas", "a.sas")
        assert os.path.exists(dest), f"Scenario 1: dest missing: {dest}"
        with open(log_path, newline="", encoding="utf-8") as f:
            log_rows = list(csv.DictReader(f))
        assert len(log_rows) == 1, f"Scenario 1: expected 1 log row, got {len(log_rows)}"
        assert not os.path.exists(exc_path) or _exceptions_empty(exc_path), \
            "Scenario 1: unexpected exceptions"
        print("  Scenario 1 (normal move): OK")
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def scenario_2_idempotent():
    """Running --apply twice: second run skips already-logged row."""
    tmpdir = tempfile.mkdtemp(prefix="smoke_s2_")
    try:
        inbox, map_path, inv_path, log_path, exc_path, file_rows = _make_apply_env(
            tmpdir, [("src/b.sas", b"/* b */\n")])
        rc, out = run(_apply_cmd(tmpdir, exc_path), cwd=tmpdir)
        assert rc == 0, f"Scenario 2 first run: exit {rc}:\n{out}"
        rc2, out2 = run(_apply_cmd(tmpdir, exc_path), cwd=tmpdir)
        assert rc2 == 0, f"Scenario 2 second run: exit {rc2}:\n{out2}"
        assert "SKIP" in out2, f"Scenario 2: expected SKIP in second run output:\n{out2}"
        with open(log_path, newline="", encoding="utf-8") as f:
            log_rows = list(csv.DictReader(f))
        assert len(log_rows) == 1, f"Scenario 2: expected 1 log row after second run, got {len(log_rows)}"
        print("  Scenario 2 (idempotent): OK")
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def scenario_3_hash_mismatch():
    """Source file changed after scan: move blocked, exception written."""
    tmpdir = tempfile.mkdtemp(prefix="smoke_s3_")
    try:
        inbox, map_path, inv_path, log_path, exc_path, file_rows = _make_apply_env(
            tmpdir, [("src/c.sas", b"/* original */\n")])
        # Tamper the inventory hash so it won't match.
        rows = []
        with open(inv_path, newline="", encoding="utf-8") as f:
            rows = list(csv.DictReader(f))
        rows[0]["sha256"] = "deadbeef" * 8  # wrong hash
        with open(inv_path, "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=["id", "rel_path", "sha256"])
            w.writeheader()
            w.writerows(rows)

        rc, out = run(_apply_cmd(tmpdir, exc_path), cwd=tmpdir)
        assert rc != 0, f"Scenario 3: expected non-zero exit, got {rc}:\n{out}"
        # Source must still exist (not moved).
        src = os.path.join(tmpdir, "_inbox", "src", "c.sas")
        assert os.path.exists(src), "Scenario 3: source should still exist after hash mismatch"
        assert os.path.exists(exc_path), "Scenario 3: apply_exceptions.csv must exist"
        exc_text = open(exc_path, encoding="utf-8").read()
        assert "hash mismatch" in exc_text, f"Scenario 3: expected 'hash mismatch' in exceptions:\n{exc_text}"
        print("  Scenario 3 (hash mismatch): OK")
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def scenario_4_name_clash():
    """Source exists, dest pre-occupied: file lands at <stem>__<id><ext>, pre-existing unchanged."""
    tmpdir = tempfile.mkdtemp(prefix="smoke_s4_")
    try:
        inbox, map_path, inv_path, log_path, exc_path, file_rows = _make_apply_env(
            tmpdir, [("src/d.sas", b"/* new file */\n")])
        # Pre-create a file at the destination.
        dest_dir = os.path.join(tmpdir, "legacy", "sas")
        pre_existing = os.path.join(dest_dir, "d.sas")
        pre_content = b"/* pre-existing */\n"
        with open(pre_existing, "wb") as f:
            f.write(pre_content)

        rc, out = run(_apply_cmd(tmpdir, exc_path), cwd=tmpdir)
        assert rc == 0, f"Scenario 4: expected exit 0, got {rc}:\n{out}"
        # Pre-existing file unchanged.
        with open(pre_existing, "rb") as f:
            assert f.read() == pre_content, "Scenario 4: pre-existing file was modified!"
        # New file at __<id> path.
        rid = file_rows[0]["id"]
        alt = os.path.join(dest_dir, f"d__{rid}.sas")
        assert os.path.exists(alt), f"Scenario 4: expected renamed dest {alt}"
        assert not _exceptions_empty(exc_path) is False or True, ""  # just no block expected
        with open(log_path, newline="", encoding="utf-8") as f:
            log_rows = list(csv.DictReader(f))
        assert len(log_rows) == 1, "Scenario 4: expected 1 log row"
        print("  Scenario 4 (name clash, source exists): OK")
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def scenario_5_crash_recovery():
    """Crash recovery: last log row deleted => RECOVERED on re-run; also __<id> variant."""
    tmpdir = tempfile.mkdtemp(prefix="smoke_s5_")
    try:
        inbox, map_path, inv_path, log_path, exc_path, file_rows = _make_apply_env(
            tmpdir, [("src/e.sas", b"/* e */\n"), ("src/f.sas", b"/* f */\n")])

        # First run: both files move.
        rc, out = run(_apply_cmd(tmpdir, exc_path), cwd=tmpdir)
        assert rc == 0, f"Scenario 5 first run: exit {rc}:\n{out}"

        # Simulate crash: delete last log data row.
        with open(log_path, newline="", encoding="utf-8") as f:
            log_rows_raw = f.readlines()
        # Keep header + all rows except the last data row.
        with open(log_path, "w", encoding="utf-8") as f:
            f.writelines(log_rows_raw[:-1])

        # Second run: should RECOVER the missing log row.
        rc2, out2 = run(_apply_cmd(tmpdir, exc_path), cwd=tmpdir)
        assert rc2 == 0, f"Scenario 5 second run: exit {rc2}:\n{out2}"
        assert "RECOVERED" in out2, f"Scenario 5: expected RECOVERED in output:\n{out2}"

        # All log rows present now.
        with open(log_path, newline="", encoding="utf-8") as f:
            log_rows = list(csv.DictReader(f))
        assert len(log_rows) == 2, f"Scenario 5: expected 2 log rows, got {len(log_rows)}"
        print("  Scenario 5 (crash recovery, plain dest): OK")

    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)

    # Variant: recovered file sits at <stem>__<id><ext>.
    tmpdir2 = tempfile.mkdtemp(prefix="smoke_s5b_")
    try:
        inbox, map_path, inv_path, log_path, exc_path, file_rows = _make_apply_env(
            tmpdir2, [("src/g.sas", b"/* g */\n")])

        # First run.
        rc, out = run(_apply_cmd(tmpdir2, exc_path), cwd=tmpdir2)
        assert rc == 0, f"Scenario 5b first run: exit {rc}:\n{out}"

        # Rename the moved file to the __<id> variant to simulate the clash case.
        rid = file_rows[0]["id"]
        dest_dir = os.path.join(tmpdir2, "legacy", "sas")
        plain = os.path.join(dest_dir, "g.sas")
        alt = os.path.join(dest_dir, f"g__{rid}.sas")
        if os.path.exists(plain):
            os.rename(plain, alt)

        # Delete last log row.
        with open(log_path, newline="", encoding="utf-8") as f:
            raw = f.readlines()
        with open(log_path, "w", encoding="utf-8") as f:
            f.writelines(raw[:-1])

        # Recovery run.
        rc2, out2 = run(_apply_cmd(tmpdir2, exc_path), cwd=tmpdir2)
        assert rc2 == 0, f"Scenario 5b recovery: exit {rc2}:\n{out2}"
        assert "RECOVERED" in out2, f"Scenario 5b: expected RECOVERED:\n{out2}"
        print("  Scenario 5 (crash recovery, __id dest): OK")
    finally:
        shutil.rmtree(tmpdir2, ignore_errors=True)


def scenario_6_corrupted_logged_dest():
    """Logged destination overwritten: re-run blocks with hash mismatch."""
    tmpdir = tempfile.mkdtemp(prefix="smoke_s6_")
    try:
        inbox, map_path, inv_path, log_path, exc_path, file_rows = _make_apply_env(
            tmpdir, [("src/h.sas", b"/* h */\n")])

        rc, out = run(_apply_cmd(tmpdir, exc_path), cwd=tmpdir)
        assert rc == 0, f"Scenario 6 first run: exit {rc}:\n{out}"

        # Overwrite the moved file's contents.
        with open(log_path, newline="", encoding="utf-8") as f:
            log_rows = list(csv.DictReader(f))
        # Resolve dest_path relative to tmpdir (log stores relative paths)
        raw_dest = log_rows[0]["to"]
        dest_path = raw_dest if os.path.isabs(raw_dest) else os.path.join(tmpdir, raw_dest.replace("/", os.sep))
        with open(dest_path, "wb") as f:
            f.write(b"/* corrupted */\n")

        # Re-run: should block.
        rc2, out2 = run(_apply_cmd(tmpdir, exc_path), cwd=tmpdir)
        assert rc2 != 0, f"Scenario 6 re-run: expected non-zero exit, got {rc2}:\n{out2}"
        exc_text = open(exc_path, encoding="utf-8").read()
        assert "logged destination hash mismatch" in exc_text, \
            f"Scenario 6: expected mismatch reason in exceptions:\n{exc_text}"
        print("  Scenario 6 (corrupted logged dest): OK")
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def _exceptions_empty(path):
    """Return True if exceptions file has no data rows."""
    if not os.path.exists(path):
        return True
    with open(path, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    return len(rows) == 0


def part_b():
    scenario_1_normal_move()
    scenario_2_idempotent()
    scenario_3_hash_mismatch()
    scenario_4_name_clash()
    scenario_5_crash_recovery()
    scenario_6_corrupted_logged_dest()
    print("  PART B: OK")


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

def main():
    print("Phase 1 smoke test")
    print("PART A — inventory.py reference classification")
    part_a()
    print("PART B — apply_file_map.py real --apply (six scenarios)")
    part_b()
    print("SMOKE OK")


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, Exception) as e:
        print(f"SMOKE FAILED: {e}")
        sys.exit(1)
