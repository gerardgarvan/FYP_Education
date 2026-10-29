---
phase: 01-inventory-triage
plan: "01"
subsystem: tools
tags: [inventory, apply, D-05, D-19, smoke-test, python]
dependency_graph:
  requires: []
  provides:
    - tools/inventory.py with REF_RE, FOLDER_RE, OUTFILE_RE, is_junk(), missing_references.md
    - tools/apply_file_map.py with resumable+hash-verified apply, path guard, exceptions output
    - tools/test_phase1_smoke.py end-to-end validation
  affects:
    - Phase 1 Plans 02-04 (import is_junk from inventory; rely on hardened apply)
    - docs/inventory/missing_references.md (generated when scan runs)
tech_stack:
  added: []
  patterns:
    - Quoted-string-only reference capture (REF_RE) with OUTFILE/FOLDER separation
    - Dynamic-first reference classification before name matching
    - Per-move log flush with crash recovery (source-missing + hash-verified dest)
    - Path-traversal guard on apply destinations
key_files:
  created:
    - tools/test_phase1_smoke.py
  modified:
    - tools/inventory.py
    - tools/apply_file_map.py
decisions:
  - "REF_RE requires quotes on both sides of each construct; bare identifiers are silently excluded"
  - "FOLDER_RE captures libname/filename paths separately; PATH_RE suppressed from re-adding them"
  - "outfile=/out= targets collected in OUTFILE_RE and prefixed out: so post-scan excludes them from missing check"
  - "Crash recovery checks both t (clash-resolved name) and original target in case prior run used the plain name"
metrics:
  duration_minutes: 45
  completed_date: "2026-10-28"
  tasks_completed: 3
  files_changed: 3
---

# Phase 01 Plan 01: Tool Hardening (D-05, D-19) Summary

**One-liner:** Quoted-string reference capture with dynamic-first classification, missing_references.md, and hash-verified resumable apply with crash recovery and path-traversal guard.

## What Was Built

### Task 1 — inventory.py D-05 extension (commit 81b3760)

Added three new regex constants alongside the existing `PATH_RE`:

- `REF_RE`: captures the file argument from quoted-string constructs only (`%include "..."`, `datafile="..."`, `infile "..."`, `read.csv("...")`, `read_excel(...)`, `readRDS(...)`, `source(...)`, `open(...)`). Bare unquoted identifiers are not captured.
- `FOLDER_RE`: captures the quoted path argument of `libname <name> "..."` and `filename <name> "..."` statements — these are directories, not file references.
- `OUTFILE_RE`: captures `outfile="..."` and `out="..."` write targets so they can be excluded from the missing-reference classification.

`scan_text()` now collects folder and output references first, then suppresses any `PATH_RE` match that duplicates a folder arg or outfile target, so those absolute paths never re-enter the file-reference list. All entries go into `paths_referenced` with prefixes (`folder:`, `out:`, plain).

The 8-reference cap was removed entirely.

`JUNK_NAMES` and `is_junk()` were extracted to module level so Plans 02 and 04 can import them.

`main()` gained a `write_missing_references()` post-scan pass that:
- Builds a case-insensitive name-count map of inventoried files.
- Classifies each read-reference: Dynamic first (macro variables / string concat), then resolved (exact match), then tentative (multiple matches), then On P: (expected), then Local and missing.
- Writes `docs/inventory/missing_references.md` with four sections: Dynamic, On P:, Local and missing, Folders referenced.

Column names and order in `inventory.csv` and `file_map.csv` are unchanged.

### Task 2 — apply_file_map.py D-19 hardening (commit 87a05cd)

Added `--inventory` and `--exceptions-out` arguments. No validation-skipping input was added.

Key behavioral changes:
- **Resumable**: rows already in `moves_log.csv` are verified (destination exists + SHA-256 matches expected) and skipped. Failed verification → blocked.
- **Crash recovery**: if source is missing and no log entry exists, the tool checks the plain destination and the `__<id>` variant. If either has the expected hash, the log row is written (RECOVERED) and the run continues.
- **Source hash verification**: before each `shutil.move`, the source's SHA-256 is compared to `inventory.csv`. Mismatch → blocked.
- **Path-traversal guard**: any destination containing `..` or outside `legacy/`, `docs/reference/`, `archive/` is rejected before any move.
- **Per-move flush**: log file opened in append mode; each row written and flushed immediately after its move.
- **Post-run reconciliation**: every file moved this run is verified at its destination; `moved + skipped + blocked == total` is asserted and printed.
- **Exceptions output**: `apply_exceptions.csv` always written (header + any blocked rows). Exit non-zero on any block.

Existing guards (REVIEW stop, DATA/DUPLICATE archive-only, dry-run) are intact.

### Task 3 — test_phase1_smoke.py (commit 734646f)

Created `tools/test_phase1_smoke.py` using standard library only. Runs the real tools as subprocesses with `cwd=<tmpdir>` so the real repo tree is never touched.

**Part A** — inventory reference classification:
- Builds a synthetic `_inbox/` with `a.sas` containing `%include "b.sas"`, a `libname` with a P: path, `read.csv("gone_local.csv")`, a dynamic reference `%include "&root.\dyn.sas"`, `outfile="exported.csv"`, and a bare unquoted `datafile=bare_unquoted`.
- Asserts: `gone_local.csv` → Local and missing; `dyn.sas` → Dynamic; P: libname folder → Folders referenced (not On P:); `b.sas` → resolved (not missing); `exported.csv` → not in any gap section; `bare_unquoted` → not captured.
- Asserts `Thumbs.db` and `~$lock.docx` absent from inventory.csv; `is_junk()` returns correct values.

**Part B** — six apply scenarios, each in an isolated temp dir with try/finally cleanup:
1. Normal move: file at dest, one log row, exit 0.
2. Idempotent: second run skips already-logged row, still exit 0, one log row.
3. Hash mismatch: source untouched, exit non-zero, "hash mismatch" in exceptions.
4. Name clash: pre-existing dest preserved; source lands at `<stem>__<id><ext>`; exit 0.
5. Crash recovery: last log row deleted → RECOVERED on re-run; variant with `__<id>` dest also tested.
6. Corrupted logged destination: re-run blocks with "logged destination hash mismatch"; exit non-zero.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Crash recovery candidate search used only the clash-resolved name**

- **Found during:** Task 3 (Scenario 5 failure)
- **Issue:** `apply_file_map.py` built the crash recovery candidates from `t` (the clash-resolved destination). On re-run after a crash, `t` might be the `__<id>` variant because the plain destination now exists. But the file was actually placed at the plain destination during the original run — so neither candidate matched.
- **Fix:** Added the original pre-clash `target` and its `__<id>` variant to the candidate list so all four possibilities are checked.
- **Files modified:** `tools/apply_file_map.py`
- **Commit:** 734646f

**2. [Rule 1 - Bug] Smoke test path resolution for log's `to` field**

- **Found during:** Task 3 (Scenario 6 failure)
- **Issue:** `moves_log.csv` stores relative destination paths (e.g., `legacy/sas/h.sas`). The test script resolved them from the repo root instead of `tmpdir`, so the overwrite landed in the wrong place.
- **Fix:** Resolve `dest_path` relative to `tmpdir` when the log entry is a relative path.
- **Files modified:** `tools/test_phase1_smoke.py`
- **Commit:** 734646f (same commit as above)

## Known Stubs

None. Both tools produce real output. The smoke test validates on synthetic input.

## Self-Check: PASSED

- `tools/inventory.py` — exists, parses, `--help` runs.
- `tools/apply_file_map.py` — exists, parses, `--help` runs.
- `tools/test_phase1_smoke.py` — exists, `python tools/test_phase1_smoke.py` prints `SMOKE OK`.
- Commits: 81b3760, 87a05cd, 734646f — all present in `git log`.
- `_inbox/` contains only `.gitkeep`.
