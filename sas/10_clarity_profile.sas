%let proj_root = C:\FYP_Education;
%include "&proj_root.\sas\00_config.sas";
/*============================================================================
  Program : 10_clarity_profile.sas
  Purpose : Discovery pass over the "Patent Education Indicator" folder, which
            holds claritysqlprod.clarity.dbo.CLARITY_CONCEPT (format unknown).
            Lists every file, imports each readable table, profiles it, and
            pulls rows that mention education / literacy / teaching terms.
  Reads   : &src_clarity_dir\*  (xlsx, xls, csv, txt, sas7bdat)
  Writes  : &dir_qc\10_clarity_profile.xlsx  (KEY first)
            fyp.clr_f<n> copies of each imported table
  Reqs    : CLR-01 .. CLR-03  (CLR-04/05 are written up from this output)
  Notes   : Uses DOPEN/DREAD, so it works with XCMD disabled.
============================================================================*/

/* Terms that suggest educational attainment, literacy, or patient teaching (Q-04) */
%let kw = EDUC|SCHOOL|GRADE|DEGREE|DIPLOMA|\bGED\b|COLLEGE|UNIVERS|LITERA|READ|LEARN|TEACH|INSTRUCT;
%let max_hits = 5000;

/*---- 1. List the folder ----------------------------------------------------*/
data work.clr_files;
    length file_id 8 fname $260 ext $12 kind $12 fullpath $600;
    rc  = filename('_cdir', "&src_clarity_dir.");
    did = dopen('_cdir');
    if did = 0 then do;
        put "ERROR: [FYP] Cannot open folder &src_clarity_dir. (spelling? see Q-02)";
        stop;
    end;
    do i = 1 to dnum(did);
        fname    = dread(did, i);
        fullpath = catx('\', "&src_clarity_dir.", fname);
        ext      = lowcase(scan(fname, -1, '.'));
        if index(fname, '.') = 0 then ext = '';
        select (ext);
            when ('xlsx', 'xlsm', 'xls')      kind = 'excel';
            when ('csv', 'txt')               kind = 'delimited';
            when ('sas7bdat')                 kind = 'sasdata';
            when ('sql')                      kind = 'sql';
            when ('')                         kind = 'folder?';
            otherwise                         kind = 'other';
        end;
        file_id + 1;
        output;
    end;
    rc = dclose(did);
    rc = filename('_cdir');
    keep file_id fname ext kind fullpath;
run;

/* SQL files: keep their text, it explains how the extract was pulled */
data work.clr_sql;
    length file_id 8 fname $260 line_no 8 text $1000;
    set work.clr_files(where=(kind = 'sql'));
    fv = fullpath;
    infile dummy filevar=fv end=eof lrecl=1000 truncover;
    line_no = 0;
    do while (not eof);
        input text $char1000.;
        line_no + 1;
        output;
    end;
    keep file_id fname line_no text;
run;

/*---- 2. Profile each readable table ---------------------------------------*/
proc datasets lib=work nolist; delete clr_contents clr_nobs; quit;

%let clr_n = 0;
data _null_;
    set work.clr_files(where=(kind in ('excel', 'delimited', 'sasdata'))) end=last;
    n + 1;
    call symputx(cats('clr_id',   n), file_id,  'G');
    call symputx(cats('clr_path', n), fullpath, 'G');
    call symputx(cats('clr_kind', n), kind,     'G');
    call symputx(cats('clr_ext',  n), ext,      'G');
    if last then call symputx('clr_n', n, 'G');
run;

%macro clr_profile;
    %local k id path kind ext nobs dbms;
    %do k = 1 %to &clr_n.;
        %let id   = &&clr_id&k.;
        %let path = %superq(clr_path&k.);
        %let kind = &&clr_kind&k.;
        %let ext  = &&clr_ext&k.;

        %if &kind. = sasdata %then %do;
            data fyp.clr_f&id.; set "&path."; run;
        %end;
        %else %if &kind. = delimited %then %do;
            %if &ext. = txt %then %let dbms = tab; %else %let dbms = csv;
            proc import datafile="&path." out=fyp.clr_f&id. dbms=&dbms. replace;
                getnames=yes; guessingrows=32767;
            run;
        %end;
        %else %do;
            %if &ext. = xls %then %let dbms = xls; %else %let dbms = xlsx;
            proc import datafile="&path." out=fyp.clr_f&id. dbms=&dbms. replace;
                getnames=yes;
            run;
        %end;

        %if %sysfunc(exist(fyp.clr_f&id.)) %then %do;
            proc contents data=fyp.clr_f&id. noprint
                          out=work._c(keep=name type length format label varnum);
            run;
            data work._c; file_id = &id.; set work._c; run;
            proc append base=work.clr_contents data=work._c force; run;

            proc sql noprint;
                select count(*) into :nobs trimmed from fyp.clr_f&id.;
            quit;
            data work._n; file_id = &id.; nobs = &nobs.; run;
            proc append base=work.clr_nobs data=work._n force; run;

            /* Keyword hits across all character columns */
            data work.clr_hits&id.(drop=_text _nhit);
                set fyp.clr_f&id.;
                length _text $32767;
                _text = catx(' | ', of _character_);
                if prxmatch("/&kw./i", _text) then do;
                    _nhit + 1;
                    if _nhit <= &max_hits. then output;
                end;
            run;
        %end;
        %else %put WARNING: [FYP] Could not read file_id=&id.: &path.;
    %end;
%mend clr_profile;
%clr_profile;

/* File-level summary */
proc sql;
    create table work.clr_summary as
    select f.file_id, f.fname, f.kind, n.nobs,
           (select count(*) from work.clr_contents c where c.file_id = f.file_id) as ncols
    from work.clr_files f
         left join work.clr_nobs n on f.file_id = n.file_id
    order by f.file_id;
quit;

/*---- 3. Workbook -----------------------------------------------------------*/
data work.clr_key;
    length Sheet $24 Description $250;
    infile datalines dlm='|' truncover;
    input Sheet $ Description $;
datalines;
Files|Every item in the folder with its type, row and column counts (blank rows = not a readable table)
Contents|Columns of each readable table (file_id links to Files)
SQL|Text of any .sql files - how the extract was pulled
F<n>_first20|First 20 rows of table n
F<n>_hits|Rows with education, school, grade, degree, literacy, reading, learning or teaching terms (max 5000)
Next|Use this to answer Q-03 to Q-06 in docs/OPEN_QUESTIONS.md and write the CLARITY_CONCEPT section of docs/DATA_SOURCES.md
;
run;

ods excel file="&dir_qc.\10_clarity_profile.xlsx" options(sheet_interval='proc' embedded_titles='yes');

ods excel options(sheet_name='KEY');
proc print data=work.clr_key noobs; run;

ods excel options(sheet_name='Files');
proc print data=work.clr_summary noobs; run;

ods excel options(sheet_name='Contents');
proc print data=work.clr_contents noobs; run;

%macro clr_sheets;
    %local k id nsql;
    proc sql noprint; select count(*) into :nsql trimmed from work.clr_sql; quit;
    %if &nsql. > 0 %then %do;
        ods excel options(sheet_name='SQL');
        proc print data=work.clr_sql noobs; run;
    %end;
    %do k = 1 %to &clr_n.;
        %let id = &&clr_id&k.;
        %if %sysfunc(exist(fyp.clr_f&id.)) %then %do;
            ods excel options(sheet_name="F&id._first20");
            proc print data=fyp.clr_f&id.(obs=20) noobs; run;
            ods excel options(sheet_name="F&id._hits");
            proc print data=work.clr_hits&id. noobs; run;
        %end;
    %end;
%mend clr_sheets;
%clr_sheets;

ods excel close;
