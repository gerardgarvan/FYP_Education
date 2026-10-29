# Analysis Plan (from FYP_PRECEDE Ops_10-26-26_MT.pptx)

**Title:** Effect of education on post-op prognosis — Mackenzie Topper, PRECEDE II Ops, 10/23/2026

## Aims

1. Association of years of education with 1-year post-op mortality (expected inverse).
2. Association of reading level (functional literacy) with 1-year mortality (expected inverse).
3. (Possible) Education × reading level interaction — lowest on both = highest risk.

## Slides that need regenerating

| Slide | Content | Program |
|---|---|---|
| 5 | Distributions: reading level (mean 55.87, SD 10.19, range 5–70); years of education (mean 13.87, SD 3.0, range 0–32) | `20_` / R histogram (reading level: v2) |
| 6 | % died by year of education, stacked by sex; Died 725 (4.8%), Male 436, Female 282 | `R/22_plot_died_by_edu.R` |
| 7 | % died by year of education, stacked by surgery type (Abdominal, Cardiothoracovascular, CNS, Head and Neck, Musculoskeletalcutaneous, OB) | `R/22_plot_died_by_edu.R` (needs Q-10) |
| 8 | Proposed analyses | `30_models.sas` |
| 9 | Table 1, Table 2, Fig 1 (education vs reading level), Fig 2 (functional vs health literacy), Fig 3 (forest plot) | `30_models.sas` |

## Proposed analyses (slide 8)

- Spearman: years of education vs reading level; functional vs health literacy (v2)
- Logistic regressions (written on the slide as `lm`, run as logistic):
  - 1Y mortality ~ education + ASA + frailty + surgery length + age + sex + race
  - 1Y mortality ~ reading level + same covariates (v2)
  - 1Y mortality ~ education + reading level + covariates (v2)
- Hierarchical regression (nested LR tests)
- Interaction: education × reading level (v2)
- Open on slide: education continuous or ordinal? → both are fit (M1, M1b)
