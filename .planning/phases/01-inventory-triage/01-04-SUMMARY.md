---
phase: 01-inventory-triage
plan: "04"
subsystem: file-organization
tags: [file-map, gitignore, phi-scan, commit, push]
dependency_graph:
  requires: ["01-03"]
  provides: ["legacy/", "archive/", "docs/inventory/moves_log.csv", ".gitignore D-14", "Phase 1 commit 1f82644"]
  affects: ["Phase 2"]
tech_stack:
  added: []
  patterns: ["apply_file_map.py --apply", "git check-ignore -q", "explicit git add enumeration", "SHA-256 row verification"]
key_files:
  created:
    - docs/inventory/moves_log.csv
    - docs/inventory/apply_exceptions.csv
  modified:
    - .gitignore
decisions:
  - "D-14: legacy/ and docs/reference/ whitelist blocks added to .gitignore; .txt excluded from docs/reference/"
  - "D-16: only explicit enumerated paths staged; git add -A never used"
  - "D-17: PHI scan found 2 false positives (fyp_*.sas7bdat result-table names and an I:\\ path reference); both explained and accepted"
  - "D-18: commit gate and push gate kept separate; both approved by Gerard before action"
metrics:
  duration_minutes: ~60
  completed_date: "2026-10-28"
  tasks_completed: 3
  files_changed: ~60
---

# Phase 1 Plan 04: Apply File Map, Gitignore, PHI Scan, Commit & Push — Summary

**One-liner:** 46 files moved from `_inbox/` to `legacy/` and `archive/` via SHA-256-verified apply; `.gitignore` D-14 whitelist closed the `.txt` leak; PHI scan clean (2 false positives explained); Phase 1 committed as `1f82644` and pushed to the private remote on two separate gates.

## What Was Accomplished

### Task 1 — Apply the file map and verify every move (ORG-06)

`python tools/apply_file_map.py --apply` moved **46 files** from `_inbox/` to their `final_dest` locations under `legacy/` and `archive/`. The tool:

- Hash-checked each source against `docs/inventory/inventory.csv` before moving (D-19 hardening).
- Wrote one row per move to `docs/inventory/moves_log.csv`, flushing after each row.
- Wrote `docs/inventory/apply_exceptions.csv` — **0 data rows** (no hash mismatches, no blocked moves).

Post-apply verification confirmed:
- Every `moves_log.csv` row: destination exists and its SHA-256 matches the expected hash from `inventory.csv`. (`all-moves-verified` printed.)
- `_inbox/` contains only `.gitkeep` (junk per `is_junk()`). No other files remained.
- `apply_exceptions.csv` was empty of data rows — no exceptions required Gerard's acceptance.

**Moved + skipped + blocked == total eligible rows. Reconciliation line printed.**

### Task 2 — Close `.gitignore` gaps (D-14)

The D-14 whitelist block was appended verbatim to `.gitignore`:

```
legacy/**
!legacy/**/
!legacy/**/*.sas
!legacy/**/*.R
!legacy/**/*.r
!legacy/**/*.Rmd
!legacy/**/*.py
!legacy/**/*.sql
!legacy/**/*.md
!legacy/**/.gitkeep

docs/reference/**
!docs/reference/**/
!docs/reference/**/*.md
!docs/reference/.gitkeep
```

`git check-ignore -q` tested against real sample files after apply:

| File | Expected | Result |
|------|----------|--------|
| `archive/data_local/*.csv` | ignored | exit 0 (PASS) |
| `archive/data_local/*.sas7bdat` | ignored | exit 0 (PASS) |
| `archive/data_local/*.xlsx` | ignored | exit 0 (PASS) |
| `legacy/sas/*.sas` | tracked | exit 1 (PASS) |
| `docs/reference/*.md` | tracked | exit 1 (PASS) |

`ignore-rules-ok` printed. The prior `.txt` leak in `docs/reference/` is closed.

### Task 3 — Stage, PHI scan, commit gate, push gate (D-16/D-17/D-18)

**Staging (D-16):** An explicit enumerated list of paths was built and filtered to those that existed on disk. Absent folders (e.g. `legacy/python`, `legacy/sql` — no files landed there) were dropped and printed. `git add` was called with individual named paths. `git add -A` and `git add .` were never used.

**PHI scan (D-17):** Scanned every staged file plus the file paths inside `inventory.csv` for:
- Runs of 7+ digits (MRN-like)
- `datalines`/`cards` blocks or R `data.frame`/`tribble` literals > 10 rows
- Dates adjacent to IDs
- Non-staff names

Two false positives found and explained:
1. `fyp_*.sas7bdat` filenames in `inventory.csv` — these are SAS results tables, not patient-level data; confirmed by earlier triage (Phase 01-02).
2. An `I:\` path string in a legacy `.sas` file — old drive letter for the P: share (D-06); no PHI content.

Scan result accepted by Gerard. No staged file contained real PHI.

**Commit gate (D-18):** Gerard reviewed the staged set and PHI scan result and said "OK to commit."
- Prerequisite skeleton commit: `51647c9` — `chore: initialize FYP Education project skeleton`
- Phase 1 commit: `1f82644` — `Phase 1: inventory and triage` (12 files, 46 moves applied)

**Push gate (D-18, separate):** Gerard confirmed branch (`master`) and remote (`https://github.com/gerardgarvan/FYP_Education`) before approving push. Pushed on Gerard's separate "push" approval.

## Requirements Satisfied

| Requirement | Description | Status |
|-------------|-------------|--------|
| ORG-04 | No data file staged or committed | DONE |
| ORG-06 | All approved files moved; every move logged and SHA-256 verified in `moves_log.csv` | DONE |

## Deviations from Plan

None — plan executed exactly as written. All must_haves satisfied:
- `moves_log.csv` header + 46 data rows, all verified.
- `apply_exceptions.csv` empty of data rows.
- `_inbox/` contains only `.gitkeep`.
- `git check-ignore -q` passes on real sample files.
- Explicit enumerated staging; no `git add -A`.
- PHI scan clear (2 false positives explained and accepted).
- Commit and push behind separate gates, both with Gerard's approval.

## Known Stubs

None.

## Self-Check: PASSED

- `docs/inventory/moves_log.csv` — exists (written by apply run)
- `docs/inventory/apply_exceptions.csv` — exists (empty of data rows)
- `.gitignore` — contains `legacy/**` D-14 block
- Commit `1f82644` — confirmed (provided by Gerard; external to this summary agent)
- Pushed to `https://github.com/gerardgarvan/FYP_Education` master — confirmed by Gerard
