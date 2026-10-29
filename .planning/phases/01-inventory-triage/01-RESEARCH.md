# Phase 1: Inventory & Triage - Research

**Researched:** 2026-10-28
**Domain:** Python file-management tooling (inventory.py, apply_file_map.py), git data-safety, CSV metadata workflows
**Confidence:** HIGH — all findings come from direct code inspection of the existing tools and CONTEXT.md decisions; no external library research needed.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Copy entire folder trees as-is; do not flatten.
- **D-02:** Each source location gets its own top-level subfolder in `_inbox/` named after its origin.
- **D-03:** Copy code, docs, slides, logs, notes and aggregate outputs only. Do NOT copy patient-level data files to the home PC. List them in `SOURCES.md` instead.
- **D-04:** Source checklist lives in `.planning/phases/01-inventory-triage/SOURCES.md`. Gerard ticks off each item before the scan runs.
- **D-05:** Extend `inventory.py` to capture relative and bare-filename references (not just full paths) and remove the 8-per-file cap. Cover `%include`, `datafile=`, `infile`, `filename`, `libname`, `out=`/`outfile=`, `read.csv`, `read_excel`, `readRDS`, `source`, `open(`. Write `docs/inventory/missing_references.md` with three groups: On P: (expected), Local and missing (real gaps), Dynamic (can't be resolved).
- **D-06:** REVIEW rows are resolved in the Claude session, not by hand-editing CSV in Excel.
- **D-07:** Claude opens each REVIEW file first and fills disposition wherever the answer is clear.
- **D-08:** Only rows still unclear go to Gerard as a short table in chat.
- **D-09:** Done = zero REVIEW rows and zero blocking dry-run errors (exit 0).
- **D-10:** Default for files still uncertain after Gerard's pass: ARCHIVE to `archive/misc/`. Suspected patient-row files → DATA → `archive/data_local/`, added to `SOURCES.md`.
- **D-11:** Destination layout: `legacy/{sas,R,python,sql}`, `docs/reference`, `archive/duplicates`, `archive/old_versions/{sas,R,python,sql,docs}`, `archive/logs`, `archive/data_local`, `archive/misc`.
- **D-12:** Do not reorganize inside `legacy/` in Phase 1. Phase 2 does that.
- **D-13:** Code from clearly unrelated projects goes to `archive/other_projects/<project>/`. Precedence: DUPLICATE and DATA first, then unrelated project, then normal rules.
- **D-14:** Update `.gitignore` so `legacy/` and `docs/reference/` accept only allowed types (`.sas .R .r .Rmd .py .sql .md .gitkeep`). Test with `git check-ignore -v`.
- **D-15:** `archive/` and `_inbox/` stay fully ignored.
- **D-16:** Stage explicit paths only (no `git add -A`). Review `git diff --cached --name-status` before committing.
- **D-17:** Before committing, scan every staged file for MRN-like runs of 7+ digits, `datalines`/`cards` blocks, dates next to IDs, and non-staff names. Show hits to Gerard.
- **D-18:** One commit: "Phase 1: inventory and triage". Confirm branch and remote before pushing; push only with Gerard's OK.
- **D-19:** Harden `apply_file_map.py`: skip rows already in `moves_log.csv` (resumable), SHA-256 check before move, never overwrite (existing `__<id>` rename), flush log row immediately after each move, post-run verification of destinations and counts, write blocked/failed rows to `docs/inventory/apply_exceptions.csv`.

### Claude's Discretion

- Tuning the family-key regex in `inventory.py` once real file names are seen.
- How the D-05 reference patterns and D-17 patient-data patterns are implemented, as long as the required outputs are produced.

### Deferred Ideas (OUT OF SCOPE)

- Deleting the originals at the source locations (separate decision after Phase 1).
- Removing patient-level data files from the home PC (tracked in SOURCES.md; Gerard's action, outside the repo).

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ORG-01 | Every file in `_inbox/` is inventoried (path, type, size, modified date, SHA-256, keywords, paths it references) in `docs/inventory/inventory.csv` | `inventory.py` already does this; D-05 extends reference capture |
| ORG-02 | Exact duplicates are grouped and one canonical copy is chosen per group | `inventory.py` already does SHA-256-based duplicate grouping |
| ORG-03 | Version families are grouped and the current version identified | `inventory.py` already does `family_key()` grouping; regex may need tuning on real names |
| ORG-04 | Data files and possible PHI are flagged DATA and kept out of every tracked folder | `inventory.py` already sets `data_flag`; D-14 gitignore closes remaining gaps |
| ORG-05 | Gerard approves `file_map.csv` before anything moves | `apply_file_map.py` already blocks on REVIEW rows; D-06–D-10 define the resolution workflow |
| ORG-06 | Approved files are moved to `legacy/`, `docs/reference/`, or `archive/`; nothing deleted; every move logged | `apply_file_map.py` already does this; D-19 adds resumability, hash verification, and `apply_exceptions.csv` |

</phase_requirements>

---

## Summary

Phase 1 is a home-PC-only file-organization phase. The two key tools (`inventory.py` and `apply_file_map.py`) already exist and are substantially complete. Phase 1 planning is therefore about **operating the tools in the right order**, **extending them with two specific improvements** (D-05 reference capture, D-19 hardening), and **enforcing data-safety and git-safety rules** at every step.

No external Python packages are required. Both tools use the standard library only. The entire workflow is Python + CSV + git, running locally on Windows.

The primary risk is not technical complexity but **sequencing**: the scan cannot run until Gerard has confirmed `SOURCES.md` is complete, REVIEW resolution cannot happen until the scan completes, and `--apply` cannot run until zero REVIEW rows and a clean dry run. The plan must encode these gates explicitly.

**Primary recommendation:** Plan as a strict linear sequence of gated waves: (1) SOURCES.md confirmation, (2) tool hardening (D-05, D-19), (3) scan + summary review, (4) REVIEW resolution with Gerard, (5) dry run gate, (6) apply + post-run verification, (7) git safety checks + commit.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Python standard library | 3.x (any) | hashlib, csv, os, re, shutil, argparse | No install needed; tools already use it |
| git | installed | Staging, ignoring data files, final commit | Project requirement |

### No additional packages needed.

All tool functionality is implemented with the Python standard library. The planner should not add dependencies.

---

## Architecture Patterns

### Tool Execution Order (mandatory sequence)

```
1. SOURCES.md confirmed by Gerard
      ↓
2. D-05 changes to inventory.py merged and tested
      ↓
3. python tools/inventory.py --root _inbox --out docs/inventory
      ↓
4. Review inventory_summary.md + missing_references.md
      ↓
5. Claude reads REVIEW files → proposes dispositions
   Gerard confirms ambiguous rows in chat
   Claude writes answers into file_map.csv
      ↓
6. python tools/apply_file_map.py   (dry run, must exit 0)
      ↓
7. D-19 changes to apply_file_map.py in place
   python tools/apply_file_map.py --apply
      ↓
8. Post-run verification (counts, hashes, _inbox empty)
      ↓
9. git safety scan (D-17) + staged-file review (D-16)
      ↓
10. One commit → push with Gerard's OK
```

### Recommended Project Structure (outputs of this phase)

```
docs/inventory/
├── inventory.csv            # one row per file (ORG-01)
├── file_map.csv             # approved dispositions (ORG-05)
├── moves_log.csv            # one row per move (ORG-06)
├── inventory_summary.md     # duplicate groups, version families (ORG-02/03)
├── missing_references.md    # D-05 output (three groups)
└── apply_exceptions.csv     # D-19 output (blocked/failed rows, may be empty)

legacy/
├── sas/                     # KEEP SAS programs
├── R/                       # KEEP R programs
├── python/                  # KEEP Python programs
└── sql/                     # KEEP SQL programs

docs/reference/              # KEEP docs (.md only after D-14)

archive/
├── duplicates/
├── old_versions/{sas,R,python,sql,docs}/
├── logs/
├── data_local/              # DATA files (git-ignored)
├── other_projects/<proj>/   # D-13 unrelated projects
└── misc/                    # D-10 fallback

.planning/phases/01-inventory-triage/
└── SOURCES.md               # source checklist (D-04)
```

### Pattern: REVIEW Row Resolution Workflow

**What:** Claude reads each REVIEW file's first lines, extension, size, source folder, and keywords. If the answer is clear (FYP-related code → KEEP legacy/sas; unrelated project → archive/other_projects/; data file → DATA), Claude fills `final_disposition`, `final_dest`, and `notes` directly in `file_map.csv`. If unclear, Claude shows Gerard a short table with its assessment and suggested choice. Gerard answers in chat; Claude writes the answer.

**When to use:** Every REVIEW row before dry run.

**CSV editing rule:** Use Python to read/write `file_map.csv`, not Excel (D-06). Preserve quoting and encoding.

### Anti-Patterns to Avoid

- **`git add -A` or `git add .`**: Banned (D-16). Use explicit paths.
- **Running `--apply` before dry run exits 0**: The dry run is the gate.
- **Editing `file_map.csv` in Excel**: Changes quoting, dates, encoding (D-06).
- **Flattening `_inbox/` subfolders before the scan**: Folder names carry context (D-01).
- **Deleting originals during Phase 1**: Out of scope (deferred).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SHA-256 hashing | Custom hash loop | `hashlib` (already in `inventory.py`) | Already implemented |
| File moves with logging | Custom shell script | `apply_file_map.py --apply` | Already implemented; D-19 adds what's missing |
| Duplicate detection | Filename comparison | SHA-256 grouping (already in `inventory.py`) | Content-identical files with different names are caught |
| Git ignore testing | Manual inspection | `git check-ignore -v <file>` | Shows exactly which rule matched |

**Key insight:** The tools are already 80% complete. The plan should extend them minimally (D-05, D-19) rather than rewrite them.

---

## Current Tool State and Gaps

### `inventory.py` — what it does today (HIGH confidence, from code inspection)

- Walks `--root`, hashing every file with SHA-256
- Records: `rel_path`, `name`, `ext`, `category`, `size_kb`, `modified`, `sha256`, `family`, `keywords`, `paths_referenced`, `log_errors`
- Detects exact duplicates by hash; picks canonical = shortest path, then newest
- Groups version families by `family_key()` regex (collapses dates, versions, initials)
- Proposes dispositions: DUPLICATE, DATA, KEEP, ARCHIVE, REVIEW
- Writes: `inventory.csv`, `file_map.csv`, `inventory_summary.md`

### `inventory.py` — current gaps (HIGH confidence, from code + CONTEXT)

| Gap | Where | Fix (D-05) |
|-----|-------|-----------|
| `PATH_RE` only captures absolute paths (drive letters, UNC, /blue, /mnt) | Line 54–55 | Add patterns for relative paths and bare filenames |
| Reference patterns cover only `PATH_RE.findall()` | `scan_text()` lines 108–114 | Add targeted regex for `%include`, `datafile=`, `infile`, `filename`, `libname`, `out=`, `outfile=`, `read.csv`, `read_excel`, `readRDS`, `source(`, `open(` |
| 8-reference cap per file | Line 113 | Remove cap |
| No `missing_references.md` output | `main()` | Add post-scan pass: match references to inventoried file names (case-insensitive, ignore drive/folder), classify into three groups |

### `apply_file_map.py` — what it does today (HIGH confidence, from code inspection)

- Reads `file_map.csv`, resolves `final_*` vs `proposed_*` columns
- Validates: no REVIEW rows, valid dispositions, DATA/DUPLICATE only to `archive/`
- Resolves name clashes with `__<id>` suffix
- Dry run by default; `--apply` moves files with `shutil.move`
- Appends to `moves_log.csv` after all moves complete
- Removes empty folders in `_inbox/` after apply

### `apply_file_map.py` — current gaps (HIGH confidence, from code + CONTEXT)

| Gap | Where | Fix (D-19) |
|-----|-------|-----------|
| Not resumable: already-moved rows reported as "source missing" and abort | Lines 50–56 | Skip rows already in `moves_log.csv` by id |
| No hash verification before move | Lines 87–93 | Compare file's current SHA-256 to `inventory.csv` value; block on mismatch |
| Log written in batch at end, not per-move | Lines 84–93 | Open log in append mode, write+flush each row immediately after its move |
| No post-run verification | (absent) | After run, verify each moved file exists at destination with expected hash; count moved + skipped + blocked = total rows |
| No `apply_exceptions.csv` | (absent) | Write blocked/failed rows with reason |

---

## Common Pitfalls

### Pitfall 1: Data file slips into a tracked folder
**What goes wrong:** A `.csv` or `.xlsx` gets staged accidentally; patient data enters git history.
**Why it happens:** `docs/inventory/file_map.csv` is tracked; so is `docs/inventory/inventory.csv`. If a DATA file is accidentally proposed to `docs/reference/` and the gitignore doesn't cover it, `git add` commits it.
**How to avoid:** D-14 gitignore closes `docs/reference/` to everything except `.md`. D-16 requires staged-file review before every commit. D-17 adds a PHI pattern scan.
**Warning signs:** `git diff --cached` shows a `.csv`, `.xlsx`, `.sas7bdat`, `.rds`, or `.pdf` that isn't in `docs/inventory/`.

### Pitfall 2: Partial apply run leaves `_inbox/` half-empty
**What goes wrong:** `apply_file_map.py --apply` fails mid-run (disk full, permission error). Re-running without D-19 reports "source missing" for already-moved files and aborts.
**Why it happens:** Current tool writes the log in a batch at the end; if it crashes first, the log has no record of completed moves.
**How to avoid:** D-19 hardening: skip rows already in `moves_log.csv`; flush log per move.
**Warning signs:** `moves_log.csv` row count does not match expected; `_inbox/` still has files after a claimed-complete run.

### Pitfall 3: `family_key()` regex over-strips or under-strips on real file names
**What goes wrong:** Two versions of a file are not grouped (miss), or two different files are grouped (false positive), leading to wrong KEEP/ARCHIVE decisions.
**Why it happens:** `family_key()` was written before real file names were seen. SAS naming conventions like `create_data_MT_Sept_30_2026_GJG.sas` include initials, dates, and month abbreviations that must be stripped.
**How to avoid:** After the first scan, review version families in `inventory_summary.md`. Tune the regex before finalizing `file_map.csv`. This is Claude's discretion (CONTEXT.md).
**Warning signs:** A family with more than 5 members, or two files from different programs in the same family.

### Pitfall 4: `docs/reference/` `.txt` files slip through
**What goes wrong:** Under the pre-D-14 gitignore, `.txt` files in `docs/reference/` are tracked. If a reference doc is a `.txt` with aggregate output or partial data, it enters git.
**Why it happens:** The current `.gitignore` whitelists `.txt` and `.md` in `docs/reference/`.
**How to avoid:** D-14 removes `.txt` from the whitelist. Test with `git check-ignore -v docs/reference/sample.txt` before committing.

### Pitfall 5: CSV encoding corrupted by Excel
**What goes wrong:** Gerard opens `file_map.csv` in Excel to review, saves it, and quoting or date formats change. `apply_file_map.py` misreads the file.
**Why it happens:** Excel auto-converts some strings (dates, numeric-looking IDs) on save.
**How to avoid:** D-06 mandates VS Code or Notepad for any manual edits. Claude writes all programmatic edits through Python's `csv` module.

### Pitfall 6: Missing references classified incorrectly
**What goes wrong:** A reference to `P:\PeCAN Research\...` is classified as a "local and missing" gap instead of "On P: (expected)".
**Why it happens:** The path starts with a drive letter, which the simple classifier treats the same as a `C:\` path.
**How to avoid:** D-05 implementation must check for `P:\` or UNC patterns specifically to classify as "On P: (expected)". All other absolute-path references go to "Local and missing" for Gerard to verify.

---

## Code Examples

### D-05: Reference pattern extension for `scan_text()`

```python
# Patterns to add alongside PATH_RE
REF_RE = re.compile(
    r"""(?xi)
    (?:%include\s+["']?([^"';\r\n]+))      # SAS %include
    |(?:(?:datafile|infile|filename)\s*=\s*["']([^"';\r\n]+))  # SAS file refs
    |(?:libname\s+\w+\s+["']([^"';\r\n]+)) # SAS libname
    |(?:(?:out|outfile)\s*=\s*["']?(\S+))  # SAS output
    |(?:read\.csv\s*\(\s*["']([^"']+))     # R read.csv
    |(?:read_excel\s*\(\s*["']([^"']+))    # R read_excel
    |(?:readRDS\s*\(\s*["']([^"']+))       # R readRDS
    |(?:source\s*\(\s*["']([^"']+))        # R source
    |(?:open\s*\(\s*["']([^"']+))          # Python open
    """,
    re.IGNORECASE
)
```

### D-19: Resumable apply — skip already-logged rows

```python
# Load already-completed ids from moves_log.csv
completed_ids = set()
if os.path.exists(a.log):
    with open(a.log, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            completed_ids.add(row["id"])

# In the plan loop:
for rid, src, t, disp in final:
    if rid in completed_ids:
        print(f"SKIP (already moved) id={rid}")
        continue
    # ... move, then immediately write+flush log row
```

### D-19: SHA-256 pre-move verification

```python
# Load expected hashes from inventory.csv
expected = {r["id"]: r["sha256"] for r in inventory_rows}

# Before each move:
actual = sha256(src)
if actual != expected[rid]:
    blocked.append((rid, src, "hash mismatch"))
    continue
```

### D-16/D-17: Staged file review commands

```bash
# Stage explicit paths only
git add .gitignore tools/inventory.py tools/apply_file_map.py
git add docs/inventory/inventory.csv docs/inventory/file_map.csv
git add docs/inventory/moves_log.csv docs/inventory/inventory_summary.md
git add docs/inventory/missing_references.md
git add legacy/sas/ legacy/R/ legacy/python/ legacy/sql/
git add .planning/phases/01-inventory-triage/SOURCES.md

# Verify staged set
git diff --cached --name-status

# Test gitignore rules
git check-ignore -v legacy/sample.sas
git check-ignore -v legacy/sample.csv
git check-ignore -v docs/reference/sample.txt
git check-ignore -v docs/reference/sample.md
```

### D-14: `.gitignore` additions

```gitignore
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

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Python 3 | inventory.py, apply_file_map.py | Assumed yes (tools exist) | unknown | — |
| git | D-14 to D-18 | Assumed yes (CLAUDE.md requires it) | unknown | — |
| P: drive | Reading patient-level data | No (home PC) | — | List in SOURCES.md, do not copy |
| SAS | Running programs | No (home PC) | — | Not needed for Phase 1 |

No blocking dependencies beyond Python 3 and git, which are assumed present.

---

## Validation Architecture

Phase 1 has no automated test suite. Validation is structural (file counts, exit codes, manual review gates) rather than unit-test based.

### Phase Gate Checklist (maps to completion gate in CONTEXT.md)

| Check | How Verified | Automated? |
|-------|-------------|------------|
| SOURCES.md all items ticked | Gerard confirms in chat | Manual |
| `inventory.csv` row count = file count in `_inbox/` | `wc -l docs/inventory/inventory.csv` vs `find _inbox -type f` count | Semi-automated |
| Scan exits 0, no errors printed | Exit code of `inventory.py` | Automated |
| `missing_references.md` exists; "local and missing" items resolved | Gerard reviews file | Manual |
| Zero REVIEW rows in `file_map.csv` | `python tools/apply_file_map.py` exits 0 | Automated (dry run) |
| `--apply` completes; post-run check passes | Counts in apply output; `apply_exceptions.csv` empty | Automated |
| `_inbox/` contains only `.gitkeep` | `ls _inbox/` | Manual |
| Originals unchanged | Out-of-scope verification | Manual (Gerard) |
| `git check-ignore -v` tests pass for D-14 | Run against sample files | Manual |
| `git diff --cached --name-status` shows only allowed files | Run before commit | Manual |
| D-17 PHI scan clear or resolved | Claude scans and shows hits | Semi-automated |
| Commit on correct branch, pushed with Gerard's OK | Confirm branch + remote | Manual |

### Wave 0 Gaps

- No existing test files for `inventory.py` or `apply_file_map.py`. Phase 1 plan should include a smoke-test task: run `inventory.py` against a tiny synthetic `_inbox/` with 2–3 files and verify output columns exist with expected values. This validates D-05 changes without waiting for real data.

---

## Open Questions

1. **When will Gerard copy files into `_inbox/`?**
   - What we know: STATE.md says "waiting on Gerard to copy the old folders into `_inbox/`"
   - What's unclear: Has this happened? The plan needs a conditional first wave that only proceeds once confirmed.
   - Recommendation: Wave 0 of the plan should be "confirm `_inbox/` is populated" before any tool runs.

2. **Is Python 3 confirmed on the home PC?**
   - What we know: Tools exist and were apparently written here; no explicit version noted.
   - What's unclear: Which minor version; whether `hashlib.sha256` with the standard interface is available (it is in all Python 3.x).
   - Recommendation: Plan includes a `python --version` check as the first task.

3. **How many files are expected in `_inbox/`?**
   - What we know: Sources include Desktop, Documents, Downloads, email attachments, OneDrive/Google Drive, R project folders, possibly USB drives.
   - What's unclear: Total file count; could range from dozens to thousands.
   - Recommendation: Treat the REVIEW resolution workflow as potentially multi-session. D-07/D-08 limit Gerard's burden; the plan should not assume single-session completion.

---

## Sources

### Primary (HIGH confidence)

- `tools/inventory.py` — direct code inspection; all behavioral claims verified against source
- `tools/apply_file_map.py` — direct code inspection; all gap claims verified against source
- `.planning/phases/01-inventory-triage/01-CONTEXT.md` — all D-* decisions read verbatim
- `.planning/REQUIREMENTS.md` — ORG-01 through ORG-06 read verbatim
- `CLAUDE.md` — project constraints read directly

### Secondary (MEDIUM confidence)

- `.planning/STATE.md` — current project status and pending Gerard actions

### Tertiary (LOW confidence)

- None. All findings are from direct file inspection.

---

## Project Constraints (from CLAUDE.md)

| Directive | Implication for This Phase |
|-----------|---------------------------|
| Home PC has no SAS, no P: drive | Phase 1 runs entirely on the home PC with Python only |
| Data files never enter the repo | DATA disposition → `archive/data_local/` (git-ignored); D-14 closes remaining gaps |
| Every path lives in `sas/00_config.sas` or `R/00_config.R` | Not relevant to Phase 1 (no SAS/R execution) |
| `python tools/check_paths.py` must pass before phase complete | Not a Phase 1 gate per CLAUDE.md (stated explicitly there) |
| Programs: `NN_verb_noun.sas`, decade numbering | Not applicable to Phase 1 tool changes (tools already named) |
| Deliver complete programs, not fragments | D-05 and D-19 changes must be complete working code, not pseudocode |
| Decisions → `docs/DECISIONS.md` | Phase-level D-* decisions are in CONTEXT.md; any new project-level decisions go to `docs/DECISIONS.md` |
| Unknowns → `docs/OPEN_QUESTIONS.md` | Open questions from REVIEW resolution should be logged there |

---

## Metadata

**Confidence breakdown:**
- Tool behavior (inventory.py, apply_file_map.py): HIGH — read directly from source
- Tool gaps (D-05, D-19 targets): HIGH — cross-verified between code inspection and CONTEXT.md tested behavior notes
- Git safety patterns: HIGH — standard git behavior, verified against D-14/D-16/D-17 decisions
- File count and REVIEW volume: LOW — depends on what Gerard copies; plan must be flexible

**Research date:** 2026-10-28
**Valid until:** Stable (no external dependencies; only changes if tools are modified)
