# File Map

Written in Phase 2 after the Phase 1 moves. One row per kept legacy file.

| Legacy file | What it did | Replaced by | Notes |
|---|---|---|---|
| _(filled in Phase 2)_ | | | |

## Pipeline programs

| Program | Stage | Reads | Writes |
|---|---|---|---|
| `sas/00_config.sas` | Config | — | Creates output folders, `fyp` library |
| `sas/01_import_clean.sas` | Import & clean | FIBRO_MASTER xlsx | `fyp.fibro_clean`, `exports\FIBRO_CLEAN.xlsx`, `qc\01_import_clean_qc.xlsx` |
| `sas/10_clarity_profile.sas` | Discovery | `Patent Education Indicator\*` | `qc\10_clarity_profile.xlsx` |
| `sas/20_mt_stacked_bars_data.sas` | Descriptives | `fyp.fibro_clean` | `exports\MT_educ_stacked_bars.csv` |
| `sas/30_models.sas` | Tables & models | `fyp.fibro_clean` | `tables\FIBRO_FYP_Results.xlsx`, Fig3 PNGs |
| `sas/99_run_all.sas` | Orchestration | — | `logs\run_all_<date>.log` |
| `R/21_plot_mt_stacked_bars.R` | Figures | `exports\MT_educ_stacked_bars.csv` | 3 PNGs |
| `R/22_plot_died_by_edu.R` | Figures | `exports\FIBRO_CLEAN.xlsx` | % died bars, education histogram |
