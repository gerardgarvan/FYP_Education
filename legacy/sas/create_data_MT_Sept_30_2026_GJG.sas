


options ls=76; 
%let path=P:\PeCAN Master Data\Garvan\Mackenzie_Topper;

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
run;



data two; set one (keep=
  studyid sex_cat Mortality_1Y ASA_Anest_Record rt_AN_START_to_AN_END_mins
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
race_sa2
  age sex Frailty_Score Edu_Years Service_PT Dischg_Disposition
  Mortality_One_Year _30_DAY_MORTALITY LOS_HOURS_CWG
  pecaner MCI_PECAN TIME_ICU2 total_icu_time ICU_LOS_TOTAL_TIME_HOURS
  MCI_NEW_CONDENSED 
);
if cwg_COMDwgTotTime GE 152 then cwg_COMDwgTotTime=155;

nonhome=.;
if Dischg_Disposition ne "" then nonhome=1;
if Dischg_Disposition="TO HOME" or Dischg_Disposition="TO HOME PLANNED READMIT"
or Dischg_Disposition="TO HOMECARE" or Dischg_Disposition="TO HOMECARE PLANNED READMIT" then nonhome=0; 

MT_EDUC_GROUP=.;
if Edu_Years GE 0 and Edu_Years LT 5 then MT_EDUC_GROUP=1;
if Edu_Years GE 5 and Edu_Years LT 7 then MT_EDUC_GROUP=1;
if Edu_Years GE 7 and Edu_Years LT 9 then MT_EDUC_GROUP=2;
if Edu_Years GE 9 and Edu_Years LT 12 then MT_EDUC_GROUP=3;
if Edu_Years = 12 then MT_EDUC_GROUP=4;
if Edu_Years GT 12 and Edu_Years LT 16 then MT_EDUC_GROUP=5;
if Edu_Years = 16 then MT_EDUC_GROUP=6;
if Edu_Years GT 16  then MT_EDUC_GROUP=7;

MEGA_GROUP=.;
if MT_EDUC_GROUP GE 0 and MT_EDUC_GROUP LT 4 then MEGA_GROUP=1;
if MT_EDUC_GROUP GE 4 and MT_EDUC_GROUP LT 5 then MEGA_GROUP=2;
if MT_EDUC_GROUP GE 5                    then MEGA_GROUP=3;


MT_ASA=.;
if ASA=1 or ASA= 2 then MT_ASA=1;
if ASA GE 3 then MT_ASA=2;

MT_Frailty_Score=.;
if Frailty_Score GE 0 and Frailty_Score LE 2 then MT_Frailty_Score=1;
if Frailty_Score GT 2 then MT_Frailty_Score=2;
/*
Non-Frail: 02 criteria met (combines the purely robust [0] 
and pre-frail [12] categories).Frail: 35 criteria met.
*/

anest_time_group=.;
if rt_AN_START_to_AN_END_mins ne . and rt_AN_START_to_AN_END_mins LE 59 then anest_time_group=1;
if rt_AN_START_to_AN_END_mins GT 59 and rt_AN_START_to_AN_END_mins LE 128 then anest_time_group=2;
if rt_AN_START_to_AN_END_mins GT 128 and rt_AN_START_to_AN_END_mins LE 208 then anest_time_group=3;
if rt_AN_START_to_AN_END_mins GT 208 then anest_time_group=4;
run;




