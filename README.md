# FYP Education & Post-op Mortality

Pipeline for Mackenzie Topper's first-year project (PRECEDE II Ops): years of education
(later reading level and health literacy) and 1-year post-operative mortality.

- **Programs** live in this repo — on the work PC at `C:\FYP_Education`.
- **Inputs and outputs** live on the share:
  `P:\PeCAN Research\06 Individual Folders\Mackenzie Topper`
- **Planning** uses GSD (`.planning/`), driven from Claude CLI on the home PC.

```
FYP_Education/                       (repo)
├─ CLAUDE.md                         rules Claude follows in this project
├─ .planning/                        GSD: PROJECT, REQUIREMENTS, ROADMAP, STATE
├─ sas/
│  ├─ 00_config.sas                  ALL SAS paths and options
│  ├─ 01_import_clean.sas            FIBRO_MASTER → fyp.fibro_clean
│  ├─ 10_clarity_profile.sas         discovery: Patent Education Indicator folder
│  ├─ 20_mt_stacked_bars_data.sas    MT_educ_stacked_bars.csv
│  ├─ 30_models.sas                  Table 1, Table 2, LR tests, forest plots
│  └─ 99_run_all.sas                 runs everything, dated log
├─ R/
│  ├─ 00_config.R                    ALL R paths, UF colors
│  ├─ 21_plot_mt_stacked_bars.R
│  └─ 22_plot_died_by_edu.R
├─ run_pipeline.cmd                  one-click run on the work PC
├─ tools/                            inventory.py, apply_file_map.py, check_paths.py
├─ docs/                             DECISIONS, OPEN_QUESTIONS, DATA_SOURCES, ANALYSIS_PLAN, FILE_MAP
├─ legacy/                           kept original programs (reference)
├─ _inbox/   (git-ignored)           drop zone for the old mess (home PC)
└─ archive/  (git-ignored)           old versions, duplicates, local data copies

P:\...\Mackenzie Topper\
├─ FIBRO_MASTER_APRIL_20_2026_4_MT.xlsx
├─ Patent Education Indicator\       CLARITY_CONCEPT extract
└─ FYP_Education\                    created by the pipeline
   ├─ sasdata\  exports\  tables\  figures\  qc\  logs\
```

## Home PC — organize the mess with Claude CLI

1. Put this folder somewhere convenient and make it a git repo with a **private** remote:
   ```
   git init
   git add -A
   git commit -m "Initialize FYP project"
   git remote add origin <your private repo URL>
   git push -u origin main
   ```
2. **Copy** (don't move) every old folder related to this project into `_inbox\`.
3. Install GSD if it isn't already: `npx get-shit-done-cc@latest`
4. Open Claude CLI in the repo folder and start with:
   ```
   /gsd:progress
   /gsd:plan-phase 1
   /gsd:execute-phase 1
   ```
   Phase 1 runs `tools/inventory.py`, proposes a file map, and stops for your approval.
   Edit `docs/inventory/file_map.csv` (`final_disposition`, `final_dest`) where you disagree,
   then let it run `tools/apply_file_map.py --apply`. Nothing is deleted.
5. Continue with `/gsd:plan-phase 2` (fold legacy code into the pipeline, check paths).
6. Commit and push.

## Work PC — run the pipeline

1. First time: `git clone <repo URL> C:\FYP_Education`. After that: `git pull`.
   If you use a different folder, change `proj_root` on line 1 of each SAS program.
2. Either
   - double-click `run_pipeline.cmd` (edit `SAS_EXE` inside it if SAS lives elsewhere), or
   - open `sas\99_run_all.sas` in SAS and submit it, or
   - open and submit a single program — each one includes the config itself.
3. Outputs land in `P:\...\Mackenzie Topper\FYP_Education\`; the log is `logs\run_all_<date>_<time>.log`.
4. To verify a phase, copy that log into `_inbox\logs_from_work\` on the home PC (or paste it to
   Claude) so the phase can be checked and closed.

## Rules of the road

- Paths only in `sas/00_config.sas` and `R/00_config.R`; `python tools/check_paths.py` must pass.
- No data, PHI or Office files in git (see `.gitignore`). Data stays on P:.
- Workbooks open on a KEY sheet; figures use UF blue `#0021A5` and orange `#FA4616`.
- Unknowns go in `docs/OPEN_QUESTIONS.md`, decisions in `docs/DECISIONS.md`.
