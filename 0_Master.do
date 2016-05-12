********************************************************************************
******************************MASTER DO*****************************************
********************************************************************************

/***************
Author: Hideto Koizumi
Project: CKW (Rural Information - Uganda)
Purpose: Master Do file for Cleaning and Analyses for Journal Submission
Note: For journal submission, we don't need cleaning do file lines

Description of the project:
	We designed a field experiment in northern Uganda whose treatment is using local community membersÑi.e., 
	CKWsÑas data collector, while its counterfactual is normal data collectors whom IPA usually hires. 
	Note that there is no typical baseline survey, and we only have one wave of survey. T
	he survey was conducted between Sep 4th, 2011 and Dec 29th, 2011. We are mainly interested in two outcomes: 
	1) how many less / more survey questions CKWs complete compared to IPA enumerators and 
	2) how accurate responses CKWs can get from respondents, given that we have the ÒtruthÓ on some survey questions 
	by design.  Our true data is coming from various sources, and the successor is expected to read the ÒStep 
	2) Gather True Data SourcesÓ section of the report Trina Gorman wrote 2 years ago (CKW\Reports\Final Report 1 
	and 2\ CKW Final Report I - 29.June.2012 - with GRMN comments.docx). 
	For online appendix tables, we are expected to look at 
	a) how many surveys CKWs conducted compared to IPA, 
	b) what the impression of respondents to CKW surveyors, which come from audit surveys we separately conducted. 
all the b,c,d,f,g,h,i information from the code-check checklist is available at the 
Dropbox/CKW/Internal Notes/data structure_chart_for_progress_ckw.xlsx

e: output
/Users/hidetokoizumi/Dropbox/CKW/Analysis/results/balance.xml--> balance table (Table 1)
/Users/hidetokoizumi/Dropbox/CKW/Analysis/results/attrition.xml--> attrition test which we might not use (Table1)
/Users/hidetokoizumi/Dropbox/CKW/Analysis/results/summstats_outcome.xml--> summary stats of outcomes (Table1)
/Users/hidetokoizumi/Dropbox/CKW/Analysis/results/temp/reg_main_ols.csv--> main regression table (Table2)
/Users/hidetokoizumi/Dropbox/CKW/Analysis/results/temp/reg_appendix_ols.csv--> productivity and audit (Appendix)
/Users/hidetokoizumi/Dropbox/CKW/Analysis/results/temp/reg_accMISS0_ols.csv--> missings as mistakes (Appendix)
/Users/hidetokoizumi/Dropbox/CKW/Analysis/results/temp/reg_mainWeight_ols.csv--> equal weight (Appendix)
/Users/hidetokoizumi/Dropbox/CKW/Analysis/results/temp/reg_ckwhetero_ols.csv-->ckw heterogeneity (Table3)
/Users/hidetokoizumi/Dropbox/CKW/Analysis/results/temp/reg_knowsense_ols.csv-->hetero by acquaintance
/Users/hidetokoizumi/Dropbox/CKW/Analysis/results/temp/reg_samevsense_ols.csv--> hetero by same village

i: order of do files
is clear below



`root'/Analysis/dofiles/cleaning/completenessCleaning.do is to calculate the completeness rate of questions
from the appendix table

***************/
clear all
capture log close
if "`c(username)'"=="hkoizumi"  ///
	c dropbox
else if "`c(username)'"=="dsk26"  ///
	cd "C:/Users/dsk26/Dropbox"
else if "`c(username)'"=="margaretmcconnell"  ///
	cd "C:/Users/margaretmcconnell/Dropbox"
else if "`c(username)'"=="Pi"  ///
	cd "C:/Users/Pi/Documents/My Dropbox"
local root "../Dropbox/CKW"
local do "`root'/Analysis/dofiles"
local main "`root'/Analysis/dofiles/main"
local appen "`root'/Analysis/dofiles/appendix"

global currentdate : display %tdNN-DD-CCYY date(c(current_date),"DM20Y")
local logpath "../Dropbox/CKW/Analysis/logfiles"
log using "`logpath'/analysis_preliminary_${currentdate}.txt", append

******SSC commands to be installed**************
#d ;
loc ssc 
		xml_tab
;
#d cr	

foreach var of local ssc{
	cap ssc install `var'
}

**Cleaning Data set
include "`do'/cleaning/Data Cleaning_Master.do"

**Data (Note that the one before dropping unncessary variables is "FinalData.dta"
use "`root'/Analysis/data/Main",clear

****Main Tables*************************************
**Table 1: Summary Stats
include "`main'/Table1.do"
**Table 2: Main results
include "`main'/Table2.do"
**Table 3: CKW Heterogeneity
include "`main'/Table3.do"


****Appendix Tables*************************************
*Outcomes = Productivity Measure and Audit Outcome Variables
include "`appen'/ProductivityAudit.do"
*Assign 0s to missing values of recorded_accurate--i.e., missing values as mistakes
include "`appen'/Main_MissingAsInaccurate.do"
*Give an equal weight to each respondent --i.e., weight by the inverse of (1) # of attempted questions & 
*(2) # of completed questions
include "`appen'/Main_weighted.do"




