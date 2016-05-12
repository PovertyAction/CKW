********************************************************************************
***********************SUMMARY STATS OF OUTCOME VARIABLES***********************
********************************************************************************

/***************
Author: Hideto Koizumi
Project: CKW (Rural Information - Uganda)
Purpose: Generate Appendix tables for productivity and audit outcome variables
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

global currentdate : display %tdNN-DD-CCYY date(c(current_date),"DM20Y")
local logpath "..\Dropbox\CKW\Analysis\logfiles"
log using "`logpath'\analysis_preliminary_${currentdate}.txt", append
loc dest "..\Dropbox\CKW\Analysis\results\temp"

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

use "../Dropbox/CKW/Analysis/data/FinalData_ForD2D",clear
#d;
loc labelpool 
		"`"Proportion of Completed Survey"' 
		`"Total Num of Completed Survey"'
		`"Completeness Rate"'
		`"Showed Consent Form?"'
		`"Politeness Scale"'
		`"Trust Scale"'
		`"Did enum ask to enter home"'
		`"Error Severity Score"'"
;
#d cr

#d;
loc outcomes
		propComplete
		totalcomplete
		completeness
		showconsentform 
		politescale  
		trustscale  
		enter   
		auditerror_score
;
#d cr

ren enumerator_full enumerator_full_str
encode enumerator_full_str, gen(enumerator_full)
collapse `outcomes' ckw  ///
		educationlevel gender_enum enumerator_full ///
		samegender samevillage age_enum how_well_know incomplete, by(uniqueid)


preserve
collapse propComplete totalcomplete educationlevel gender_enum age_enum, by(ckw enumerator_full)		

tempfile collapse
save `collapse'
restore

**Generate missing values
gen how_well_know_miss = mi(how_well_know)
la var how_well_know_miss "Missing Dummy for how well enum knows resp"
replace how_well_know = 0 if mi(how_well_know)
gen samegender_miss = mi(samegender)
la var samegender_miss "Missing Dummy for same gender b/w enum and resp"
replace samegender = 0 if mi(samegender)
gen samevillage_miss = mi(samevillage)
la var samevillage_miss "Missing Dummy for same village b/w enum and resp"
replace samevillage = 0 if mi(samevillage)


forval i = 1/`:list sizeof outcomes'{
	loc var: word `i' of `outcomes'
	loc lab: word `i' of `labelpool'
	
	la var `var' "`lab'"
}


estimates clear
cap eststo drop A*

*Simple regression
foreach var of local outcomes{
	if inlist("`var'", "propComplete", "totalcomplete") == 1{
		preserve
		u `collapse', clear
		la var propComplete "Proportion of Completed Survey"
		la var totalcomplete "Total Num of Completed Survey"
		if inlist("`var'", "totalcomplete") != 1{
			
			**Data source by sensitivity
			eststo Ase`var'2: qui regxomit `var' ckw educationlevel gender_enum ///
				age_enum 
			qui estadd loc obs = string(e(N),"%9.0f")
			qui estadd loc lab = "`:var lab `var''"
			qui estadd loc sample = "Attempted Survey"	
			qui estadd loc unit = "Enumerator Level"
			qui sum `var' if ckw == 0
			qui estadd loc ipadep = string(r(mean),"%9.3f")			
		}
		restore
	}
	else{
		**Data source cateogry by sensitivity
		eststo Ase`var'2: qui regxomit `var' ckw educationlevel gender_enum ///
			samegender samevillage age_enum how_well_know incomplete, cluster(enumerator_full)
			qui estadd loc obs = string(e(N),"%9.0f")
			qui estadd loc lab = "`:var lab `var''"
			qui estadd loc sample = "Attempted Survey"	
			qui estadd loc unit = "Survey Level"
			qui sum `var' if ckw == 0
			qui estadd loc ipadep = string(r(mean),"%9.3f")			
	}
}

****Productivity and Audit outcome variables analysis
esttab Ase*2 using "`dest'/reg_appendix_ols.csv", b(3) se(3) ar2(2) title(Table 2: Main Results) ///
	nonote noobs nogap star(* 0.10 ** 0.05 *** 0.01) replace /// 
	scalars("ipadep Mean of Dependent Variable for IPA Surveyors" "obs No. of Observations" "lab Dependent Variable:" ///
		"sample Sample Frame:" "unit Unit of Observation:")  /// 
	addn("Notes. Standard errors (clustered by enumerator if at the survey level) in parentheses." ///
	"* significant at 10% ** significant at 5% *** significant at 1%.") ///
	substitute(!^ `"" & CHAR(44) & " "') 




