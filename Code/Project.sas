
%LET filepath = ".."

/* Data Set-Up */
LIBNAME DataPg "&filepath/data";

%MACRO import; 
	%DO number = 1 %TO 3;
		PROC IMPORT 
 				DATAFILE="&filepath/data/Visit&number"
				DBMS=XLS OUT=DataPg.visit&number REPLACE;
		RUN; 
	
		DATA visit&number;
			SET DataPg.visit&number(RENAME=(DBP&number=DBP SBP&number=SBP 
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

ODS RTF FILE="&filepath/data/final_patients.rtf";

PROC PRINT DATA=PatientsAll;
	TITLE "Final Dataset";
RUN; 

ODS RTF CLOSE;

/* Create Reports  */
ODS RTF file="&filepath/data/final_report.rtf";

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



