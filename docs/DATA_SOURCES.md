# Data Sources

Share root: `P:\PeCAN Research\06 Individual Folders\Mackenzie Topper`

## FIBRO_MASTER_APRIL_20_2026_4_MT.xlsx

- **Location:** share root (unconfirmed, Q-01)
- **Grain:** one row per PRECEDE_Study_ID (duplicates removed in 01, first kept, listed in QC)
- **Variables kept**

| Variable | Meaning | Cleaning |
|---|---|---|
| PRECEDE_Study_ID | Study ID | Character, stripped; blank rows dropped |
| rt_AN_START_to_AN_END_mins | Anesthesia duration (min) | ≤ 0 → missing |
| Frailty_Score | Frailty score | Numeric coercion |
| Edu_Years_CWG | Years of education | Outside 0–30 → missing |
| ASA__Anesth_Record_ | ASA class | Not 1–6 → missing |
| Age_at_Encounter | Age (years) | Outside 18–110 → missing |
| Sex | Sex | Female / Male / Other/Unk |
| Race | Race | Trimmed, proper case; unknown/declined → missing |
| Death_Days_After_Surgery | Days surgery → death | < 0 → missing |

- **Derived:** Died_Any, Died_30d, Died_90d, Died_1yr (death 0–365 days; no death date = alive)
- Text-to-number coercion treats `NA`, `N/A`, `NULL`, `UNKNOWN`, `MISSING`, `.` and blank as missing;
  anything else that fails is written to the log as a WARNING with the ID.

## claritysqlprod.clarity.dbo.CLARITY_CONCEPT

- **Location:** `Patent Education Indicator\` (spelling unconfirmed, Q-02)
- **Status:** unknown — filled in by Phase 4 (`10_clarity_profile.sas`)
- **Background:** in Epic Clarity, CLARITY_CONCEPT is usually a dictionary of concept IDs and names
  (SmartData elements). On its own it identifies *which* concepts exist, not patient values.

## Reading level / health literacy

- **Status:** not delivered. `30_models.sas` reads them from `LITERACY_VARS.xlsx` on the share
  when `HAVE_READ` / `HAVE_HL` are set to 1.
