options ls=76; 
%let path=I:\PeCAN Master Data\Garvan\Mackenzie_Topper;

libname c "&path";



data one;set c.pecandata20230926v2;
 ARRAY oldCLK(36) 
COMDwgTotTime
COMDwgTotStrokes
COMClockFace1HorizSz
COMClockFace1VertSz
COMclockface_area1
COMClockFace1EllipHSymm
COMClockFace1EllipVSymm
COMHH1HandLen
COMmocaHandRatio
COMMH1HandLen
COMHH1DiffIdealAng
COMHH1AngTo11
COMMH1DiffIdealAng
COMMH1AngTo2
COMClockFaceNonClockFaceLatency
COMClockFaceNonClockFaceNoNoiseL
COMPreFirstHandLatency
COMPreFirstHandNoNoiseLatency
COPYDwgTotTime
COPYDwgTotStrokes
COPYClockFace1HorizSz
COPYClockFace1VertSz
COPYclockface_area1
COPYClockFace1EllipHSymm
COPYClockFace1EllipVSymm
COPYHH1HandLen
COPYmocaHandRatio
COPYMH1HandLen
COPYHH1DiffIdealAng
COPYHH1AngTo11
COPYMH1DiffIdealAng
COPYMH1AngTo2
COPYClockFaceNonClockFaceLatency
COPYClockFaceNonClockFaceNoNoise
COPYPreFirstHandLatency
COPYPreFirstHandNoNoiseLatency
;
 ARRAY newCLK(36) 
cwg_COMDwgTotTime
cwg_COMDwgTotStrokes
cwg_COMCLKFace1HorizSz
cwg_COMCLKFace1VertSz
cwg_COMCLKface_area1
cwg_COMCLKFace1EllipHSymm
cwg_COMCLKFace1EllipVSymm
cwg_COMHH1HandLen
cwg_COMmocaHandRatio
cwg_COMMH1HandLen
cwg_COMHH1DiffIdealAng
cwg_COMHH1AngTo11
cwg_COMMH1DiffIdealAng
cwg_COMMH1AngTo2
cwg_COMCLKFaceNonCLKFaceLAT
cwg_COMCLKFaceNonCLKFaceNoNoiseL
cwg_COMPreFirstHandLAT
cwg_COMPreFirstHandNoNoiseLAT
cwg_COPYDwgTotTime
cwg_COPYDwgTotStrokes
cwg_COPYCLKFace1HorizSz
cwg_COPYCLKFace1VertSz
cwg_COPYCLKface_area1
cwg_COPYCLKFace1EllipHSymm
cwg_COPYCLKFace1EllipVSymm
cwg_COPYHH1HandLen
cwg_COPYmocaHandRatio
cwg_COPYMH1HandLen
cwg_COPYHH1DiffIdealAng
cwg_COPYHH1AngTo11
cwg_COPYMH1DiffIdealAng
cwg_COPYMH1AngTo2
cwg_COPYCLKFaceNonCLKFaceLAT
cwg_COPYCLKFaceNonCLKFaceNoNoise
cwg_COPYPreFirstHandLAT
cwg_COPYPreFirstHandNoNoiseLAT
;
 DO i = 1 TO 36;
        newCLK(i)= oldCLK{i};
        if oldCLK{i}=-999 then newCLK(i) = .;
 END;     
 drop i;
run;


proc contents data=one varnum;
title "Contents - variable order";
run;
/*
proc univariate plots data=one;
var
COMDwgTotTime
COMDwgTotStrokes
COMClockFace1HorizSz
COMClockFace1VertSz
COMclockface_area1
COMClockFace1EllipHSymm
COMClockFace1EllipVSymm
COMHH1HandLen
COMmocaHandRatio
COMMH1HandLen
COMHH1DiffIdealAng
COMHH1AngTo11
COMMH1DiffIdealAng
COMMH1AngTo2
COMClockFaceNonClockFaceLatency
COMClockFaceNonClockFaceNoNoiseL
COMPreFirstHandLatency
COMPreFirstHandNoNoiseLatency
COPYDwgTotTime
COPYDwgTotStrokes
COPYClockFace1HorizSz
COPYClockFace1VertSz
COPYclockface_area1
COPYClockFace1EllipHSymm
COPYClockFace1EllipVSymm
COPYHH1HandLen
COPYmocaHandRatio
COPYMH1HandLen
COPYHH1DiffIdealAng
COPYHH1AngTo11
COPYMH1DiffIdealAng
COPYMH1AngTo2
COPYClockFaceNonClockFaceLatency
COPYClockFaceNonClockFaceNoNoise
COPYPreFirstHandLatency
COPYPreFirstHandNoNoiseLatency;
title "Check";
run;
*/


/*------------------------------------------------------------------*
 * EDU_GROUPS: cumulative binary indicators for years of education
 *   &prefix._ge5  = 1 if Edu_Years >= 5,  else 0
 *   &prefix._ge7  = 1 if Edu_Years >= 7,  else 0
 *   &prefix._ge9  = 1 if Edu_Years >= 9,  else 0
 *   &prefix._ge12 = 1 if Edu_Years >= 12, else 0
 * Together they reproduce the groups 0-4, 5-6, 7-8, 9-11, 12+
 * (0-4 = all four indicators 0).
 * Missing or negative (e.g., -999) -> all indicators missing.
 * Call INSIDE a data step.
 *------------------------------------------------------------------*/
%macro edu_groups(invar=Edu_Years, prefix=edu);
  if missing(&invar) or &invar < 0 then do;
    &prefix._ge5  = .;
    &prefix._ge7  = .;
    &prefix._ge9  = .;
    &prefix._ge12 = .;
  end;
  else do;
    &prefix._ge5  = (&invar >= 5);
    &prefix._ge7  = (&invar >= 7);
    &prefix._ge9  = (&invar >= 9);
    &prefix._ge12 = (&invar >= 12);
  end;
  label &prefix._ge5  = "Education 5+ years (1=yes)"
        &prefix._ge7  = "Education 7+ years (1=yes)"
        &prefix._ge9  = "Education 9+ years (1=yes)"
        &prefix._ge12 = "Education 12+ years (1=yes)";
%mend edu_groups;


data two; set one (keep=
  studyid sex_cat Mortality_1Y ASA_Anest_Record 
  wrat_total_raw    wrat_total_raw2 
wrat_desc  edu_categorical ASA
cwg_COMDwgTotTime
cwg_COMDwgTotStrokes
cwg_COMCLKFace1HorizSz
cwg_COMCLKFace1VertSz
cwg_COMCLKface_area1
cwg_COMCLKFace1EllipHSymm
cwg_COMCLKFace1EllipVSymm
cwg_COMHH1HandLen
cwg_COMmocaHandRatio
cwg_COMMH1HandLen
cwg_COMHH1DiffIdealAng
cwg_COMHH1AngTo11
cwg_COMMH1DiffIdealAng
cwg_COMMH1AngTo2
cwg_COMCLKFaceNonCLKFaceLAT
cwg_COMCLKFaceNonCLKFaceNoNoiseL
cwg_COMPreFirstHandLAT
cwg_COMPreFirstHandNoNoiseLAT
cwg_COPYDwgTotTime
cwg_COPYDwgTotStrokes
cwg_COPYCLKFace1HorizSz
cwg_COPYCLKFace1VertSz
cwg_COPYCLKface_area1
cwg_COPYCLKFace1EllipHSymm
cwg_COPYCLKFace1EllipVSymm
cwg_COPYHH1HandLen
cwg_COPYmocaHandRatio
cwg_COPYMH1HandLen
cwg_COPYHH1DiffIdealAng
cwg_COPYHH1AngTo11
cwg_COPYMH1DiffIdealAng
cwg_COPYMH1AngTo2
cwg_COPYCLKFaceNonCLKFaceLAT
cwg_COPYCLKFaceNonCLKFaceNoNoise
cwg_COPYPreFirstHandLAT
cwg_COPYPreFirstHandNoNoiseLAT

  age sex Frailty_Score Edu_Years Service_PT Dischg_Disposition
  Mortality_One_Year _30_DAY_MORTALITY LOS_HOURS_CWG
  pecaner MCI_PECAN TIME_ICU2 total_icu_time ICU_LOS_TOTAL_TIME_HOURS
  MCI_NEW_CONDENSED 
);
if cwg_COMDwgTotTime GE 152 then cwg_COMDwgTotTime=155;

/* nonhome: 1 = any non-home discharge, 0 = home/homecare, . = missing */
nonhome=.;
if Dischg_Disposition ne "" then nonhome=1;
if Dischg_Disposition in ("TO HOME" "TO HOME PLANNED READMIT"
                          "TO HOMECARE" "TO HOMECARE PLANNED READMIT") then nonhome=0; 

/* Invalid education codes (e.g., -999) -> missing for all analyses */
if Edu_Years < 0 then Edu_Years = .;

%edu_groups();
run;


/* Check: each Edu_Years value should show the expected 0/1 pattern */
proc freq data=two;
  tables Edu_Years*edu_ge5*edu_ge7*edu_ge9*edu_ge12 / list missing;
  title "Check education indicator variables";
run;


/*------------------------------------------------------------------*
 * INS Abstract - descriptive screen of TWO
 * Output: RTF (opens in Word) written to the project folder
 * Assumes DATA TWO has already been built (see prior step)
 *------------------------------------------------------------------*/


/*==================================================================*
 * 1. CATEGORICAL 
 *==================================================================*/


*ods rtf file="&path\results_MT_Sept_25_2026.doc"; 


proc freq data=two;
  title "Categorical variables - valid percentages (missing excluded)";
  tables sex_cat ASA_Anest_Record edu_categorical ASA
         wrat_total_raw wrat_total_raw2 wrat_desc
         Frailty_Score
         nonhome
         Service_PT
         Dischg_Disposition*nonhome
         MCI_NEW_CONDENSED
         _30_DAY_MORTALITY
         Mortality_1Y
         pecaner;
run;

proc freq data=two;
tables  Edu_Years*(ASA_Anest_Record  Frailty_Score Mortality_1Y);
title "Edu_Years by ASA, frailty, and 1-year mortality";
run;

/*==================================================================*
 * 2. CONTINUOUS VARIABLES 
 *==================================================================*/

proc univariate data=two plots;
  title "Continuous variables - distribution and outliers";
  var age
      Edu_Years
      Frailty_Score
      LOS_HOURS_CWG
      TIME_ICU2
      cwg_COMDwgTotTime  cwg_COPYDwgTotTime;
run;

proc corr data=two spearman;
var Edu_Years;
with 
age
Frailty_Score
LOS_HOURS_CWG
TIME_ICU2
cwg_COMDwgTotTime
cwg_COPYDwgTotTime;
title "Spearman correlations with Edu_Years";
run;


/*------------------------------------------------------------------*
 * EDU_BY_CLASS: for each class variable, Wilcoxon test and
 * descriptive means of Edu_Years. Each variable runs separately,
 * so a missing value in one class variable does not drop the row
 * from the others.
 *------------------------------------------------------------------*/
%macro edu_by_class(classvars=);
  %local k cv;
  %do k = 1 %to %sysfunc(countw(&classvars, %str( )));
    %let cv = %scan(&classvars, &k, %str( ));

    proc npar1way data=two wilcoxon;
      class &cv;
      var Edu_Years;
      title "Edu_Years by &cv - Wilcoxon";
    run;

    proc means data=two maxdec=1;
      class &cv;
      var Edu_Years;
      title "Edu_Years by &cv - means";
    run;
  %end;
%mend edu_by_class;

%edu_by_class(classvars=sex_cat nonhome Service_PT MCI_NEW_CONDENSED
                        _30_DAY_MORTALITY Mortality_1Y pecaner);

*ods rtf close; 



/* Pre-model check: REF= values below must match these levels exactly */
proc freq data=two;
  tables Service_PT sex_cat Mortality_1Y / missing;
  title "Pre-model check - levels of model CLASS variables and outcome";
run;


proc logistic data=two descending;
class service_PT (ref="Musculoskeletalcutaneous") sex_cat (ref="FEMALE") /param=ref;
model Mortality_1Y = sex_cat age Edu_Years service_PT Edu_Years*service_PT;
title "Logistic regression - 1-year mortality (education x service interaction)";
run;

ods rtf file="&path\results_MT_Aug_27_2026_mortality_model.doc"; 


proc freq data=two;
  tables (Service_PT sex_cat)*Mortality_1Y /chisq;
title "1-year mortality by service and sex";
run;


proc logistic data=two descending;
class service_PT (ref="Musculoskeletalcutaneous") sex_cat (ref="FEMALE") /param=ref;
model Mortality_1Y = sex_cat age Edu_Years service_PT;
title "Logistic regression - 1-year mortality (main effects)";
run;


ods rtf close; 


proc contents data=two;
title "Contents";
run;
