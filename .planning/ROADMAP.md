# Roadmap: FYP Education & Post-op Mortality

## Overview

Sort the home-PC mess into a clean repo first (Phases 1–2, home PC only), then verify each
pipeline stage on real data on the work PC (Phases 3–6), then wire it into one run command
(Phase 7). Reading level and health literacy join when delivered (Phase 8).

Phases marked **[work PC]** have code written on the home PC but are only complete after
Gerard runs them in SAS on the work PC and the log is reviewed.

## Phases

- [ ] **Phase 1: Inventory & Triage** - Scan the copied mess, find duplicates and versions, approve a file map, move files
- [ ] **Phase 2: Repo Layout & Config** - Fold legacy code into the numbered pipeline; single SAS/R config; no hard-coded paths
- [ ] **Phase 3: FIBRO Import & Clean** [work PC] - fyp.fibro_clean with QC checked against the deck
- [ ] **Phase 4: Clarity Concept Discovery** [work PC] - Profile `Patent Education Indicator\` and settle what CLARITY_CONCEPT is for
- [ ] **Phase 5: Descriptives & Figures** [work PC] - Distributions, % died bars, MT stacked bars, Table 1
- [ ] **Phase 6: Models** [work PC] - Logistic models, hierarchical tests, Table 2, forest plots
- [ ] **Phase 7: Run-All & Hand-off** [work PC] - 99_run_all.sas, run_pipeline.cmd, README
- [ ] **Phase 8: Literacy Integration** (v2, blocked) - Reading level and health literacy analyses

## Phase Details

### Phase 1: Inventory & Triage
**Goal**: Every file from the old folders is accounted for and sitting in the right place, with nothing lost
**Depends on**: Nothing (Gerard has copied the old folders into `_inbox/`)
**Requirements**: ORG-01, ORG-02, ORG-03, ORG-04, ORG-05, ORG-06
**Success Criteria** (what must be TRUE):
  1. `docs/inventory/inventory.csv` lists every file under `_inbox/` (row count = file count)
  2. `docs/inventory/inventory_summary.md` shows duplicate groups, version families and flagged data files
  3. Gerard has filled or accepted every `final_disposition` in `file_map.csv`; no row left as `REVIEW`
  4. After `apply_file_map.py --apply`, `_inbox/` is empty except `.gitkeep`, and `moves_log.csv` has one row per moved file
  5. `git status` shows no data files staged
**Plans**: 4 plans
- [x] 01-01-PLAN.md — Harden inventory.py (D-05) and apply_file_map.py (D-19); smoke-test both
- [ ] 01-02-PLAN.md — Confirm SOURCES.md, run the scan, review duplicates/versions/data and missing references
- [ ] 01-03-PLAN.md — Resolve REVIEW rows (Claude then Gerard), approve file_map.csv, clean dry run
- [ ] 01-04-PLAN.md — Apply the map, verify moves, close .gitignore (D-14), PHI scan, Phase 1 commit
**Gate**: Human approval of `file_map.csv` before `--apply`

### Phase 2: Repo Layout & Config
**Goal**: Each piece of legacy logic either lives in a numbered pipeline program or is documented as superseded
**Depends on**: Phase 1
**Requirements**: ORG-07, CFG-01, CFG-02, CFG-03, CFG-04
**Success Criteria** (what must be TRUE):
  1. `docs/FILE_MAP.md` maps each `legacy/` program to its replacement (or "reference only")
  2. MT_EDUC_GROUP / MT_ASA / MT_Frailty_Score cut points in `sas/20_mt_stacked_bars_data.sas` match the legacy `create_data_MT_*` code (or Q-07 is logged as open)
  3. `python tools/check_paths.py` exits 0
  4. Every `sas/*.sas` (except 00) begins with the standard two-line header
**Plans**: TBD

### Phase 3: FIBRO Import & Clean [work PC]
**Goal**: A clean, documented analysis file whose numbers match what the deck already reports
**Depends on**: Phase 2
**Requirements**: DAT-01, DAT-02, DAT-03, DAT-04
**Success Criteria** (what must be TRUE):
  1. `01_import_clean.sas` log has 0 ERRORs; every WARNING is explained in the plan summary
  2. All 9 variables are found (or the keep list is corrected from `PROC CONTENTS`)
  3. QC N, deaths and education mean/SD are compared with slides 5–6 and differences explained
  4. `docs/DATA_SOURCES.md` lists the cleaning rules actually applied
**Plans**: TBD

### Phase 4: Clarity Concept Discovery [work PC]
**Goal**: We know what is in `Patent Education Indicator\` and whether/how it feeds the analysis
**Depends on**: Phase 2 (independent of Phase 3)
**Requirements**: CLR-01, CLR-02, CLR-03, CLR-04, CLR-05
**Success Criteria** (what must be TRUE):
  1. `qc\10_clarity_profile.xlsx` exists with KEY, file list, contents, samples and keyword hits
  2. `docs/DATA_SOURCES.md` has a CLARITY_CONCEPT section: grain, key columns, relevant concept IDs
  3. Q-03 to Q-06 answered, or parked with an owner (Gerard / Mackenzie / whoever pulled the extract)
  4. A decision (D-NN) records whether Clarity data enters v1, v2, or neither
**Plans**: TBD

### Phase 5: Descriptives & Figures [work PC]
**Goal**: The descriptive slides can be regenerated from code
**Depends on**: Phase 3
**Requirements**: DSC-01, DSC-02, DSC-03, DSC-04
**Success Criteria** (what must be TRUE):
  1. `figures\` has the education histogram, % died by education (sex; surgery type if the variable exists) and three MT stacked bars, all in UF colors
  2. `exports\MT_educ_stacked_bars.csv` has 42 rows (3 variables × 7 groups × 2 levels)
  3. Table 1 in `tables\FIBRO_FYP_Results.xlsx` (KEY first)
**Plans**: TBD

### Phase 6: Models [work PC]
**Goal**: Table 2 and Figure 3 for the 10/30 meeting
**Depends on**: Phase 3
**Requirements**: MOD-01, MOD-02, MOD-03, MOD-04, MOD-05
**Success Criteria** (what must be TRUE):
  1. Models M0, M1, M1b converge with no quasi-separation warnings (or they are explained)
  2. LR tests use the same sample for nested models
  3. Table 2, ModelFit and Hierarchical sheets exist; Fig3a/3b PNGs in `figures\`
**Plans**: TBD

### Phase 7: Run-All & Hand-off [work PC]
**Goal**: Anyone can rebuild everything with one command
**Depends on**: Phases 3–6
**Requirements**: RUN-01, RUN-02, RUN-03
**Success Criteria** (what must be TRUE):
  1. Deleting `FYP_Education\` on P: and running `run_pipeline.cmd` recreates every output
  2. One dated log per run in `logs\`
  3. README run instructions tested by Gerard on the work PC
**Plans**: TBD

### Phase 8: Literacy Integration (v2)
**Goal**: Aims 2–3 (reading level, interaction) answered
**Depends on**: Phase 6 + delivery of reading level / health literacy
**Requirements**: LIT-01, LIT-02, LIT-03, LIT-04
**Success Criteria** (what must be TRUE):
  1. `HAVE_READ` / `HAVE_HL` switched on in `30_models.sas` and all extra outputs produced
**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Inventory & Triage | 1/4 | In Progress|  |
| 2. Repo Layout & Config | 0/TBD | Not started | - |
| 3. FIBRO Import & Clean | 0/TBD | Not started | - |
| 4. Clarity Concept Discovery | 0/TBD | Not started | - |
| 5. Descriptives & Figures | 0/TBD | Not started | - |
| 6. Models | 0/TBD | Not started | - |
| 7. Run-All & Hand-off | 0/TBD | Not started | - |
| 8. Literacy Integration | 0/TBD | Blocked | - |
