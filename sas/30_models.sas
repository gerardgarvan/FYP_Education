%let proj_root = C:\FYP_Education;
%include "&proj_root.\sas\00_config.sas";
/*============================================================================
  Program : 30_models.sas
  Project : FYP - Effect of education on post-op prognosis (PRECEDE II Ops)
  Input   : fyp.fibro_clean  (from 01_import_clean.sas)
  Output  : &dir_tables\FIBRO_FYP_Results.xlsx (KEY first); PNGs in &dir_figures
  Reqs    : DSC-04, MOD-01 .. MOD-05; LIT-01 .. LIT-03 when switched on
  Purpose : Analyses from the (Proposed) Analyses / Next Steps slides
              Table 1  Demographic characteristics by 1-year mortality
              Table 2  Logistic models (OR, 95% CI) + hierarchical LR tests
              Fig 1    Education vs reading level          [when available]
              Fig 2    Functional vs health literacy       [when available]
              Fig 3    Forest plot of odds ratios
  Notes   : Reading level and health literacy are not yet in the data.
            Set HAVE_READ / HAVE_HL = 1 and fill in the file/variable names in
            Section 1 when they arrive; everything downstream switches on.
============================================================================*/

/*---- 1. Settings (edit) ---------------------------------------------------*/
%let HAVE_READ = 0;                       /* 1 when reading level is added    */
%let HAVE_HL   = 0;                       /* 1 when health literacy is added  */
%let lit_file  = &src_literacy.;         /* set in 00_config.sas            */
%let read_var  = Reading_Level;           /* reading level column name        */
%let hl_var    = Health_Lit;              /* health literacy column name      */

/* Covariates common to every model */
%let covs = ASA_cat Frailty_Score Dur_hr Age_10 Sex Race_cat;

/*---- 2. Formats -----------------------------------------------------------*/
proc format;
    value educf 1 = '<12 years'
                2 = '12 years'
                3 = '13-15 years'
                4 = '16 years'
                5 = '>16 years';
    value asaf  1 = 'ASA 1-2'
                2 = 'ASA 3'
                3 = 'ASA 4-5';
    value $plab 'Edu_Years_CWG'  = 'Education (per year)'
                'Edu_cat'        = 'Education'
                'Read_5'         = 'Reading level (per 5 pts)'
                'Edu_c'          = 'Education (per year, centered)'
                'Read_c'         = 'Reading level (per 5 pts, centered)'
                'Edu_c*Read_c'   = 'Education x Reading level'
                'ASA_cat'        = 'ASA'
                'Frailty_Score'  = 'Frailty score (per point)'
                'Dur_hr'         = 'Anesthesia duration (per hour)'
                'Age_10'         = 'Age (per 10 years)'
                'Sex'            = 'Sex'
                'Race_cat'       = 'Race';
run;

/*---- 3. Analysis variables -----------------------------------------------*/
data work.ana_base;
    set fyp.fibro_clean;

    /* Outcome: Died_1yr from cleaning step (death 0-365 d; no death date = alive) */

    /* Education, ordinal */
    if missing(Edu_Years_CWG)     then Edu_cat = .;
    else if Edu_Years_CWG < 12    then Edu_cat = 1;
    else if Edu_Years_CWG = 12    then Edu_cat = 2;
    else if Edu_Years_CWG < 16    then Edu_cat = 3;
    else if Edu_Years_CWG = 16    then Edu_cat = 4;
    else                               Edu_cat = 5;

    /* ASA collapsed; ASA 6 (organ donor) excluded */
    if      ASA__Anesth_Record_ in (1,2) then ASA_cat = 1;
    else if ASA__Anesth_Record_ = 3      then ASA_cat = 2;
    else if ASA__Anesth_Record_ in (4,5) then ASA_cat = 3;
    else                                      ASA_cat = .;

    /* Race collapsed; unknown kept as its own level */
    length Race_cat $16;
    if      missing(Race)                                         then Race_cat = 'Unknown';
    else if index(upcase(Race), 'WHITE')                          then Race_cat = 'White';
    else if index(upcase(Race), 'BLACK') or
            index(upcase(Race), 'AFRICAN')                        then Race_cat = 'Black';
    else                                                               Race_cat = 'Other';

    if Sex = 'Other/Unk' then Sex = '';

    /* Rescaled covariates for interpretable ORs */
    Dur_hr = rt_AN_START_to_AN_END_mins / 60;
    Age_10 = Age_at_Encounter / 10;

    format Edu_cat educf. ASA_cat asaf.;
    label Edu_cat  = 'Education category'
          ASA_cat  = 'ASA class'
          Race_cat = 'Race'
          Dur_hr   = 'Anesthesia duration (hours)'
          Age_10   = 'Age (per 10 years)'
          Died_1yr = 'Died within 1 year of surgery';
run;

/*---- 4. Merge reading level / health literacy (when available) -----------*/
%if &HAVE_READ. = 1 or &HAVE_HL. = 1 %then %do;
    proc import datafile="&lit_file." out=work.lit dbms=xlsx replace;
        getnames=yes;
    run;
    proc sort data=work.lit;      by PRECEDE_Study_ID; run;
    proc sort data=work.ana_base; by PRECEDE_Study_ID; run;
    data work.ana_base;
        merge work.ana_base(in=a) work.lit;
        by PRECEDE_Study_ID;
        if a;
    run;
%end;

%if &HAVE_READ. = 1 %then %do;
    data work.ana_base;
        set work.ana_base;
        Read_5 = &read_var. / 5;
        label Read_5 = 'Reading level (per 5 points)';
    run;
%end;

/*---- 5. Analytic samples (complete case, consistent across nested models) */
data work.ana_edu;
    set work.ana_base;
    if nmiss(Died_1yr, Edu_Years_CWG, ASA_cat, Frailty_Score, Dur_hr, Age_10) = 0
       and not missing(Sex);
run;

%if &HAVE_READ. = 1 %then %do;
    data work.ana_read;
        set work.ana_edu;
        if not missing(Read_5);
    run;
    proc sql noprint;
        select mean(Edu_Years_CWG), mean(Read_5) into :mu_edu, :mu_read
        from work.ana_read;
    quit;
    data work.ana_read;
        set work.ana_read;
        Edu_c  = Edu_Years_CWG - &mu_edu.;
        Read_c = Read_5 - &mu_read.;
    run;
%end;

title "Sample flow";
proc sql;
    select 'Clean file'          as Step, count(*) as N, sum(Died_1yr) as Deaths_1yr from work.ana_base
    union all
    select 'Complete case (edu)' as Step, count(*) as N, sum(Died_1yr) as Deaths_1yr from work.ana_edu
    %if &HAVE_READ. = 1 %then %do;
    union all
    select 'Complete case (edu + reading)' as Step, count(*) as N, sum(Died_1yr) as Deaths_1yr from work.ana_read
    %end;
    ;
quit;
title;

/*---- 6. Table 1 ----------------------------------------------------------*/
proc datasets lib=work nolist; delete t1; quit;

%macro t1_n(data=);
    proc sql noprint;
        select count(*), sum(Died_1yr=0), sum(Died_1yr=1)
        into :n_all trimmed, :n_alive trimmed, :n_died trimmed
        from &data.;
    quit;
    data work._row;
        length Characteristic $80 Level $40 Overall Alive Died $30 P $10;
        Characteristic = 'N'; Level = '';
        Overall = "&n_all."; Alive = "&n_alive."; Died = "&n_died."; P = '';
    run;
    proc append base=work.t1 data=work._row force; run;
%mend t1_n;

%macro t1_cont(data=, var=, label=);
    proc means data=&data. noprint;
        class Died_1yr;
        var &var.;
        output out=work._m mean=mean std=sd;
    run;
    proc npar1way data=&data. wilcoxon noprint;
        class Died_1yr;
        var &var.;
        output out=work._p wilcoxon;
    run;
    data work._row(keep=Characteristic Level Overall Alive Died P);
        length Characteristic $80 Level $40 Overall Alive Died $30 P $10 cell $30;
        retain Overall Alive Died;
        set work._m end=last;
        cell = cats(put(mean, 8.1), ' (', put(sd, 8.1), ')');
        if _type_ = 0          then Overall = cell;
        else if Died_1yr = 0   then Alive   = cell;
        else                        Died    = cell;
        if last then do;
            set work._p(keep=P2_WIL);
            Characteristic = "&label., mean (SD)";
            Level = '';
            if P2_WIL < 0.001 then P = '<0.001'; else P = strip(put(P2_WIL, 6.3));
            output;
        end;
    run;
    proc append base=work.t1 data=work._row force; run;
%mend t1_cont;

%macro t1_cat(data=, var=, label=);
    proc freq data=&data. noprint;
        tables &var.*Died_1yr / chisq outpct out=work._f;
        output out=work._c pchi;
    run;
    proc freq data=&data. noprint;
        tables &var. / out=work._tot;
    run;
    data work._hdr;
        length Characteristic $80 Level $40 Overall Alive Died $30 P $10;
        set work._c(keep=P_PCHI);
        Characteristic = "&label., n (%)";
        Level = ''; Overall = ''; Alive = ''; Died = '';
        if P_PCHI < 0.001 then P = '<0.001'; else P = strip(put(P_PCHI, 6.3));
        drop P_PCHI;
    run;
    proc sort data=work._f;   by &var.; run;
    proc sort data=work._tot; by &var.; run;
    data work._row(keep=Characteristic Level Overall Alive Died P);
        length Characteristic $80 Level $40 Overall Alive Died $30 P $10;
        merge work._f(where=(not missing(&var.)))
              work._tot(where=(not missing(&var.)) rename=(COUNT=TOT PERCENT=TOTPCT));
        by &var.;
        retain Overall Alive Died;
        if first.&var. then call missing(Overall, Alive, Died);
        if Died_1yr = 0 then Alive = cats(COUNT, ' (', put(PCT_COL, 5.1), ')');
        else                 Died  = cats(COUNT, ' (', put(PCT_COL, 5.1), ')');
        if last.&var. then do;
            Overall = cats(TOT, ' (', put(TOTPCT, 5.1), ')');
            Characteristic = '';
            Level = strip(vvalue(&var.));
            P = '';
            output;
        end;
    run;
    proc append base=work.t1 data=work._hdr force; run;
    proc append base=work.t1 data=work._row force; run;
%mend t1_cat;

%t1_n   (data=work.ana_edu);
%t1_cont(data=work.ana_edu, var=Age_at_Encounter,           label=Age (years));
%t1_cat (data=work.ana_edu, var=Sex,                        label=Sex);
%t1_cat (data=work.ana_edu, var=Race_cat,                   label=Race);
%t1_cont(data=work.ana_edu, var=Edu_Years_CWG,              label=Education (years));
%t1_cat (data=work.ana_edu, var=Edu_cat,                    label=Education category);
%if &HAVE_READ. = 1 %then %do;
%t1_cont(data=work.ana_edu, var=&read_var.,                 label=Reading level);
%end;
%if &HAVE_HL. = 1 %then %do;
%t1_cont(data=work.ana_edu, var=&hl_var.,                   label=Health literacy);
%end;
%t1_cat (data=work.ana_edu, var=ASA_cat,                    label=ASA class);
%t1_cont(data=work.ana_edu, var=Frailty_Score,              label=Frailty score);
%t1_cont(data=work.ana_edu, var=rt_AN_START_to_AN_END_mins, label=Anesthesia duration (min));

data work.t1;
    set work.t1;
    label Characteristic = 'Characteristic'
          Level          = 'Level'
          Overall        = 'Overall'
          Alive          = 'Alive at 1 year'
          Died           = 'Died within 1 year'
          P              = 'p-value';
run;

/*---- 7. Spearman correlations (when available) ---------------------------*/
%macro spear(data=, a=, b=, id=);
    proc corr data=&data. spearman noprint outs=work._s;
        var &a. &b.;
    run;
    proc corr data=&data. spearman nosimple;
        var &a. &b.;
        ods output SpearmanCorr=work._sc;
    run;
    data work._sp(keep=Pair Rho P N);
        length Pair $80;
        set work._sc(where=(Variable = "&a."));
        Pair = "&a. vs &b.";
        Rho  = &b.;
        P    = P&b.;
        N    = N&b.;
        call symputx("rho_&id.", put(Rho, 5.2));
        call symputx("p_&id.",   ifc(P < 0.001, '<0.001', put(P, 5.3)));
    run;
    proc append base=work.spearman_all data=work._sp force; run;
%mend spear;

proc datasets lib=work nolist; delete spearman_all; quit;
%if &HAVE_READ. = 1 %then %do;
    %spear(data=work.ana_edu, a=Edu_Years_CWG, b=&read_var., id=f1);
%end;
%if &HAVE_READ. = 1 and &HAVE_HL. = 1 %then %do;
    %spear(data=work.ana_edu, a=&read_var.,    b=&hl_var.,   id=f2);
%end;

/*---- 8. Logistic models --------------------------------------------------*/
proc datasets lib=work nolist; delete or_all fit_all lr_all; quit;

%macro fitlog(id=, label=, data=, x=);
    proc logistic data=&data.;
        class Sex(ref='Female') Race_cat(ref='White') ASA_cat(ref='ASA 1-2')
              Edu_cat(ref='12 years') / param=ref;
        model Died_1yr(event='1') = &x. / clparm=wald;
        ods output ParameterEstimates=work._pe CLparmWald=work._cl
                   FitStatistics=work._fit Association=work._as;
    run;

    proc sql noprint;
        select count(*), sum(Died_1yr) into :n_m trimmed, :ev_m trimmed from &data.;
        select count(*) into :k_m trimmed from work._pe;
    quit;

    data work._or;
        length Model $12 ModelLabel $80 Term $90 ORtxt $30 Ptxt $10;
        merge work._pe(where=(Variable ne 'Intercept'))
              work._cl(where=(Parameter ne 'Intercept') keep=Parameter LowerCL UpperCL);
        Model      = "&id.";
        ModelLabel = "&label.";
        Term       = catx(': ', put(Variable, $plab.), ClassVal0);
        OR   = exp(Estimate);
        OR_L = exp(LowerCL);
        OR_U = exp(UpperCL);
        P    = ProbChiSq;
        ORtxt = cats(put(OR, 8.2), ' (', put(OR_L, 8.2), ', ', put(OR_U, 8.2), ')');
        if P < 0.001 then Ptxt = '<0.001'; else Ptxt = strip(put(P, 6.3));
        keep Model ModelLabel Variable Term OR OR_L OR_U P ORtxt Ptxt;
    run;
    proc append base=work.or_all data=work._or force; run;

    data work._f(keep=Model ModelLabel N Events k m2ll AIC c);
        length Model $12 ModelLabel $80;
        retain m2ll AIC;
        set work._fit end=last;
        if Criterion = '-2 Log L' then m2ll = InterceptAndCovariates;
        if Criterion = 'AIC'      then AIC  = InterceptAndCovariates;
        if last then do;
            set work._as(where=(Label2 = 'c') keep=Label2 nValue2);
            c = nValue2;
            Model = "&id."; ModelLabel = "&label.";
            N = &n_m.; Events = &ev_m.; k = &k_m.;
            output;
        end;
    run;
    proc append base=work.fit_all data=work._f force; run;
%mend fitlog;

%macro lrt(reduced=, full=, label=);
    data work._lr(keep=Comparison LR df P Ptxt);
        length Comparison $90 Ptxt $10;
        set work.fit_all(where=(Model = "&reduced.") keep=Model m2ll k rename=(m2ll=m2ll_r k=k_r));
        set work.fit_all(where=(Model = "&full.")    keep=Model m2ll k);
        Comparison = "&label.";
        LR = m2ll_r - m2ll;
        df = k - k_r;
        P  = sdf('chisq', LR, df);
        if P < 0.001 then Ptxt = '<0.001'; else Ptxt = strip(put(P, 6.3));
    run;
    proc append base=work.lr_all data=work._lr force; run;
%mend lrt;

/* Education models (run now) */
%fitlog(id=M0,  label=Covariates only,                     data=work.ana_edu, x=&covs.);
%fitlog(id=M1,  label=Model 1: Education (continuous),     data=work.ana_edu, x=Edu_Years_CWG &covs.);
%fitlog(id=M1b, label=Model 1b: Education (ordinal),       data=work.ana_edu, x=Edu_cat &covs.);

%lrt(reduced=M0, full=M1,  label=Add education (continuous) to covariates);
%lrt(reduced=M0, full=M1b, label=Add education (ordinal) to covariates);

/* Reading level models (switch on with HAVE_READ = 1) */
%if &HAVE_READ. = 1 %then %do;
    %fitlog(id=M0r, label=Covariates only (reading sample),       data=work.ana_read, x=&covs.);
    %fitlog(id=M1r, label=Model 1: Education (reading sample),    data=work.ana_read, x=Edu_Years_CWG &covs.);
    %fitlog(id=M2,  label=Model 2: Reading level,                 data=work.ana_read, x=Read_5 &covs.);
    %fitlog(id=M3,  label=Model 3: Education + Reading level,     data=work.ana_read, x=Edu_Years_CWG Read_5 &covs.);
    %fitlog(id=M4,  label=Model 4: Education x Reading level,     data=work.ana_read, x=Edu_c Read_c Edu_c*Read_c &covs.);

    %lrt(reduced=M0r, full=M1r, label=Step 1: Add education to covariates);
    %lrt(reduced=M1r, full=M3,  label=Step 2: Add reading level to education);
    %lrt(reduced=M3,  full=M4,  label=Step 3: Add education x reading interaction);
%end;

data work.fit_all;
    set work.fit_all;
    format m2ll AIC 10.1 c 5.3;
    label ModelLabel = 'Model' N = 'N' Events = 'Deaths' k = 'Parameters'
          m2ll = '-2 Log L' AIC = 'AIC' c = 'C-statistic';
run;

data work.lr_all;
    set work.lr_all;
    format LR 8.2;
    label Comparison = 'Comparison' LR = 'LR chi-square' df = 'df' Ptxt = 'p-value';
run;

data work.t2;
    set work.or_all(where=(Model ne 'M0' and Model ne 'M0r'));
    label ModelLabel = 'Model' Term = 'Term' ORtxt = 'OR (95% CI)' Ptxt = 'p-value';
run;

/*---- 9. Output: workbook (KEY first) + figures ---------------------------*/
data work.key;
    length Item $40 Description $200;
    infile datalines dlm='|' truncover;
    input Item $ Description $;
datalines;
Outcome|Died_1yr = death 0-365 days after surgery; no recorded death date treated as alive
Sample|Complete case on outcome, education, ASA, frailty, duration, age, sex
Education (continuous)|Edu_Years_CWG, OR per additional year
Education (ordinal)|<12, 12 (reference), 13-15, 16, >16 years
ASA|Collapsed 1-2 (reference), 3, 4-5; ASA 6 excluded
Race|White (reference), Black, Other, Unknown
Sex|Female (reference)
Anesthesia duration|AN_START to AN_END, OR per hour
Age|OR per 10 years
Reading level|OR per 5 points; Model 4 terms mean-centered (pending data)
Health literacy|Spearman correlation with reading level only (pending data)
Table 1 tests|Continuous: Wilcoxon rank-sum; categorical: chi-square
Hierarchical tests|Likelihood ratio tests between nested models on the same sample
Figures|PNG files saved to the figures folder on P: (Fig1, Fig2, Fig3a, Fig3b)
;
run;

data work.forest_exp;
    set work.or_all;
    where Variable in ('Edu_Years_CWG', 'Edu_cat', 'Read_5', 'Edu_c', 'Read_c', 'Edu_c*Read_c')
          and Model not in ('M0', 'M0r');
    length YLabel $120;
    YLabel = catx(' | ', ModelLabel, Term);
run;

data work.forest_m1;
    set work.or_all(where=(Model = 'M1'));
run;

ods listing gpath="&dir_figures.";
ods excel file="&dir_tables.\FIBRO_FYP_Results.xlsx"
          options(sheet_interval='proc' embedded_titles='yes');

ods excel options(sheet_name='KEY');
title "Key";
proc print data=work.key noobs label; run;

ods excel options(sheet_name='Table1');
title "Table 1. Demographic characteristics by 1-year mortality";
proc print data=work.t1 noobs label; run;

ods excel options(sheet_name='Table2');
title "Table 2. Logistic regression results for 1-year mortality";
proc print data=work.t2 noobs label;
    var ModelLabel Term ORtxt Ptxt;
run;

ods excel options(sheet_name='ModelFit');
title "Model fit";
proc print data=work.fit_all noobs label;
    var ModelLabel N Events k m2ll AIC c;
run;

ods excel options(sheet_name='Hierarchical');
title "Hierarchical (nested model) likelihood ratio tests";
proc print data=work.lr_all noobs label;
    var Comparison LR df Ptxt;
run;

%if &HAVE_READ. = 1 %then %do;
ods excel options(sheet_name='Spearman');
title "Spearman correlations";
proc print data=work.spearman_all noobs; run;
%end;

/* Figure 1: education vs reading level */
%if &HAVE_READ. = 1 %then %do;
ods excel options(sheet_name='Fig1');
ods graphics / reset imagename="Fig1_Edu_vs_Reading" imagefmt=png width=7in height=5in;
title "Figure 1. Years of education vs reading level";
proc sgplot data=work.ana_edu noautolegend;
    scatter x=Edu_Years_CWG y=&read_var. / jitter transparency=0.6
            markerattrs=(symbol=circlefilled color=&uf_blue. size=5);
    loess x=Edu_Years_CWG y=&read_var. / nomarkers lineattrs=(color=&uf_orange. thickness=2);
    inset "Spearman rho = &rho_f1. (p = &p_f1.)" / position=topleft border;
    xaxis label='Years of education';
    yaxis label='Reading level';
run;
%end;

/* Figure 2: functional literacy vs health literacy */
%if &HAVE_READ. = 1 and &HAVE_HL. = 1 %then %do;
ods excel options(sheet_name='Fig2');
ods graphics / reset imagename="Fig2_Reading_vs_HealthLit" imagefmt=png width=7in height=5in;
title "Figure 2. Reading level (functional literacy) vs health literacy";
proc sgplot data=work.ana_edu noautolegend;
    scatter x=&read_var. y=&hl_var. / jitter transparency=0.6
            markerattrs=(symbol=circlefilled color=&uf_blue. size=5);
    loess x=&read_var. y=&hl_var. / nomarkers lineattrs=(color=&uf_orange. thickness=2);
    inset "Spearman rho = &rho_f2. (p = &p_f2.)" / position=topleft border;
    xaxis label='Reading level';
    yaxis label='Health literacy';
run;
%end;

/* Figure 3a: exposure ORs across models */
ods excel options(sheet_name='Fig3a');
ods graphics / reset imagename="Fig3a_Forest_Exposures" imagefmt=png width=9in height=5in;
title "Figure 3a. Odds ratios for 1-year mortality: exposures of interest";
proc sgplot data=work.forest_exp noautolegend;
    refline 1 / axis=x lineattrs=(color=&uf_orange. pattern=dash thickness=1.5);
    scatter y=YLabel x=OR / xerrorlower=OR_L xerrorupper=OR_U
            markerattrs=(symbol=squarefilled color=&uf_blue. size=8)
            errorbarattrs=(color=&uf_blue. thickness=1.5);
    xaxis type=log logbase=10 logstyle=linear label='Odds ratio (95% CI, log scale)';
    yaxis discreteorder=data reverse display=(nolabel);
run;

/* Figure 3b: full Model 1 */
ods excel options(sheet_name='Fig3b');
ods graphics / reset imagename="Fig3b_Forest_Model1" imagefmt=png width=9in height=6in;
title "Figure 3b. Odds ratios for 1-year mortality: Model 1 (all terms)";
proc sgplot data=work.forest_m1 noautolegend;
    refline 1 / axis=x lineattrs=(color=&uf_orange. pattern=dash thickness=1.5);
    scatter y=Term x=OR / xerrorlower=OR_L xerrorupper=OR_U
            markerattrs=(symbol=squarefilled color=&uf_blue. size=8)
            errorbarattrs=(color=&uf_blue. thickness=1.5);
    xaxis type=log logbase=10 logstyle=linear label='Odds ratio (95% CI, log scale)';
    yaxis discreteorder=data reverse display=(nolabel);
run;

title;
ods excel close;

/* Permanent copies */
data fyp.fyp_table1;  set work.t1;      run;
data fyp.fyp_table2;  set work.t2;      run;
data fyp.fyp_fit;     set work.fit_all; run;
data fyp.fyp_lrtests; set work.lr_all;  run;
