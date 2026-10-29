/*============================================================================
  Program : 00_config.sas
  Purpose : The only place paths, libraries and global options are defined.
            Every pipeline program starts with:
              %let proj_root = C:\FYP_Education;
              %include "&proj_root.\sas\00_config.sas";
  Layout  : Programs  -> &proj_root (work PC local drive, git repo)
            Inputs    -> &share
            Outputs   -> &out_root (= &share\FYP_Education)
============================================================================*/

options validvarname=v7 nofmterr mprint msglevel=i dlcreatedir;

/*---- Share (inputs) -------------------------------------------------------*/
%let share           = P:\PeCAN Research\06 Individual Folders\Mackenzie Topper;
%let src_fibro       = &share.\FIBRO_MASTER_APRIL_20_2026_4_MT.xlsx;      /* Q-01 */
%let src_fibro_sheet = ;                                                  /* blank = first sheet */
%let src_clarity_dir = &share.\Patent Education Indicator;                /* Q-02 */
%let src_literacy    = &share.\LITERACY_VARS.xlsx;                        /* v2, not delivered */

/*---- Outputs ---------------------------------------------------------------*/
%let out_root    = &share.\FYP_Education;
%let dir_sasdata = &out_root.\sasdata;
%let dir_exports = &out_root.\exports;
%let dir_tables  = &out_root.\tables;
%let dir_figures = &out_root.\figures;
%let dir_qc      = &out_root.\qc;
%let dir_logs    = &out_root.\logs;

/* Create folders if missing (DLCREATEDIR creates one level per LIBNAME) */
%macro fyp_mkdirs;
    %local d i;
    %let d = &out_root.|&dir_sasdata.|&dir_exports.|&dir_tables.|&dir_figures.|&dir_qc.|&dir_logs.;
    %do i = 1 %to 7;
        libname _mk "%scan(&d., &i., |)";
        libname _mk clear;
    %end;
%mend fyp_mkdirs;
%fyp_mkdirs;

libname fyp "&dir_sasdata.";

/*---- Run stamp and UF colors ----------------------------------------------*/
%let run_date  = %sysfunc(today(), yymmddn8.);
%let run_stamp = &run_date._%sysfunc(compress(%sysfunc(time(), tod8.), :));
%let uf_blue   = CX0021A5;
%let uf_orange = CXFA4616;

/*---- Guard: stop early with a clear message if the share is unreachable ----*/
%macro fyp_check_inputs;
    %if not %sysfunc(fileexist(&share.)) %then
        %put ERROR: [FYP] Share not reachable: &share.;
    %if not %sysfunc(fileexist(&src_fibro.)) %then
        %put WARNING: [FYP] FIBRO master not found: &src_fibro. (see docs/OPEN_QUESTIONS.md Q-01);
%mend fyp_check_inputs;
%fyp_check_inputs;

%put NOTE: [FYP] config loaded. proj_root=&proj_root. out_root=&out_root.;
