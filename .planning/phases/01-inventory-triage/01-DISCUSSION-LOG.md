# Phase 1: Inventory & Triage - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-10-28
**Phase:** 01-inventory-triage
**Areas discussed:** Copy instructions for _inbox/, REVIEW row resolution process, Destination folder layout, Git commit scope after --apply

---

## Copy instructions for `_inbox/`

| Option | Description | Selected |
|--------|-------------|----------|
| One root folder (copy the whole thing) | Copy a single folder tree into _inbox/ | |
| Several scattered folders | Gather from multiple locations separately | |
| Mix — one main folder plus loose files | Main folder plus strays | |

**User's choice:** Preserve folder trees, named subfolders per source location (free-text response)

**Notes:** Gerard copies entire folder trees as-is, each into its own named subfolder under `_inbox/`
(e.g., `_inbox/Desktop_FYP/`, `_inbox/Downloads/`). Over-including is fine — Phase 1 sorts
it out. Data files may be included; they go to `archive/data_local/` (gitignored). Originals
stay put until Phase 1 is verified.

---

## Source checklist

| Option | Description | Selected |
|--------|-------------|----------|
| Include a starter checklist in the plan | List known likely sources | ✓ |
| Leave it to Gerard | Don't prescribe source locations | |

**User's choice:** Include a starter checklist with specific named sources.

**Notes:** Detailed checklist provided covering Desktop/FYP, Documents/PeCAN-era MT programs,
Downloads, email/Teams attachments, OneDrive/Google Drive, R project folders, USB drives, and
work-PC-only files (list but don't copy). After scan, Claude checks for "referenced but not
found" paths to catch gaps.

---

## REVIEW row resolution process

| Option | Description | Selected |
|--------|-------------|----------|
| Edit file_map.csv directly in Excel / VS Code | Gerard opens CSV, filters, types in values | |
| Add a helper script (show_review.py) | Print only REVIEW rows as readable table | |
| Enhance inventory_summary.md | Detailed section asking for decisions | |

**User's choice:** Resolve REVIEW rows in the Claude chat session (free-text response)

**Notes:** Claude reads each REVIEW file directly and fills dispositions where clear. Only
truly ambiguous rows go to Gerard as a short chat table. Claude writes answers into
file_map.csv. Default for anything still unclear: ARCHIVE to archive/misc/. Do not use
Excel to edit CSV (corrupts quoting/encoding). Use VS Code or Notepad if manual edit needed.

---

## Destination folder layout

| Option | Description | Selected |
|--------|-------------|----------|
| Keep the fine-grained layout (Recommended) | legacy/sas, legacy/R, docs/reference, archive/... | ✓ |
| Coarser — just legacy/ and archive/ | Less structure, Phase 2 sorts | |
| You decide | Claude picks | |

**User's choice:** Keep proposed fine-grained layout

**Notes:** Destinations: `legacy/sas`, `legacy/R`, `legacy/python`, `legacy/sql`,
`docs/reference`, `archive/{duplicates,old_versions,logs,data_local,misc}`. No
reorganization inside `legacy/` in Phase 1 (Phase 2 does that). Exception: code from
clearly separate projects (PeCAN master-merge, INS abstract) goes under
`legacy/sas/<project>/` or `archive/other_projects/<project>/` — Claude proposes the
split, Gerard confirms.

---

## Git commit scope after `--apply`

| Option | Description | Selected |
|--------|-------------|----------|
| Commit docs/inventory/ only, then run git status check (Recommended) | Safest, minimal scope | |
| Also commit code/docs in legacy/ and docs/reference/ | More complete history | |
| You decide | Claude picks safest strategy | |

**User's choice:** Commit docs/inventory/ plus code in legacy/, guarded by gitignore whitelist (free-text response)

**Notes:** Add `.gitignore` rules that allow only code extensions inside `legacy/`. Before
committing, run `git add -n .` and show Gerard the full list. Scan staged code for patient
data (numeric ID sequences, MRN-like strings, datalines/cards blocks). One commit:
"Phase 1: inventory and triage". Then push.

---

## Claude's Discretion

- Family-key algorithm tuning in `inventory.py` if real file names reveal gaps
- Implementation of the "referenced but not found" gap check

## Deferred Ideas

None — discussion stayed within phase scope.
