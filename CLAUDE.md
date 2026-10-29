# FYP Education & Post-op Mortality — project rules for Claude

Mackenzie Topper's first-year project (PRECEDE II Ops): effect of years of education
and reading level on 1-year post-operative mortality. Gerard runs the data work.
Planning lives in `.planning/` (GSD). Read `.planning/STATE.md` first in every session.

## Two machines, one repo

| | Home PC (this CLI) | Work PC |
|---|---|---|
| Claude CLI | yes | no |
| SAS | **no** | yes |
| P: drive | **no** | yes |
| Repo path | anywhere | `C:\FYP_Education` |

- Claude never tries to run SAS or read P:. Code is written here and run on the work PC.
- Verification of SAS work = Gerard pastes the log or copies `logs\` from P: into
  `_inbox/logs_from_work/`. A phase that needs a SAS run is not complete until that log
  has been reviewed (0 ERRORs, WARNINGs explained).
- The repo syncs between machines through git (private remote) — never through P:.
  A git repo on P: corrupted its index on an earlier project.

## Paths

- Every path lives in **one** place: `sas/00_config.sas` (SAS) and `R/00_config.R` (R).
- Every SAS program starts with exactly:
  ```sas
  %let proj_root = C:\FYP_Education;
  %include "&proj_root.\sas\00_config.sas";
  ```
- R scripts assume the working directory is the repo root (`FYP_Education.Rproj`) and start
  with `source("R/00_config.R")`.
- Inputs are read from, and all outputs written to, the share:
  `P:\PeCAN Research\06 Individual Folders\Mackenzie Topper` (outputs under `FYP_Education\`).
- `python tools/check_paths.py` must pass before a phase is marked complete.

## Data never enters the repo

- No `.xlsx .xls .csv .sas7bdat .rds .RData .pptx .docx .pdf` in tracked folders (see `.gitignore`).
- `_inbox/` and `archive/` are git-ignored working areas on the home PC.
- If a data file turns up in the mess, it is flagged `DATA` in the file map and stays in
  `archive/data_local/`; the canonical copy belongs on P:.

## Organizing the mess (Phase 1)

- Gerard **copies** (not moves) the old folders into `_inbox/`.
- `python tools/inventory.py --root _inbox --out docs/inventory` — read-only scan.
- Nothing is moved until Gerard approves `docs/inventory/file_map.csv`
  (`final_disposition` / `final_dest` columns override the proposals).
- `python tools/apply_file_map.py` is a dry run; `--apply` moves. Nothing is ever deleted.

## Conventions

- SAS programs: `NN_verb_noun.sas`, decade numbering by stage (01 import, 10 Clarity,
  20 descriptives, 30 models, 99 run-all). R plots: `R/NN_plot_*.R`.
- Deliver complete programs, not fragments.
- Workbooks: a `KEY` sheet is always the leftmost tab.
- Figures: UF blue `#0021A5` and UF orange `#FA4616`.
- Slide/report text: measured, neutral language.
- Requirement IDs: `ORG- CFG- DAT- CLR- DSC- MOD- LIT- RUN-` (see `.planning/REQUIREMENTS.md`).
- Decisions → `docs/DECISIONS.md` (D-NN). Unknowns → `docs/OPEN_QUESTIONS.md` (Q-NN).
  Don't guess an answer to an open question in code without marking it as a setting.
