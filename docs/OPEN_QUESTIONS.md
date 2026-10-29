# Open Questions

Format: Q-NN · question · why it matters · who can answer · status

## Inputs on P:

**Q-01 · Where exactly is FIBRO_MASTER_APRIL_20_2026_4_MT.xlsx?**
Config assumes the root of `P:\PeCAN Research\06 Individual Folders\Mackenzie Topper\`.
Also: which sheet holds the data? · Gerard · OPEN

**Q-02 · Is the folder really spelled "Patent Education Indicator"?**
Possibly "Patient". The config uses the spelling as given; one typo = file not found. · Gerard · OPEN

## Clarity concept / education indicator

**Q-03 · What is physically in `Patent Education Indicator\`?**
An export of `claritysqlprod.clarity.dbo.CLARITY_CONCEPT` (xlsx/csv/sas7bdat?), a SQL query,
patient-level results, or a mix? `10_clarity_profile.sas` answers the mechanical part. · Phase 4 · OPEN

**Q-04 · Which "education" is meant?**
In Epic, "patient education" usually means *teaching given to the patient* (education
documentation, learning barriers, preferred learning method), not *years of schooling*.
Both could appear as SmartData concepts. The analysis needs educational attainment
(and maybe a literacy screen). · Mackenzie / whoever requested the extract · OPEN

**Q-05 · Is CLARITY_CONCEPT a lookup only?**
Normally it maps CONCEPT_ID → NAME and carries no patient rows. If so, the patient-level values
live in another table (e.g., SmartData value tables) that is not in the folder yet. · Phase 4 · OPEN

**Q-06 · How would Clarity data link to FIBRO?**
FIBRO is keyed on PRECEDE_Study_ID. Clarity rows would carry PAT_ID / PAT_ENC_CSN_ID (or encrypted
MRN/encounter). Is there a crosswalk on P:? · Gerard · OPEN

## Definitions carried over from the PeCAN work

**Q-07 · MT_EDUC_GROUP, MT_ASA, MT_Frailty_Score definitions**
Phase 1 found TWO relevant programs in _inbox — BOTH will be moved to legacy/sas (Plan 04):
  - `create_data_MT_Oct_28_2026_GJG.sas` — current definitions file (newest by filename date, confirmed by Gerard)
  - `create_data_MT_Sept_30_2026_GJG.sas` — kept alongside for Phase 2 diff
Phase 2 action: diff Oct 28 vs Sept 30 to find any changes to MT_EDUC_GROUP, MT_ASA,
and MT_Frailty_Score cut points. Update 00_config.sas placeholder values if they differ
from (education 0-8/9-11/12/13-15/16/17-18/19+; ASA >= 2; frailty >= 3).
Both programs reference P:\PeCAN Master Data\Garvan\Mackenzie_Topper (not I:\). · Phase 2 · PARTIALLY RESOLVED

**Q-08 · Which mortality window does the deck use?**
Slides say "Died 725 (4.8%)" with no window; the % died charts disagree with each other at
4 years (≈10% vs ≈13%). 1-year (`Died_1yr`) or any recorded death (`Died_Any`)? · Mackenzie · OPEN

**Q-10 · Surgery type variable**
Needed for slide 7 (% died by education stacked by surgery type). Not in the current keep list.
Name in FIBRO_MASTER? · Gerard · OPEN

**Q-11 · Follow-up**
Patients operated < 1 year before the data pull are counted as alive at 1 year. Is a surgery
date or data-pull date available? · Gerard · OPEN

## Environment

**Q-09 · Work PC details**
Repo path (default `C:\FYP_Education`), SAS executable path (default
`C:\Program Files\SASHome\SASFoundation\9.4\sas.exe`), is R installed? · Gerard · OPEN
