%let proj_root = C:\FYP_Education;
%include "&proj_root.\sas\00_config.sas";
/*============================================================================
  Program : 01_import_clean.sas
  Purpose : Import FIBRO_MASTER_APRIL_20_2026_4_MT.xlsx, keep the analysis
            variables, coerce types, standardize categories, QC.
  Reads   : &src_fibro
  Writes  : fyp.fibro_clean
            &dir_exports\FIBRO_CLEAN.xlsx
            &dir_qc\01_import_clean_qc.xlsx  (KEY first)
  Reqs    : DAT-01 .. DAT-04
============================================================================*/

/*---- 1. Import ------------------------------------------------------------*/
proc import datafile="&src_fibro."
            out=work.fibro_raw
            dbms=xlsx
            replace;
    getnames=yes;
    %if %length(&src_fibro_sheet.) %then %do; sheet="&src_fibro_sheet."; %end;
run;

proc contents data=work.fibro_raw varnum out=work.raw_contents(keep=name type length varnum) noprint;
run;

/*---- 2. Keep target variables (fail loudly if any are missing) -----------*/
%let keepvars = PRECEDE_Study_ID
                rt_AN_START_to_AN_END_mins
                Frailty_Score
                Edu_Years_CWG
                ASA__Anesth_Record_
                Age_at_Encounter
                Sex
                Race
                Death_Days_After_Surgery;

%macro check_keep;
    %local i v dsid miss;
    %let dsid = %sysfunc(open(work.fibro_raw));
    %do i = 1 %to %sysfunc(countw(&keepvars.));
        %let v = %scan(&keepvars., &i.);
        %if %sysfunc(varnum(&dsid., &v.)) = 0 %then %let miss = &miss. &v.;
    %end;
    %let dsid = %sysfunc(close(&dsid.));
    %if %length(&miss.) %then %do;
        %put ERROR: [FYP] Not found in FIBRO_MASTER: &miss.. Check WORK.RAW_CONTENTS and fix keepvars.;
        %abort cancel;
    %end;
%mend check_keep;
%check_keep;

data work.fibro_keep;
    set work.fibro_raw(keep=&keepvars.);
run;

/*---- 3. Coerce numerics (columns Excel stored as text) --------------------*/
%macro to_num(var);
    %local dsid vnum vtype rc;
    %let dsid  = %sysfunc(open(work.fibro_keep));
    %let vnum  = %sysfunc(varnum(&dsid., &var.));
    %let vtype = %sysfunc(vartype(&dsid., &vnum.));
    %let rc    = %sysfunc(close(&dsid.));

    %if &vtype. = C %then %do;
        data work.fibro_keep;
            set work.fibro_keep(rename=(&var.=_&var._c));
            length _tmp $64;
            _tmp = upcase(strip(_&var._c));
            if _tmp in ('', '.', 'NA', 'N/A', 'NULL', 'UNKNOWN', 'MISSING') then &var. = .;
            else do;
                &var. = input(compress(_tmp, ', '), ?? best32.);
                if missing(&var.) then
                    put "WARNING: [FYP] non-numeric value in &var.: " PRECEDE_Study_ID= _&var._c=;
            end;
            drop _&var._c _tmp;
        run;
    %end;
%mend to_num;

%to_num(rt_AN_START_to_AN_END_mins);
%to_num(Frailty_Score);
%to_num(Edu_Years_CWG);
%to_num(ASA__Anesth_Record_);
%to_num(Age_at_Encounter);
%to_num(Death_Days_After_Surgery);

/*---- 4. Clean / standardize ----------------------------------------------*/
data work.fibro_clean;
    set work.fibro_keep;

    /* ID as character whatever type it was imported as */
    length _id $40;
    _id = strip(vvalue(PRECEDE_Study_ID));
    if missing(_id) or _id = '.' then delete;

    /* Sex */
    length Sex_c $10;
    select (upcase(strip(vvalue(Sex))));
        when ('F', 'FEMALE') Sex_c = 'Female';
        when ('M', 'MALE')   Sex_c = 'Male';
        when ('', '.')       Sex_c = '';
        otherwise            Sex_c = 'Other/Unk';
    end;

    /* Race */
    length Race_c $60;
    Race_c = propcase(strip(compbl(vvalue(Race))));
    if upcase(Race_c) in ('', '.', 'UNKNOWN', 'NA', 'N/A', 'NULL', 'MISSING', 'DECLINED', 'PATIENT REFUSED')
        then Race_c = '';

    drop PRECEDE_Study_ID Sex Race;
    rename _id = PRECEDE_Study_ID  Sex_c = Sex  Race_c = Race;

    /* Range checks (bounds are settings - record changes in docs/DATA_SOURCES.md) */
    if not missing(Age_at_Encounter)           and not (18 <= Age_at_Encounter <= 110)     then Age_at_Encounter = .;
    if not missing(ASA__Anesth_Record_)        and ASA__Anesth_Record_ not in (1,2,3,4,5,6) then ASA__Anesth_Record_ = .;
    if not missing(rt_AN_START_to_AN_END_mins) and rt_AN_START_to_AN_END_mins <= 0         then rt_AN_START_to_AN_END_mins = .;
    if not missing(Edu_Years_CWG)              and not (0 <= Edu_Years_CWG <= 30)          then Edu_Years_CWG = .;
    if not missing(Death_Days_After_Surgery)   and Death_Days_After_Surgery < 0            then Death_Days_After_Surgery = .;

    /* Mortality flags (no death date = alive; see Q-11 on follow-up) */
    Died_Any = (not missing(Death_Days_After_Surgery));
    Died_30d = (0 <= Death_Days_After_Surgery <= 30);
    Died_90d = (0 <= Death_Days_After_Surgery <= 90);
    Died_1yr = (0 <= Death_Days_After_Surgery <= 365);

    label _id                        = 'PRECEDE Study ID'
          rt_AN_START_to_AN_END_mins = 'Anesthesia duration (min)'
          Frailty_Score              = 'Frailty score'
          Edu_Years_CWG              = 'Education (years)'
          ASA__Anesth_Record_        = 'ASA class (anesthesia record)'
          Age_at_Encounter           = 'Age at encounter (years)'
          Sex_c                      = 'Sex'
          Race_c                     = 'Race'
          Death_Days_After_Surgery   = 'Days from surgery to death'
          Died_Any                   = 'Death recorded (any time)'
          Died_30d                   = 'Death within 30 days'
          Died_90d                   = 'Death within 90 days'
          Died_1yr                   = 'Death within 365 days';
run;

/*---- 5. Duplicate IDs ----------------------------------------------------*/
proc sort data=work.fibro_clean out=work.fibro_clean dupout=work.fibro_dups nodupkey;
    by PRECEDE_Study_ID;
run;

/*---- 6. Save ---------------------------------------------------------------*/
data fyp.fibro_clean;
    retain PRECEDE_Study_ID Age_at_Encounter Sex Race Edu_Years_CWG
           ASA__Anesth_Record_ Frailty_Score rt_AN_START_to_AN_END_mins
           Death_Days_After_Surgery Died_Any Died_30d Died_90d Died_1yr;
    set work.fibro_clean;
run;

proc export data=fyp.fibro_clean
            outfile="&dir_exports.\FIBRO_CLEAN.xlsx"
            dbms=xlsx replace;
    sheet="FIBRO_CLEAN";
run;

/*---- 7. QC workbook (KEY first) ------------------------------------------*/
proc sql noprint;
    create table work.qc_flow as
    select 'Rows imported'          as Step length=40, count(*) as N from work.fibro_raw
    union all
    select 'Duplicate IDs removed'  as Step, count(*) as N from work.fibro_dups
    union all
    select 'Rows in fibro_clean'    as Step, count(*) as N from fyp.fibro_clean
    union all
    select 'Deaths within 1 year'   as Step, sum(Died_1yr) as N from fyp.fibro_clean
    union all
    select 'Deaths any time'        as Step, sum(Died_Any) as N from fyp.fibro_clean;
quit;

data work.qc_key;
    length Sheet $20 Description $200;
    infile datalines dlm='|' truncover;
    input Sheet $ Description $;
datalines;
Flow|Row counts from import to the clean file, plus death counts
Contents|Every column in the raw workbook with its imported type
Continuous|N, missing, mean, SD and quantiles of numeric analysis variables
Categorical|Frequencies including missing for Sex, Race, ASA and mortality flags
Duplicates|PRECEDE_Study_ID values that appeared more than once (first row kept)
DeckCheck|Values to compare with the deck: education mean 13.87 SD 3.0; deaths 725 (4.8%)
;
run;

ods excel file="&dir_qc.\01_import_clean_qc.xlsx" options(sheet_interval='proc' embedded_titles='yes');

ods excel options(sheet_name='KEY');
proc print data=work.qc_key noobs; run;

ods excel options(sheet_name='Flow');
proc print data=work.qc_flow noobs; run;

ods excel options(sheet_name='Contents');
proc print data=work.raw_contents noobs; run;

ods excel options(sheet_name='Continuous');
proc means data=fyp.fibro_clean n nmiss mean std min p25 median p75 max maxdec=2;
    var rt_AN_START_to_AN_END_mins Frailty_Score Edu_Years_CWG Age_at_Encounter Death_Days_After_Surgery;
run;

ods excel options(sheet_name='Categorical');
proc freq data=fyp.fibro_clean;
    tables Sex Race ASA__Anesth_Record_ Died_Any Died_30d Died_90d Died_1yr / missing;
run;

ods excel options(sheet_name='Duplicates');
proc print data=work.fibro_dups(obs=500 keep=PRECEDE_Study_ID) noobs; run;

ods excel options(sheet_name='DeckCheck');
title "Compare with slide 5 (education) and slides 6-7 (deaths)";
proc means data=fyp.fibro_clean n mean std min max maxdec=2;
    var Edu_Years_CWG;
run;
proc freq data=fyp.fibro_clean;
    tables Died_1yr Died_Any Died_1yr*Sex / nocol nopercent;
run;
title;

ods excel close;
