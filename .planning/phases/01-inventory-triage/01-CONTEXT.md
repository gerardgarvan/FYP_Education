# Phase 1: Inventory & Triage - Context

**Gathered:** 2026-10-28
**Revised:** 2026-10-28 (after review: tool tests, data-handling, git checks, recovery)
**Status:** Ready for planning

<domain>
## Phase Boundary

Code, documents, slides, logs and notes from the home-PC mess are **copied** into `_inbox/`
(folder structure preserved), inventoried by `tools/inventory.py`, classified in
`docs/inventory/file_map.csv`, and moved to staging destinations by
`tools/apply_file_map.py --apply`. Patient-level data files are listed, not copied.
The originals are never modified or deleted during Phase 1. Deleting them later needs
Gerard's separate go-ahead.

Phase 1 runs entirely on the home PC. No SAS, work PC or P: drive is needed.
"Complete" means the **home-PC** inventory is complete. Files that exist only on the
work PC or on P: are listed in `SOURCES.md` but are out of scope for the scan.

Phase 1 includes small, specific changes to `inventory.py` and `apply_file_map.py`
(D-05, D-19). The tools are not final.

</domain>

<decisions>
## Implementation Decisions

### What to copy into `_inbox/`

- **D-01:** Copy **entire folder trees as-is**. Folder names carry context (project, month,
  source). Do not flatten.
- **D-02:** Each source location gets its **own top-level subfolder** named after where it
  came from, e.g. `_inbox/Desktop_FYP/`, `_inbox/Downloads/`, `_inbox/Documents_PeCAN_old/`,
  `_inbox/email_attachments/`.
- **D-03:** Copy code, documents, slides, logs, notes and **aggregate** outputs (summary
  CSVs, result tables, figures). Do **not** copy patient-level data files (FIBRO
  extracts, Clarity exports, any xlsx/csv/sas7bdat/rds with patient rows) to the home PC.
  List them by name and location in `SOURCES.md` instead. If patient-level files already
  exist on the home PC, record them in `SOURCES.md` under "to remove from home PC" for
  Gerard to handle. If in doubt, list the file instead of copying it.
- **D-04:** The source checklist lives in `.planning/phases/01-inventory-triage/SOURCES.md`
  (**not** in `_inbox/`, where it would itself get inventoried). Gerard ticks off each
  item, marks it "n/a", or adds new ones, and confirms the list is complete before the
  scan runs. Starter list:
  - [ ] Desktop and any FYP / PRECEDE / FIBRO / Mackenzie folders
  - [ ] Documents: old SAS project folders, including PeCAN-era MT programs
        (`create_data_MT_*`, `results_MT_*`)
  - [ ] Downloads: files received by email or Teams (decks, docx tables, summary CSVs)
  - [ ] Email and Teams attachments that exist only in the mail client → `_inbox/email_attachments/`
  - [ ] OneDrive / Google Drive copies (FYP slide deck versions)
  - [ ] R project folders (ggplot stacked-bar scripts, `MT_educ_stacked_bars.csv`)
  - [ ] USB or external drives used to move files between PCs
  - [ ] Work-PC-only files: list here, don't copy
  - [ ] Patient-level data files found on the home PC: list here, don't copy (D-03)

### Missing-reference check

- **D-05:** "Referenced but not found" is a Phase 1 **task**, not just a read-through:
  1. Extend `inventory.py` to capture relative and bare-filename references as well as
     full paths. Cover `%include`, `datafile=`, `infile`, `filename`, `libname`, `out=`/`outfile=`,
     `read.csv`, `read_excel`, `readRDS`, `source`, and `open(`. Remove the 8-per-file cap.
  2. Match references to inventoried files **by file name, case-insensitive**, ignoring
     drive and folder.
  3. Write `docs/inventory/missing_references.md` with three groups:
     - **On P: (expected)**: a path on P: or a UNC share. Not a gap.
     - **Local and missing (real gaps)**: a C:\, Desktop, Documents or relative reference
       with no matching file in the inventory. Gerard checks these against `SOURCES.md`.
     - **Dynamic (can't be resolved)**: built from macro variables or string pasting,
       e.g. `&root.\x.sas`. Listed for a human to look at.

### REVIEW row resolution

- **D-06:** REVIEW rows are resolved **in the Claude session**, not by hand-editing the CSV in
  Excel, which can change quoting, dates and encoding. If a manual edit is ever needed,
  use VS Code or Notepad.
- **D-07:** Claude opens each REVIEW file first (first lines, extension, size, source
  folder, keywords). It fills `final_disposition`, `final_dest` and `notes` wherever the
  answer is clear.
- **D-08:** Only rows that are still unclear go to Gerard, as a short table in chat (id, path,
  size, Claude's assessment, suggested choice). Gerard answers in chat and Claude writes
  the answers into `file_map.csv`.
- **D-09:** Done means **zero REVIEW rows and zero blocking dry-run errors**
  (`python tools/apply_file_map.py` exits 0).
- **D-10:** Default for files still uncertain after Gerard's pass: ARCHIVE to `archive/misc/`.
  The row's `notes` must say why. Anything that looks like it contains patient rows
  goes to DATA instead (git-ignored `archive/data_local/`) and is added to `SOURCES.md`
  under "to remove from home PC".

### Destination layout

- **D-11:** Keep the layout `inventory.py` proposes:
  `legacy/{sas,R,python,sql}`, `docs/reference`, `archive/duplicates`,
  `archive/old_versions/{sas,R,python,sql,docs}`, `archive/logs`, `archive/data_local`,
  `archive/misc`.
- **D-12:** Do not reorganize inside `legacy/` in Phase 1. Phase 2 does that.
- **D-13:** Exception for **unrelated projects**: code from a clearly separate project (e.g.
  PeCAN master merge, INS abstract), identified by folder names and keywords that don't
  match FYP/MT/FIBRO, goes to `archive/other_projects/<project>/`. Use
  `legacy/sas/<project>/` only if Gerard wants it kept for reference. Claude proposes the
  split and Gerard confirms it alongside the REVIEW rows. Precedence: DUPLICATE and DATA
  first, then unrelated project, then the normal rules.

### `apply_file_map.py` hardening

- **D-19:** Phase 1 task. Change the script to:
  - skip rows already recorded in `moves_log.csv`, so a rerun picks up where it stopped
    and running it twice does nothing the second time
  - check each source's SHA-256 against `inventory.csv` before moving it, and block that
    row on a mismatch (the file changed after the scan)
  - never overwrite: keep the existing `__<id>` rename for name clashes
  - write each log row (and flush it) as soon as its move finishes
  - after the run, verify that every moved file is at its destination with the expected
    hash, and that moved + skipped + blocked equals the number of rows
  - write any blocked or failed rows to `docs/inventory/apply_exceptions.csv`

### Git

- **D-14:** Update `.gitignore` so `legacy/` and `docs/reference/` accept only allowed types:
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
  Before committing, test with `git check-ignore -v` on one sample of each type
  (`.sas .R .r .txt .dat .csv .log .sas7bdat .pptx .md`) in both folders.
- **D-15:** `archive/` and `_inbox/` stay fully ignored. Under the current rules,
  `docs/reference/` lets `.txt` through; D-14 closes that.
- **D-16:** Stage **explicit paths** (no `git add -A`). Then review
  `git diff --cached --name-status`, which shows what is actually staged.
  Allowed in the commit:
  - `.gitignore`
  - code in `legacy/` (per D-14)
  - `.md` in `docs/reference/`
  - `docs/inventory/`: `inventory.csv`, `file_map.csv`, `moves_log.csv`,
    `inventory_summary.md`, `missing_references.md`, `apply_exceptions.csv` (if any)
  - the changed `tools/inventory.py` and `tools/apply_file_map.py`
  - `.planning/` files, including `SOURCES.md`

  Anything else needs Gerard's explicit OK.
- **D-17:** Before committing, scan **every staged file**, including the file names and
  paths in `inventory.csv`, for:
  - runs of 7 or more digits that look like MRNs or encounter numbers
  - `datalines`/`cards` blocks or R `data.frame`/`tribble` literals with more than 10 rows
  - dates next to IDs
  - names of people other than project staff

  Show the hits to Gerard. Redact file names or paths if needed; the unredacted inventory
  can be kept in `archive/`.
- **D-18:** Make one commit: **"Phase 1: inventory and triage"**. Before pushing, confirm the
  branch, that the remote is the private repo, and that Gerard says to push.

### Claude's Discretion

- Tuning the family-key regex in `inventory.py` once real file names are seen.
- How the D-05 reference patterns and the D-17 patient-data patterns are implemented, as
  long as the outputs listed above are produced.

</decisions>

<completion_gate>
## Phase 1 Completion Gate

Phase 1 is complete only when **all** of these are true:

1. `SOURCES.md`: every checklist item is ticked, marked n/a or added. Work-PC-only files
   and patient-level files are listed and not copied. Gerard has confirmed the list.
2. `inventory.csv` has one row per file in `_inbox/` (row count = file count) and the scan
   reported no errors.
3. `missing_references.md` exists. Every "local and missing" item has been found and
   copied, or accepted by Gerard as gone.
4. `file_map.csv` has zero REVIEW rows. Project splits and DATA classifications are
   confirmed.
5. The dry run exits 0 with no blocking errors.
6. `--apply` has finished. The post-run check passes (files and hashes at their
   destinations, counts add up), and `apply_exceptions.csv` is empty or every exception
   is accepted by Gerard.
7. `_inbox/` contains only `.gitkeep`.
8. The originals at the source locations are unchanged. Deleting them is a separate,
   later decision.
9. The `.gitignore` rules pass the `git check-ignore -v` tests (D-14).
10. `git diff --cached --name-status` shows only allowed files (D-16), and the scan of
    staged files (D-17) is clear or its hits are resolved.
11. The commit is made on the intended branch, and it has been pushed to the private
    remote with Gerard's OK.

If any check fails, Phase 1 is not signed off.

</completion_gate>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project configuration and constraints
- `CLAUDE.md`: project rules (machines, paths, data policy, conventions)
- `.planning/REQUIREMENTS.md` §ORG-01–ORG-06: acceptance criteria
- `.planning/ROADMAP.md` §Phase 1: goal, success criteria, approval gate

### Tools (read before planning tasks that touch them)
- `tools/inventory.py`: walks `_inbox/`; records SHA-256, duplicates, version families and
  proposed dispositions. **Currently captures full paths only (max 8 per file).** D-05
  extends it.
- `tools/apply_file_map.py`: dry run by default; blocks on REVIEW rows; renames on name
  clashes. **Currently not resumable after a partial run and doesn't check hashes.** D-19
  hardens it.
- `tools/check_paths.py`: no hard-coded paths outside the config files (not a Phase 1 gate)

### Reference documents
- `docs/DECISIONS.md`: D-01–D-05 recorded at initialization (project-level numbering,
  separate from the phase decisions here)
- `docs/OPEN_QUESTIONS.md`: Q-07 (the MT_ group definitions) is helped by finding
  `create_data_MT_*` in Phase 1. Q-09 doesn't block Phase 1.

</canonical_refs>

<code_context>
## Existing Code Insights

### Tested behavior (2026-10-28)
- The `legacy/` whitelist in D-14 works for nested `<project>/` folders. Without
  `!legacy/**/*.r`, lowercase `.r` files are ignored.
- Under the current rules, `docs/reference/` tracks `.txt` and `.md`, and ignores
  `.pptx`, `.docx`, `.pdf` and `.png`.
- `paths_referenced` picks up `P:\...` paths in `%include` but misses
  `read.csv("x.csv")`, `source("x.R")` and `%include "&root.\x.sas"`.
- After a partial run, `apply_file_map.py` reports the already-moved rows as "source
  missing" and refuses to run.

### Patterns
- Outputs go to P: or to git-ignored areas. `archive/` and `_inbox/` are ignored.
- Code is tracked. Data never is. `docs/inventory/` is tracked metadata and gets checked
  under D-17 before every commit.

### Integration points
- Phase 2 reads `legacy/`, `file_map.csv` and `missing_references.md` to decide which legacy
  programs become which pipeline programs. It especially needs `create_data_MT_*` for Q-07.

</code_context>

<specifics>
## Specific Ideas

- The named subfolders under `_inbox/` mean each file's `rel_path` records where it came from.
- Claude reads ambiguous files itself before asking Gerard, so Gerard sees as few rows as
  possible.
- The FYP / other-project split is proposed from folder names and keywords, then confirmed by Gerard.
- `_inbox` holds copies, so the worst outcome of a bad move is copying again, not losing data.
  D-19 is about making runs repeatable and checkable, not about rescue.

</specifics>

<deferred>
## Deferred Ideas

- Deleting the originals at the source locations (separate decision after Phase 1).
- Removing patient-level data files from the home PC (tracked in `SOURCES.md`; Gerard's
  action, outside the repo).

</deferred>

---

*Phase: 01-inventory-triage*
*Context gathered: 2026-10-28 · revised 2026-10-28*
