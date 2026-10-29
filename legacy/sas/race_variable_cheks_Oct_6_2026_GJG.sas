/*==================================================================*
 * Compare race2, race3, race_sa, race_sa2 in WORK.TWO
 *==================================================================*/

/* 1. Variable attributes: type, length, format, label */
proc contents data=work.two (keep=race2 race3 race_sa race_sa2) varnum;
  title "1. Attributes of the four race variables";
run;

/* 2. One-way frequencies, including missing */
proc freq data=work.two;
  tables race2 race3 race_sa race_sa2 / missing;
  title "2. Distribution of each race variable";
run;

/* 3. Pairwise crosstabs in list form: shows how values map */
%macro xtab(a, b);
  proc freq data=work.two;
    tables &a*&b / list missing nocum;
    title "3. Value mapping: &a by &b";
  run;
%mend xtab;

%xtab(race2,   race3);
%xtab(race2,   race_sa);
%xtab(race2,   race_sa2);
%xtab(race3,   race_sa);
%xtab(race3,   race_sa2);
%xtab(race_sa, race_sa2);

/* 4. Exact agreement checks for each pair
      raw = stored values match; fmt = displayed (formatted) values match */
data race_cmp;
  set work.two (keep=race2 race3 race_sa race_sa2);
  length r_race2 r_race3 r_race_sa r_race_sa2
         f_race2 f_race3 f_race_sa f_race_sa2 $100;

  r_race2    = strip(cats(race2));
  r_race3    = strip(cats(race3));
  r_race_sa  = strip(cats(race_sa));
  r_race_sa2 = strip(cats(race_sa2));

  f_race2    = strip(vvalue(race2));
  f_race3    = strip(vvalue(race3));
  f_race_sa  = strip(vvalue(race_sa));
  f_race_sa2 = strip(vvalue(race_sa2));

  raw_2_3     = (r_race2   = r_race3);
  raw_2_sa    = (r_race2   = r_race_sa);
  raw_2_sa2   = (r_race2   = r_race_sa2);
  raw_3_sa    = (r_race3   = r_race_sa);
  raw_3_sa2   = (r_race3   = r_race_sa2);
  raw_sa_sa2  = (r_race_sa = r_race_sa2);

  fmt_2_3     = (upcase(f_race2)   = upcase(f_race3));
  fmt_2_sa    = (upcase(f_race2)   = upcase(f_race_sa));
  fmt_2_sa2   = (upcase(f_race2)   = upcase(f_race_sa2));
  fmt_3_sa    = (upcase(f_race3)   = upcase(f_race_sa));
  fmt_3_sa2   = (upcase(f_race3)   = upcase(f_race_sa2));
  fmt_sa_sa2  = (upcase(f_race_sa) = upcase(f_race_sa2));
run;

proc means data=race_cmp n mean sum maxdec=4;
  var raw_2_3 raw_2_sa raw_2_sa2 raw_3_sa raw_3_sa2 raw_sa_sa2
      fmt_2_3 fmt_2_sa fmt_2_sa2 fmt_3_sa fmt_3_sa2 fmt_sa_sa2;
  title "4. Proportion of records where each pair matches (1.0000 = identical)";
run;

/* 5. Example disagreements for any pair that is not identical */
%macro mismatch(a, b, flag);
  proc print data=race_cmp (where=(&flag = 0) obs=20) noobs;
    var &a &b;
    title "5. First 20 disagreements: &a vs &b (formatted values)";
  run;
%mend mismatch;

%mismatch(f_race2,   f_race3,    fmt_2_3);
%mismatch(f_race2,   f_race_sa,  fmt_2_sa);
%mismatch(f_race2,   f_race_sa2, fmt_2_sa2);
%mismatch(f_race3,   f_race_sa,  fmt_3_sa);
%mismatch(f_race3,   f_race_sa2, fmt_3_sa2);
%mismatch(f_race_sa, f_race_sa2, fmt_sa_sa2);

title;
