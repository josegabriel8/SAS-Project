/* -------------------------------------------------------------------------
   Adapted from Code/Project.sas (josegabriel8/SAS-Project) for a self-contained
   Jenner run. The ONLY change from the upstream script is the data source: the
   original %import macro read three external Excel workbooks
   (data/Visit1.xls .. Visit3.xls) via PROC IMPORT DBMS=XLS. Those files are not
   self-contained, so this bundle builds the three raw per-visit datasets inline
   with a small, realistic sample (values drawn from data/Visit1.xls), preserving
   the exact column shape the original RENAME/MDY step expects. Every downstream
   step below -- the RENAME + MDY visit build, the ARRAY stacking, VAS_CAT, the
   MERGE, and all of the ODS reports (PRINT, MEANS, TTEST, PROC SQL joins) -- is
   the author's code, unchanged. ODS RTF paths are relative.
   ------------------------------------------------------------------------- */

/* --- Inline sample standing in for PROC IMPORT of Visit1..Visit3.xls --- */
/* Raw visit 1: idpatient v1dt_dd v1dt_mm v1dt_yy SBP1 DBP1 HR1 v1PAIN birthdt_dd birthdt_mm birthdt_yy */
DATA raw_visit1;
	INFILE DATALINES;
	INPUT IDPATIENT v1dt_dd v1dt_mm v1dt_yy SBP1 DBP1 HR1 v1PAIN
		  birthdt_dd birthdt_mm birthdt_yy;
	DATALINES;
2 31 3 2015 110 70 70 70 21 6 1971
3 31 3 2015 145 80 80 60 6 4 1964
4 3 4 2015 110 70 88 80 6 11 1976
5 9 4 2015 120 80 60 87 7 9 1968
6 14 4 2015 120 60 70 62 24 7 1969
7 22 4 2015 120 80 70 75 4 2 1971
8 22 4 2015 110 90 80 67 26 8 1971
9 22 4 2015 110 80 86 66 23 6 1965
10 28 4 2015 130 80 60 90 13 10 1974
11 30 4 2015 120 80 64 51 7 9 1958
12 5 5 2015 125 80 70 60 21 4 1968
13 5 5 2015 130 85 80 70 1 7 1970
;
RUN;

/* Raw visit 2: idpatient v2dt_dd v2dt_mm v2dt_yy SBP2 DBP2 HR2 v2PAIN */
DATA raw_visit2;
	INFILE DATALINES;
	INPUT IDPATIENT v2dt_dd v2dt_mm v2dt_yy SBP2 DBP2 HR2 v2PAIN;
	DATALINES;
2 4 4 2015 105 68 73 62
3 4 4 2015 140 78 83 52
4 4 5 2015 105 68 91 72
5 10 5 2015 115 78 63 79
7 23 5 2015 115 78 73 67
8 23 5 2015 105 88 83 59
9 23 5 2015 105 78 89 58
10 1 5 2015 125 78 63 82
12 6 6 2015 120 78 73 52
13 6 6 2015 125 83 83 62
;
RUN;

/* Raw visit 3: idpatient v3dt_dd v3dt_mm v3dt_yy SBP3 DBP3 HR3 v3PAIN */
DATA raw_visit3;
	INFILE DATALINES;
	INPUT IDPATIENT v3dt_dd v3dt_mm v3dt_yy SBP3 DBP3 HR3 v3PAIN;
	DATALINES;
2 6 4 2015 100 66 76 55
3 6 4 2015 135 76 86 45
8 25 5 2015 100 86 86 52
9 25 5 2015 100 76 92 51
10 3 5 2015 120 76 66 75
12 8 6 2015 115 76 76 45
13 8 6 2015 120 81 86 55
;
RUN;

/* --- Author's per-visit RENAME + MDY build, unchanged (fed by raw_visit&number) --- */
%MACRO import;
	%DO number = 1 %TO 3;
		DATA visit&number;
			SET raw_visit&number(RENAME=(DBP&number=DBP SBP&number=SBP
											HR&number=HR v&number.PAIN=VAS)
									);
			VISITDT = MDY(v&number.dt_mm
						, v&number.dt_dd
						, v&number.dt_yy);
			IF &number = 1 THEN BRTHDT = MDY(birthdt_mm, birthdt_dd, birthdt_yy);
		RUN;
	%END;
%MEND import;

%import;
RUN;

DATA PatientsAll;
	SET visit1(IN=in1)
		visit2(IN=in2)
		visit3(IN=in3);
	ARRAY visits [3] in1-in3;
	DO number = 1 TO 3;
		IF visits[number] THEN VISIT=number;
	END;
	VisitC=CAT("Visit ", Visit);
	IF VAS < 50 THEN VAS_CAT = "L";
	ELSE VAS_CAT = "H";
	KEEP IDPATIENT VISIT VISITC DBP SBP HR VAS VISITDT VAS_CAT;
	LABEL IDPATIENT = "Patient ID"
		  DBP = "Patient ID"
		  SBP = "Patient ID"
		  HR = "Heart rate (beats/min)"
		  VAS = "VAS PAIN (mm):"
		  VISITDT = "Date* (dd/mm/yyyy)"
		  VAS_CAT = "VAS PAIN (mm): Category";
RUN;

DATA Mapping;
	SET visit1(KEEP=IDPATIENT BRTHDT);
RUN;

PROC SORT DATA=Mapping;
	BY IDPatient;
RUN;

PROC SORT DATA=PatientsAll;
	BY IDPatient;
RUN;

DATA PatientsAll;
	MERGE PatientsAll Mapping;
	BY IDPatient;
	FORMAT VISITDT BRTHDT DATE9.;
RUN;

ODS RTF FILE="./final_patients.rtf";

PROC PRINT DATA=PatientsAll;
	TITLE "Final Dataset";
RUN;

ODS RTF CLOSE;

/* Create Reports  */
ODS RTF file="./final_report.rtf";

TITLE;
PROC MEANS DATA=PatientsAll MEAN MEDIAN STD MIN MAX NONOBS;
	CLASS visit;
	title "Main statistics of each parameter by visit";
RUN;

TITLE;
PROC MEANS DATA=PatientsAll MEAN MEDIAN STD MIN MAX NONOBS;
	CLASS visit;
	WHERE VAS_CAT = "L";
	title "Main statistics of each parameter by visit, with VAS_CAT equal “L”";
RUN;

/* T statistic */
proc ttest data=PatientsAll H0=0;
var VAS ;
title "Test statistic: mean VAS differs significantly from 0";
run;



/* Original report */
PROC SQL;
	CREATE TABLE report_intersection AS
	SELECT v1.idpatient
	FROM visit1 v1
	INNER JOIN visit2 v2
		ON v1.idpatient=v2.idpatient
	INNER JOIN visit3 v3
		ON v2.idpatient=v3.idpatient
	;
QUIT;

PROC SORT DATA=report_intersection;
	BY IDPatient;
RUN;

DATA report_intersection;
	set report_intersection;
	ref="1";
	RUN;

DATA report_intersection2;
	MERGE PatientsAll report_intersection;
	BY IDPatient;
	IF ref = "1";
	DROP ref;
RUN;

PROC PRINT DATA=report_intersection2;
	TITLE "Patients attending 3 times";
RUN;

PROC SQL;
	CREATE TABLE report_counts AS
	SELECT sum(case when v1.idpatient is not null
		and v2.idpatient is not null
		and v3.idpatient is not null
		then 1 else 0 end) as been_to_all,

		sum(case when v1.idpatient is not null
		and v2.idpatient is null
		and v3.idpatient is null
		then 1 else 0 end) as been_to_only1,

		sum(case when (v1.idpatient is not null or v2.idpatient is not null)
		and v3.idpatient is null
		then 1 else 0 end) as been_to_only1or2
	FROM visit1 v1
	LEFT JOIN visit2 v2
		ON v1.idpatient=v2.idpatient
	LEFT JOIN visit3 v3
		ON v2.idpatient=v3.idpatient
	;
QUIT;

PROC PRINT DATA=report_counts;
	TITLE "Patient Counts";
RUN;

ODS rtf CLOSE;
