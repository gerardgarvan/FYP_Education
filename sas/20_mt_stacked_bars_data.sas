%let proj_root = C:\FYP_Education;
%include "&proj_root.\sas\00_config.sas";
/*============================================================================
  Program : 20_mt_stacked_bars_data.sas
  Purpose : Rebuild MT_educ_stacked_bars.csv from fyp.fibro_clean
            (input for R/21_plot_mt_stacked_bars.R)
  Reqs    : DSC-03   (cut points: docs/OPEN_QUESTIONS.md Q-07)
  Output  : &dir_exports\MT_educ_stacked_bars.csv
            columns: variable, educ_group, category, row_pct, highlighted
            one highlighted row + its complement per education group,
            so each bar stacks to 100%
  Notes   : The original groupings came from create_data_MT_Sept_30_2026_GJG.sas
            (PeCAN data). The cut points in Section 1 are settings - check them
            against that program before using the output.
============================================================================*/

/*---- 1. Settings (edit) ---------------------------------------------------*/
/* MT_EDUC_GROUP: upper bound (years) of groups 1-6; group 7 is everything above */
%let e1 = 8;    /* 1:  0-8   */
%let e2 = 11;   /* 2:  9-11  */
%let e3 = 12;   /* 3:  12    */
%let e4 = 15;   /* 4:  13-15 */
%let e5 = 16;   /* 5:  16    */
%let e6 = 18;   /* 6:  17-18 */
                /* 7:  19+   */

/* MT_ASA: 2 = ASA >= asa_cut, 1 = below */
%let asa_cut = 2;

/* MT_Frailty_Score: 2 (frail) = Frailty_Score >= frail_cut, 1 = below */
%let frail_cut = 3;

/*---- 2. Derive MT_ variables ---------------------------------------------*/
data work.mt;
    set fyp.fibro_clean;

    if missing(Edu_Years_CWG)          then MT_EDUC_GROUP = .;
    else if Edu_Years_CWG <= &e1.      then MT_EDUC_GROUP = 1;
    else if Edu_Years_CWG <= &e2.      then MT_EDUC_GROUP = 2;
    else if Edu_Years_CWG <= &e3.      then MT_EDUC_GROUP = 3;
    else if Edu_Years_CWG <= &e4.      then MT_EDUC_GROUP = 4;
    else if Edu_Years_CWG <= &e5.      then MT_EDUC_GROUP = 5;
    else if Edu_Years_CWG <= &e6.      then MT_EDUC_GROUP = 6;
    else                                    MT_EDUC_GROUP = 7;

    length MT_ASA MT_Frailty_Score $1 Mortality_1Y $3;

    if ASA__Anesth_Record_ in (1,2,3,4,5) then
        MT_ASA = ifc(ASA__Anesth_Record_ >= &asa_cut., '2', '1');

    if not missing(Frailty_Score) then
        MT_Frailty_Score = ifc(Frailty_Score >= &frail_cut., '2', '1');

    Mortality_1Y = ifc(Died_1yr = 1, 'Yes', 'No');

    if missing(MT_EDUC_GROUP) then delete;
run;

/* QC: check the groupings before trusting the CSV */
title "QC: MT_EDUC_GROUP by years of education";
proc means data=work.mt n min max maxdec=0;
    class MT_EDUC_GROUP;
    var Edu_Years_CWG;
run;

title "QC: source distributions for the ASA and frailty cut points";
proc freq data=work.mt;
    tables ASA__Anesth_Record_ Frailty_Score MT_ASA MT_Frailty_Score Mortality_1Y / missing;
run;
title;

/*---- 3. Row percents per variable ----------------------------------------*/
proc datasets lib=work nolist; delete bars; quit;

%macro rowpct(var=, hi=, ref=);
    proc freq data=work.mt noprint;
        where not missing(&var.);
        tables MT_EDUC_GROUP*&var. / outpct out=work._f(keep=MT_EDUC_GROUP &var. PCT_ROW);
    run;

    data work._b(keep=variable educ_group category row_pct highlighted);
        length variable $20 category $3 highlighted $5;
        set work._f;
        variable    = "&var.";
        educ_group  = MT_EDUC_GROUP;
        category    = strip(&var.);
        row_pct     = round(PCT_ROW, 0.01);
        highlighted = ifc(category = "&hi.", 'TRUE', 'FALSE');
        /* highlighted level first within each group, as in the original CSV */
        _ord = (category = "&ref.");
    run;

    /* Make sure both levels exist in every group (0% if absent) */
    data work._grid;
        length variable $20 category $3 highlighted $5;
        do educ_group = 1 to 7;
            variable = "&var."; category = "&hi.";  highlighted = 'TRUE';  row_pct = 0; output;
            variable = "&var."; category = "&ref."; highlighted = 'FALSE'; row_pct = 0; output;
        end;
    run;
    proc sort data=work._grid; by educ_group category; run;
    proc sort data=work._b;    by educ_group category; run;
    data work._b;
        merge work._grid work._b;
        by educ_group category;
        _ord = (highlighted = 'FALSE');
    run;
    proc sort data=work._b out=work._b(drop=_ord); by educ_group _ord; run;

    proc append base=work.bars data=work._b force; run;
%mend rowpct;

%rowpct(var=MT_ASA,           hi=2,   ref=1);
%rowpct(var=MT_Frailty_Score, hi=2,   ref=1);
%rowpct(var=Mortality_1Y,     hi=Yes, ref=No);

/*---- 4. Export -----------------------------------------------------------*/
data work.bars;
    retain variable educ_group category row_pct highlighted;
    set work.bars;
    format row_pct 8.2;
run;

title "MT_educ_stacked_bars (highlighted rows)";
proc print data=work.bars noobs;
    where highlighted = 'TRUE';
run;
title;

proc export data=work.bars
            outfile="&dir_exports.\MT_educ_stacked_bars.csv"
            dbms=csv replace;
    putnames=yes;
run;
