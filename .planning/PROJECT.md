# FYP Education & Post-op Mortality

## What This Is

A SAS/R analysis pipeline for Mackenzie Topper's first-year project (PRECEDE II Ops):
does education — years of schooling, and later reading level and health literacy —
predict 1-year mortality after surgery? The project starts by turning a scattered pile
of programs, slides, CSVs and notes on Gerard's home PC into one organized repo whose
programs run on the work PC against data on the P: drive.

## Core Value

One command on the work PC (`run_pipeline.cmd`) rebuilds every table and figure for
the PRECEDE Ops deck from `FIBRO_MASTER_APRIL_20_2026_4_MT`, with all inputs and outputs
on the share and no hard-coded paths anywhere but the config files.

## Requirements

### Validated

(None yet — ship to validate)

### Active

See `.planning/REQUIREMENTS.md` (ORG, CFG, DAT, CLR, DSC, MOD, LIT, RUN).

### Out of Scope

- Pulling data directly from Clarity (claritysqlprod) — we work from extracts on P:.
- Re-deriving the PeCAN master datasets — that is the separate master-merge project.
- Reading level / health literacy analyses until those variables are delivered (LIT, v2).

## Context

- **Deck:** `FYP_PRECEDE Ops_10-26-26_MT.pptx` — aims, distributions, % died by years of
  education (stacked by sex and by surgery type), proposed analyses (Spearman, logistic
  models, hierarchical regression, education × reading-level interaction), next steps
  (Table 1, Table 2, Figures 1–3) for the 10/30 PRECEDE Ops meeting. Summary in
  `docs/ANALYSIS_PLAN.md`.
- **Primary data:** `FIBRO_MASTER_APRIL_20_2026_4_MT.xlsx`. Analysis variables:
  PRECEDE_Study_ID, rt_AN_START_to_AN_END_mins, Frailty_Score, Edu_Years_CWG,
  ASA__Anesth_Record_, Age_at_Encounter, Sex, Race, Death_Days_After_Surgery.
- **Second source (murky):** `claritysqlprod.clarity.dbo.CLARITY_CONCEPT`, in
  `P:\...\Mackenzie Topper\Patent Education Indicator`. In Epic Clarity this table is
  normally a lookup of concept IDs → names (SmartData elements), not patient-level data.
  Its role here is unknown — see `docs/OPEN_QUESTIONS.md` Q-03 to Q-06.
- **Earlier work to fold in:** `import_clean_fibro_master.sas`, `fibro_fyp_analysis.sas`,
  `make_MT_educ_stacked_bars.sas`, `plot_MT_educ_stacked_bars.R`, `fyp_died_by_edu_bars.R`,
  and the PeCAN-era `create_data_MT_Sept_30_2026_GJG.sas` / `results_MT_*_GJG.sas`
  (defines MT_EDUC_GROUP, MT_ASA, MT_Frailty_Score). Starter versions of the first five
  are already in `sas/` and `R/`, repointed to the config.
- **Pattern borrowed from the master-merge project:** code repo on `C:\`, data/QC/logs on
  P:, one `00_config.sas` included by every program, `99_run_all.sas` + `run_pipeline.cmd`.

## Constraints

- **Machines:** Claude CLI runs on the home PC (no SAS, no P:). SAS runs on the work PC.
- **Paths:** programs on the work PC's local drive (`C:\FYP_Education`); inputs and outputs on
  `P:\PeCAN Research\06 Individual Folders\Mackenzie Topper`.
- **Data:** no data or PHI in the repo, ever.
- **Deliverables:** KEY sheet leftmost; UF colors; measured language.
- **Deadline:** tables and figures for PRECEDE Ops on 2026-10-30.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Repo on C:, data on P: | Git on P: corrupted an index before; P: is the shared source of truth | — Pending |
| Outputs in a `FYP_Education\` subfolder of Mackenzie's folder | Keeps her folder root clean; one place to clear and rebuild | — Pending |
| Organize by copy → inventory → approve → move; never delete | Mess may hold the only copy of something | — Pending |
| Starter programs repointed, not rewritten | They already match the deck; Phase 3+ verifies them on real data | — Pending |

---
*Last updated: 2026-10-28 after project initialization*
