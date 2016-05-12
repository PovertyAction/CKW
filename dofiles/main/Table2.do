********************************************************************************
***********************Table 2***********************
********************************************************************************

/***************
Author: Hideto Koizumi
Project: CKW (Rural Information - Uganda)
Purpose: Generate Table 2: Main results
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
else if "`c(username)'"=="hidetokoizumi"  ///
	cd "/Users/hidetokoizumi/Dropbox/"

	
global currentdate : display %tdNN-DD-CCYY date(c(current_date),"DM20Y")
local logpath "../Dropbox/CKW/Analysis/logfiles"
log using "`logpath'/analysis_preliminary_${currentdate}.txt", append
loc dest "../Dropbox/CKW/Analysis/results/temp"


***Program to omit rows for omitted variable rows in result tables : Probit
cap pr drop probreg
pr probreg, eclass
	syntax varlist [if] [in], *

	probit `varlist' `if' `in', `options'
	loc probnames : colnames e(b)

	* Save results from -probit- to repost later.
	tempname b V
	mat `b' = e(b)
	mat `V' = e(V)
	loc N = e(N)

	qui reg `varlist' `if' `in'
	loc regnames : colnames e(b)
	assert `:list probnames == regnames'

	* Repost the results.
	eret repost b = `b'
	eret repost V = `V'
	eret sca N = `N'
end

***Program to omit rows for omitted variable rows in result tables : OLS reg
cap pr drop regxomit
pr regxomit
	syntax varlist [if] [in], *

	gettoken depvar indepvars : varlist

	qui _rmcollright `varlist' `if' `in'
	loc dropped `r(dropped)'
	loc indepvars : list indepvars - dropped

	reg `depvar' `indepvars' `if' `in', `options'
end

use "../Dropbox/CKW/Analysis/data/FinalData",clear

**Generate missing value dummies
gen how_well_know_miss = mi(how_well_know)
la var how_well_know_miss "Missing Dummy for how well enum knows resp"
replace how_well_know = 0 if mi(how_well_know)
gen samegender_miss = mi(samegender)
la var samegender_miss "Missing Dummy for same gender b/w enum and resp"
replace samegender = 0 if mi(samegender)
gen samevillage_miss = mi(samevillage)
la var samevillage_miss "Missing Dummy for same village b/w enum and resp"
replace samevillage = 0 if mi(samevillage)

gen ckw_female_resp = ckw*female_resp
gen ckw_female_enum = ckw*female_enum
gen ckw_female_respenum = ckw*female_respenum

#d;
loc outcomes 
		recorded_answer
		recorded_accurate
;
#d cr


estimates clear
cap eststo drop A*

*Simple regression
foreach var of local outcomes{
	eststo A`var'1: qui reg `var' ckw, cluster(enumerator_full)			
	qui estadd loc obs = string(e(N),"%9.0f")
	qui sum `var' if ckw == 0 //Mean stats for IPA group
	qui estadd loc ipadep = string(r(mean),"%9.3f")
	qui estadd loc lab = "`:var lab `var''"	
	if "`var'" == "recorded_answer" {
		qui estadd loc sample = "Attempted Questions"
		qui estadd loc unit = "Question on Attempted Survey!^ for Which We Also Have ^!Truth^! from Administrative Data"
	}
	else if "`var'" == "recorded_accurate" {
		qui estadd loc sample = "Completed Questions"
		qui estadd loc unit = "Completed Question!^ for Which We Also Have ^!Truth^! from Administrative Data"
	}
	qui estadd loc control = "Yes"
}

* Data source
foreach var of local outcomes{
	**Data source cateogry by sensitivity
	eststo Ase`var'1: qui reg `var' ckw ckw_local ckw_sense ///
		data_local data_sense educationlevel gender_enum ///
		samegender samevillage age_enum how_well_know incomplete, cluster(enumerator_full)
	qui estadd loc obs = string(e(N),"%9.0f")
	qui sum `var' if ckw == 0 //Mean stats for IPA group
	qui estadd loc ipadep = string(r(mean),"%9.3f")
	qui estadd loc lab = "`:var lab `var''"
	if "`var'" == "recorded_answer" {
		qui estadd loc sample = "Attempted Questions"
		qui estadd loc unit = "Question on Attempted Survey!^ for Which We Also Have ^!Truth^! from Administrative Data"
	}
	else if "`var'" == "recorded_accurate" {
		qui estadd loc sample = "Completed Questions"
		qui estadd loc unit = "Completed Question!^ for Which We Also Have ^!Truth^! from Administrative Data"
	}
	qui estadd loc control = "Yes"	
}

**Gender Hetero

foreach var of local outcomes{

	**Gender hetero
	eststo Agen`var'1: qui reg `var' ckw female_resp female_enum female_respenum ///
		educationlevel  ///
		samegender samevillage age_enum how_well_know incomplete, cluster(enumerator_full)
	qui estadd loc obs = string(e(N),"%9.0f")
	qui sum `var' if ckw == 0
	qui estadd loc ipadep = string(r(mean),"%9.3f")
	qui estadd loc lab = "`:var lab `var''"
	if "`var'" == "recorded_answer" {
		qui estadd loc sample = "Attempted Questions"
		qui estadd loc unit = "Question on Attempted Survey!^ for Which We Also Have ^!Truth^! from Administrative Data"
	}
	else if "`var'" == "recorded_accurate" {
		qui estadd loc sample = "Completed Questions"
		qui estadd loc unit = "Completed Question!^ for Which We Also Have ^!Truth^! from Administrative Data"
	}
	qui estadd loc control = "Yes"
}

**Gender interact with CKW
foreach var of local outcomes{

	**Gender hetero
	eststo Acgen`var'1: qui reg `var' ckw female_resp female_enum female_respenum ///
		ckw_female_resp ckw_female_enum ckw_female_respenum educationlevel ///
		samegender samevillage age_enum how_well_know incomplete, cluster(enumerator_full)
	qui estadd loc obs = string(e(N),"%9.0f")
	qui sum `var' if ckw == 0
	qui estadd loc ipadep = string(r(mean),"%9.3f")
	qui estadd loc lab = "`:var lab `var''"
	if "`var'" == "recorded_answer" {
		qui estadd loc sample = "Attempted Questions"
		qui estadd loc unit = "Question on Attempted Survey!^ for Which We Also Have ^!Truth^! from Administrative Data"
	}
	else if "`var'" == "recorded_accurate" {
		qui estadd loc sample = "Completed Questions"
		qui estadd loc unit = "Completed Question!^ for Which We Also Have ^!Truth^! from Administrative Data"
	}
	qui estadd loc control = "Yes"
}

****Data source hetero by sensitivity
esttab A*1 using "`dest'/reg_main_ols.csv", b(3) se(3) ar2(2) title(Table 2: Main Results) ///
	nonote noobs nogap star(* 0.10 ** 0.05 *** 0.01) replace /// 
	scalars("control Controls Included?" "ipadep Mean of Dependent Variable for IPA Surveyors" "obs No. of Observations" "lab Dependent Variable:" ///
		"sample Sample Frame:" "unit Unit of Observation:")  /// 
	addn("Notes. Standard errors clustered at the enumerator level in parentheses. Local knowledge data is data that can be collected outside of house!^ while sensitive data is private information that is collected inside house (neutral is between the two)." ///
	"Non-sensitive data source category includes ACTED!^ Forestry!^ and NRC data sources!^ neutral data source is Bednet and D2D!^ while sensitive data source includes Condoms and Loan data sources." ///
	"* significant at 10% ** significant at 5% *** significant at 1%.") ///
	substitute(!^ `"" & CHAR(44) & " "' ^! `"" & CHAR(34) & ""') 




