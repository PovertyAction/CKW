
********************************************************************************
*************************************TABLE1*************************************
********************************************************************************
/***************
Author: Hideto Koizumi
Project: CKW (Rural Information - Uganda)
Purpose: Analysis on Summary Stats: generate Table 1
***************/
loc table TABLE 1.
clear
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
	cd "C:/Users/hidetokoizumi/Dropbox/"
else if "`c(username)'"=="rlokur"  ///
	cd "C:/Users/rlokur/Dropbox/"
	
global currentdate : display %tdNN-DD-CCYY date(c(current_date),"DM20Y")
local logpath "../Dropbox/CKW/Analysis/logfiles"
*log using "`logpath'/analysis_preliminary_${currentdate}.txt", append
loc dest "../Dropbox/CKW/Analysis/results/temp"
loc root "../Dropbox/CKW"
use "`root'/Analysis/data/FinalData",clear

**Summary Stats of Outcome Variables********
//the first rows about data source summary stats are from the following tabulation 
ta org if status == "Complete!"
levelsof source, loc(sources)
foreach v of local sources{
	di "`v'"
	ta `v' org if status == "Complete!"
}

#d;
loc outcomes 
		recorded_answer
		recorded_accurate
;
#d cr

cap matrix drop summstat
foreach v of local outcomes{
	if inlist("`v'", "propComplete", "totalcomplete") == 1 {
		preserve
		use "`collapse'", clear
	}
	di "`v'"
	ttest `v' , by(ckw)
	loc IPAmean`v' `r(mu_1)'
	loc CKWmean`v' `r(mu_2)'
	loc IPAN`v' `r(N_1)'
	loc CKWN`v' `r(N_2)'
	loc diff`v' = `CKWmean`v'' - `IPAmean`v''
	loc p`v' `r(p)'
	matrix summstat = nullmat(summstat)/(`CKWmean`v'', `IPAmean`v'', `diff`v'', `p`v'', `CKWN`v'', `IPAN`v'')
	if inlist("`v'", "propComplete", "totalcomplete") == 1 {
		restore
	}		
}
matrix rownames summstat =  "Recorded Answer" "Recorded Answer is Accurate = 1" 
matrix colnames summstat = "CKW Mean" "IPA Mean" "Difference" "P-value"	"N of CKW" "N of IPA"
xml_tab summstat using "`root'/Analysis/results/summstats_outcome.xml", replace



****Balance Test of Variables?Uncontaminated by treatment
use "`root'/Analysis/data/FinalData_ForD2D",clear
	
#d;
loc true
	gender_true
	age_true
	zscBednetDate
	seedskindnum
	loanamt
	zscLoanDate
;
#d cr

cap mat drop ttests
loc notes

foreach var of local true {
	loc mrownames "`mrownames' "`var'""
	qui su `var'
	if r(min) == r(max) {
		loc onevalvars `onevalvars' `var'
		continue
	}

	qui count if !missing(`var') & ckw == 1
	loc nt = r(N)
	qui count if !missing(`var') & ckw == 0
	loc nc = r(N)
	if `nt'==0 | `nc'==0 {
		loc missingvars `missingvars'`var'
		continue
	}
	if `nt'==1 | `nc'==1 {
		loc fewvars `fewvars' `var'
		continue
	}

	qui ttest `var', by(ckw)
	matrix ttests = nullmat(ttests) / (r(mu_2), r(mu_1), `=r(mu_2) - r(mu_1)', r(p), r(N_2), r(N_1))

	loc note : char `var'[note1]
	if "`note'" == "" {
		loc note : var lab `var'
		if "`note'" == ""  ///
			loc note `var'
	}

	if `"`notes'"' != "" loc notes "`notes', "
	loc notes "`notes' "`note'""
	
	di "`rownames'"
	loc rownames : list var - onevalvars
	loc rownames : list rownames - missingvars
	loc rownames : list rownames - fewvars
	if "`rownames'" == "" ///
		di "`g': No variables left...! :("
}
di `"`mrownames'"'
matrix rownames ttests = `mrownames'
matrix colnames ttests = "Mean of CKW" "Mean of IPA" "Difference" "P-value" "N of CKW" "N of IPA"

mata: ttests = st_matrix("ttests")
xml_tab ttests using "`root'/Analysis/results/balance.xml",  replace //VBA is formatBalance.xmls
clear
svmat2 ttests, rnames(row)
gen order = _n
sort ttests4
gen fdr = .

loc alpha = 0.05 //set significance level
loc n = _N
forval i = 1/`n'{
	replace fdr = (`i'/`n')*`alpha' in `i'
}

order fdr, after(ttests4)
sort order
drop order
ds, has(type numeric)
mkmat `r(varlist)', matrix(ttests) rownames(row)
matrix colnames ttests = "Mean of CKW" "Mean of IPA" "Difference" "P-value" "FDR Adjusted Significance Level" "N of CKW" "N of IPA"

xml_tab ttests using "`root'/Analysis/results/balance.xml", notes(`notes') /*stars(.1 .05 .01)*/ replace //VBA is formatBalance.xmls

