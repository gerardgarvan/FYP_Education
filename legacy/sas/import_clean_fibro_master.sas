/*============================================================================
  Program : import_clean_fibro_master.sas
  Purpose : Import FIBRO_MASTER_APRIL_20_2026_4_MT.xlsx, keep analysis
            variables, coerce types, standardize categories, and QC.
  Output  : WORK.FIBRO_CLEAN  (+ optional permanent copy in OUT library)
============================================================================*/

options validvarname=v7 nofmterr mprint;

/*---- 1. Paths (edit) ------------------------------------------------------*/
%let inpath  = P:/PeCAN Research/06 Individual Folders/Mackenzie Topper;     /* folder holding the xlsx */
%let infile  = FIBRO_MASTER_APRIL_20_2026_4_MT.xlsx;
%let outpath =  P:/PeCAN Research/06 Individual Folders/Mackenzie Topper;

libname out "&outpath.";

/*---- 2. Import ------------------------------------------------------------*/
proc import datafile="&inpath./&infile."
            out=work.fibro_raw
            dbms=xlsx
            replace;
    getnames=yes;
    /* sheet="Sheet1"; */   /* uncomment and set if the data are not on the first sheet */
run;

/* Confirm imported names/types before keeping */
proc contents data=work.fibro_raw varnum; run;

/*---- 3. Keep target variables --------------------------------------------*/
%let keepvars = PRECEDE_Study_ID
                rt_AN_START_to_AN_END_mins
                Frailty_Score
                Edu_Years_CWG
                ASA__Anesth_Record_
                Age_at_Encounter
                Sex
                Race
                Death_Days_After_Surgery;

data work.fibro_keep;
    set work.fibro_raw(keep=&keepvars.);
run;

/*---- 4. Coerce numerics (handles columns imported as character) ----------*/
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
            else &var. = input(compress(_tmp, ', '), ?? best32.);
            if missing(&var.) and _tmp not in ('', '.', 'NA', 'N/A', 'NULL', 'UNKNOWN', 'MISSING')
                then put "WARNING: non-numeric value in &var.: " PRECEDE_Study_ID= _&var._c=;
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

/*---- 5. Clean / standardize ----------------------------------------------*/
data work.fibro_clean;
    retain PRECEDE_Study_ID Age_at_Encounter Sex Race Edu_Years_CWG
           ASA__Anesth_Record_ Frailty_Score rt_AN_START_to_AN_END_mins
           Death_Days_After_Surgery;
    set work.fibro_keep;

    /* ID: strip whitespace; drop fully blank rows */
    PRECEDE_Study_ID = strip(vvalue(PRECEDE_Study_ID));
    if missing(PRECEDE_Study_ID) then delete;

    /* Sex: standardize text */
    length Sex_c $10;
    select (upcase(strip(Sex)));
        when ('F', 'FEMALE') Sex_c = 'Female';
        when ('M', 'MALE')   Sex_c = 'Male';
        when ('')            Sex_c = '';
        otherwise            Sex_c = 'Other/Unk';
    end;

    /* Race: trim and proper-case; blank/unknown -> missing */
    length Race_c $60;
    Race_c = propcase(strip(compbl(Race)));
    if upcase(Race_c) in ('UNKNOWN', 'NA', 'N/A', 'NULL', 'MISSING', 'DECLINED', 'PATIENT REFUSED')
        then Race_c = '';

    drop Sex Race;
    rename Sex_c = Sex  Race_c = Race;

    /* Range checks: implausible values set to missing (adjust bounds as needed) */
    if not missing(Age_at_Encounter)           and not (18 <= Age_at_Encounter <= 110)   then Age_at_Encounter = .;
    if not missing(ASA__Anesth_Record_)        and ASA__Anesth_Record_ not in (1,2,3,4,5,6) then ASA__Anesth_Record_ = .;
    if not missing(rt_AN_START_to_AN_END_mins) and rt_AN_START_to_AN_END_mins <= 0       then rt_AN_START_to_AN_END_mins = .;
    if not missing(Edu_Years_CWG)              and not (0 <= Edu_Years_CWG <= 30)        then Edu_Years_CWG = .;
    if not missing(Death_Days_After_Surgery)   and Death_Days_After_Surgery < 0          then Death_Days_After_Surgery = .;

    /* Derived mortality flags */
    Died_Any  = (not missing(Death_Days_After_Surgery));
    Died_30d  = (0 <= Death_Days_After_Surgery <= 30);
    Died_90d  = (0 <= Death_Days_After_Surgery <= 90);
    Died_1yr  = (0 <= Death_Days_After_Surgery <= 365);

    label PRECEDE_Study_ID            = 'PRECEDE Study ID'
          rt_AN_START_to_AN_END_mins  = 'Anesthesia duration (min)'
          Frailty_Score               = 'Frailty score'
          Edu_Years_CWG               = 'Education (years)'
          ASA__Anesth_Record_         = 'ASA class (anesthesia record)'
          Age_at_Encounter            = 'Age at encounter (years)'
          Sex                         = 'Sex'
          Race                        = 'Race'
          Death_Days_After_Surgery    = 'Days from surgery to death'
          Died_Any                    = 'Death recorded (any time)'
          Died_30d                    = 'Death within 30 days'
          Died_90d                    = 'Death within 90 days'
          Died_1yr                    = 'Death within 365 days';
run;

/*---- 6. Duplicate IDs ----------------------------------------------------*/
proc sort data=work.fibro_clean out=work.fibro_clean dupout=work.fibro_dups nodupkey;
    by PRECEDE_Study_ID;
run;

title "Duplicate PRECEDE_Study_ID rows removed (first kept)";
proc print data=work.fibro_dups(obs=50); var PRECEDE_Study_ID; run;

/*---- 7. QC ---------------------------------------------------------------*/
title "Continuous variables";
proc means data=work.fibro_clean n nmiss mean std min p25 median p75 max maxdec=2;
    var rt_AN_START_to_AN_END_mins Frailty_Score Edu_Years_CWG
        Age_at_Encounter Death_Days_After_Surgery;
run;

title "Categorical variables";
proc freq data=work.fibro_clean;
    tables Sex Race ASA__Anesth_Record_ Died_Any Died_30d Died_90d Died_1yr / missing;
run;
title;

/*---- 8. Save -------------------------------------------------------------*/
data out.fibro_clean;
    set work.fibro_clean;
run;

proc export data=work.fibro_clean
            outfile="&outpath./FIBRO_CLEAN.xlsx"
            dbms=xlsx replace;
    sheet="FIBRO_CLEAN";
run;
