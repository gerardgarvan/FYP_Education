# Requirements: FYP Education & Post-op Mortality

**Defined:** 2026-10-28
**Core Value:** One command on the work PC rebuilds every deck table and figure from FIBRO_MASTER, with all I/O on P:.

## v1 Requirements

### Organization (home PC)

- [x] **ORG-01**: Every file copied into `_inbox/` is inventoried (path, type, size, modified date, SHA-256, keywords, paths it references) in `docs/inventory/inventory.csv`
- [ ] **ORG-02**: Exact duplicates are grouped and one canonical copy is chosen per group
- [ ] **ORG-03**: Version families (same file, different dates/initials/_v2/_final) are grouped and the current version identified
- [ ] **ORG-04**: Data files and possible PHI are flagged `DATA` and kept out of every tracked folder
- [x] **ORG-05**: Gerard approves `docs/inventory/file_map.csv` before anything moves
- [x] **ORG-06**: Approved files are moved into `legacy/`, `docs/reference/` or `archive/`; nothing is deleted; every move is logged in `docs/inventory/moves_log.csv`
- [ ] **ORG-07**: `docs/FILE_MAP.md` explains, in plain language, what each kept legacy program did and which new pipeline program replaces it

### Configuration

- [ ] **CFG-01**: `sas/00_config.sas` defines every SAS path, library and option; every program includes it
- [ ] **CFG-02**: `R/00_config.R` defines every R path and the UF colors
- [ ] **CFG-03**: `tools/check_paths.py` finds no hard-coded drive, UNC, `/blue` or `/mnt` paths outside the two config files
- [ ] **CFG-04**: Output folders on P: (`sasdata`, `exports`, `tables`, `figures`, `qc`, `logs`) are created automatically on first run

### FIBRO data

- [ ] **DAT-01**: `01_import_clean.sas` imports FIBRO_MASTER_APRIL_20_2026_4_MT and keeps the 9 analysis variables
- [ ] **DAT-02**: Cleaning rules (type coercion, Sex/Race standardization, range checks, duplicate IDs, mortality flags) are applied and listed in `docs/DATA_SOURCES.md`
- [ ] **DAT-03**: QC output (N, missingness, distributions, removed duplicates) is written to `qc\` and reviewed against the deck (e.g., education mean ≈ 13.87, SD ≈ 3.0)
- [ ] **DAT-04**: `fyp.fibro_clean` and `exports\FIBRO_CLEAN.xlsx` are produced

### Clarity concept / education indicator

- [ ] **CLR-01**: Every file in `Patent Education Indicator\` is listed with type and size
- [ ] **CLR-02**: Each readable table is profiled (rows, columns, types, first rows)
- [ ] **CLR-03**: Rows mentioning education, schooling, grade, degree, literacy, reading, learning or teaching are extracted for review
- [ ] **CLR-04**: The role of CLARITY_CONCEPT is documented: lookup only vs patient-level, which concept IDs matter, and how (or whether) it links to FIBRO
- [ ] **CLR-05**: Open questions Q-03 to Q-06 are answered or explicitly parked

### Descriptives and figures

- [ ] **DSC-01**: Distribution figures for years of education (and reading level when available) match slide 5
- [ ] **DSC-02**: % died by year of education, stacked by sex and by surgery type (slides 6–7)
- [ ] **DSC-03**: `MT_educ_stacked_bars.csv` and the three stacked-bar plots (ASA, frailty, 1-year mortality by MT_EDUC_GROUP)
- [ ] **DSC-04**: Table 1 — characteristics by 1-year mortality

### Models

- [ ] **MOD-01**: Logistic model — 1-year mortality ~ years of education (continuous) + ASA + frailty + surgery length + age + sex + race
- [ ] **MOD-02**: Same model with education as ordinal categories
- [ ] **MOD-03**: Hierarchical likelihood-ratio tests between nested models on one sample
- [ ] **MOD-04**: Table 2 (OR, 95% CI, p) and model-fit sheet in a workbook with KEY first
- [ ] **MOD-05**: Forest plots (Figure 3) in UF colors

### Run and hand-off

- [ ] **RUN-01**: `99_run_all.sas` runs the pipeline in order and writes a dated log to `logs\`
- [ ] **RUN-02**: `run_pipeline.cmd` runs SAS in batch from the repo, then the R plots if R is installed
- [ ] **RUN-03**: `README.md` lets someone who has never seen the project run it on the work PC

## v2 Requirements

### Literacy

- **LIT-01**: Merge reading level and health literacy by PRECEDE_Study_ID when delivered
- **LIT-02**: Spearman correlations and Figures 1–2
- **LIT-03**: Models 2–4 (reading level, both, interaction) and three-step hierarchical tests
- **LIT-04**: Follow-up restriction (exclude surgeries < 1 year before data pull) once a surgery date is available

## Out of Scope

| Feature | Reason |
|---------|--------|
| Direct Clarity/SQL Server queries | Work from extracts on P: |
| Rebuilding PeCAN master datasets | Separate master-merge project |
| Running SAS on the home PC | No SAS or P: access there |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ORG-01 – ORG-06 | Phase 1 | Pending |
| ORG-07, CFG-01 – CFG-04 | Phase 2 | Pending |
| DAT-01 – DAT-04 | Phase 3 | Pending |
| CLR-01 – CLR-05 | Phase 4 | Pending |
| DSC-01 – DSC-04 | Phase 5 | Pending |
| MOD-01 – MOD-05 | Phase 6 | Pending |
| RUN-01 – RUN-03 | Phase 7 | Pending |
| LIT-01 – LIT-04 | Phase 8 (v2) | Blocked — data not delivered |

**Coverage:** v1 requirements 33, mapped 33, unmapped 0

---
*Requirements defined: 2026-10-28*
