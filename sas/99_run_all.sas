%let proj_root = C:\FYP_Education;
%include "&proj_root.\sas\00_config.sas";
/*============================================================================
  Program : 99_run_all.sas
  Purpose : Run the pipeline in order; one dated log per run in &dir_logs.
  Reqs    : RUN-01
  Usage   : Submit in SAS, or run run_pipeline.cmd from the repo root.
============================================================================*/

%let RUN_CLARITY = 1;   /* 10_clarity_profile.sas - discovery, can be slow */

proc printto log="&dir_logs.\run_all_&run_stamp..log" new; run;

%put NOTE: [FYP] run_all started &run_stamp.;

%include "&proj_root.\sas\01_import_clean.sas";

%macro run_optional;
    %if &RUN_CLARITY. = 1 %then %do;
        %include "&proj_root.\sas\10_clarity_profile.sas";
    %end;
%mend run_optional;
%run_optional;

%include "&proj_root.\sas\20_mt_stacked_bars_data.sas";
%include "&proj_root.\sas\30_models.sas";

%put NOTE: [FYP] run_all finished %sysfunc(datetime(), datetime20.);

proc printto; run;

/* Echo an error count to the session log */
data _null_;
    infile "&dir_logs.\run_all_&run_stamp..log" end=eof;
    input;
    if _infile_ =: 'ERROR' then n_err + 1;
    if _infile_ =: 'WARNING' then n_warn + 1;
    if eof then put "NOTE: [FYP] Log &dir_logs.\run_all_&run_stamp..log: " n_err= n_warn=;
run;
