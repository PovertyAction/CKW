
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
	cd "C:/Users/rlokur/Dropbox/CKW"

global currentdate : display %tdNN-DD-CCYY date(c(current_date),"DM20Y")
	*local logpath "../CKW/Analysis/logfiles"
	*log using "`logpath'/analysis_preliminary_${currentdate}.txt", append
loc dest "../CKW/Analysis/results/revised_results/temp"
loc root "../CKW"
use "Analysis/data/FinalData",clear

**Summary Stats of Outcome Variables********
//the first rows about data source summary stats are from the following tabulation 
ta org if status == "Complete!"
levelsof source, loc(sources)
foreach v of local sources{
	di "`v'"
	ta `v' org if status == "Complete!"
}

tab ckw foundsurvey if status=="Complete!"  // this generates proportions of 


**	 Panel C 	**
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
	loc total`v' = r(N_1) + r(N_2)
	loc diff`v' = `CKWmean`v'' - `IPAmean`v''
	loc p`v' `r(p)'
	matrix summstat = (nullmat(summstat) \ `CKWmean`v'', `IPAmean`v'', `diff`v'', `p`v'', `total`v'')
	if inlist("`v'", "propComplete", "totalcomplete") == 1 {
		restore
	}		
}
matrix rownames summstat = "Recorded Answer" "Recorded Answer is Accurate" 
matrix colnames summstat = "CKW Mean" "IPA Mean" "Difference" "P-value"	"Total N"
xml_tab summstat using "Analysis/results/summstats_outcome.xls", replace
stop

orth_out completeness, by(ckw)

** Summary stats of survey response rate

***IPA
**Assigned
count if ckw == 0 //IPA
local ipan = `r(N)'

**Sensitive
count if ckw == 0 & data_sense == 1 //IPA
local ipan_sense = `r(N)'

count if ckw == 0 & data_neutral == 1 //IPA
local ipan_neutral = `r(N)'

count if ckw == 0 & data_local == 1 //IPA
local ipan_local = `r(N)'

**Completed
count if ckw == 0 & status == "Complete!" //IPA
local ipaint = `r(N)'

count if ckw == 0 & status == "Complete!"  & data_sense == 1 //IPA
local ipaint_sense = `r(N)'

count if ckw == 0 & status == "Complete!"  & data_neutral == 1 //IPA
local ipaint_neutral = `r(N)'

count if ckw == 0 & status == "Complete!"  & data_local == 1 //IPA
local ipaint_local = `r(N)'


***CKW
**Assigned
count if ckw == 1 //ckw
local ckwn = `r(N)'

count if ckw == 1 & data_sense == 1 //IPA
local ckwn_sense = `r(N)'

count if ckw == 1 & data_neutral == 1 //IPA
local ckwn_neutral = `r(N)'

count if ckw == 1 & data_local == 1 //IPA
local ckwn_local = `r(N)'

**Completed
count if ckw == 1 & status == "Complete!" //IPA
local ckwint = `r(N)'

count if ckw == 1 & status == "Complete!"  & data_sense == 1 //IPA
local ckwint_sense = `r(N)'

count if ckw == 1 & status == "Complete!"  & data_neutral == 1 //IPA
local ckwint_neutral = `r(N)'

count if ckw == 1 & status == "Complete!"  & data_local == 1 //IPA
local ckwint_local = `r(N)'


count if _N
loc N `r(N)'
count if data_sense == 1
loc sense `r(N)'
count if data_local == 1
loc local `r(N)'
count if data_neutral == 1
loc neutral `r(N)'
count if status == "Complete!"
loc comp `r(N)'
count if status == "Complete!" & data_sense == 1
loc comp_sense `r(N)'
count if status == "Complete!" & data_local == 1
loc comp_local `r(N)'
count if status == "Complete!" & data_neutral == 1
loc comp_neutral `r(N)'

cap matrix drop attrition

matrix attrition = nullmat(attrition)\(`N', `ipan', `ckwn', `=`ckwn'-`ipan'')
matrix attrition = nullmat(attrition)\(`sense', `ipan_sense', `ckwn_sense', `=`ckwn_sense'-`ipan_sense'')
matrix attrition = nullmat(attrition)\(`neutral', `ipan_neutral', `ckwn_neutral', `=`ckwn_neutral'-`ipan_neutral'')
matrix attrition = nullmat(attrition)\(`local', `ipan_local', `ckwn_local', ///
	`=`ckwn_local'-`ipan_local'')

matrix attrition = nullmat(attrition)\(`comp', `ipaint', `ckwint', `=`ckwint'-`ipaint'')
matrix attrition = nullmat(attrition)\(`comp_sense', `ipaint_sense', `ckwint_sense', ///
	`=`ckwint_sense'-`ipaint_sense'')
matrix attrition = nullmat(attrition)\(`comp_neutral', `ipaint_neutral', `ckwint_neutral', ///
	`=`ckwint_neutral'-`ipaint_neutral'')
matrix attrition = nullmat(attrition)\(`comp_local', `ipaint_local', `ckwint_local', ///
	`=`ckwint_local'-`ipaint_local'')

matrix attrition = nullmat(attrition)\(`=`comp'/`N'', `=`ipaint'/`ipan'', `=`ckwint'/`ckwn'', ///
	`=`=`ckwint'/`ckwn''-`=`ipaint'/`ipan''')
matrix attrition = nullmat(attrition)\(`=`comp_sense'/`sense'', `=`ipaint_sense'/`ipan_sense'', ///
	`=`ckwint_sense'/`ckwn_sense'', `=`=`ckwint_sense'/`ckwn_sense''-`=`ipaint_sense'/`ipan_sense''')
matrix attrition = nullmat(attrition)\(`=`comp_neutral'/`neutral'', `=`ipaint_neutral'/`ipan_neutral'', ///
	`=`ckwint_neutral'/`ckwn_neutral'', `=`=`ckwint_neutral'/`ckwn_neutral''-`=`ipaint_neutral'/`ipan_neutral''')
matrix attrition = nullmat(attrition)\(`=`comp_local'/`local'', `=`ipaint_local'/`ipan_local'', ///
	`=`ckwint_local'/`ckwn_local'', `=`=`ckwint_local'/`ckwn_local''-`=`ipaint_local'/`ipan_local''')
	
matrix rownames attrition = "# of respondents assigned" "# of respondents assigned_S" ///
	"# of respondents assigned_N" "# of respondents assigned_L" ///
	"# of respondents found" "# of respondents found_S" ///
	"# of respondents found_N" "# of respondents found_L" ///
	"% of respondents found" "% of respondents found_S" ///
	"% of respondents found_N" "% of respondents found_L" 
xml_tab attrition using "Analysis/results/revised results/summstats_completion.xls", replace

****	Summary stats of responses and accurate answers, by question type	****

***IPA
**Assigned
count if ckw == 0 //IPA
local ipan = `r(N)'

**Recorded_answers
count if ckw == 0 & recorded_answer==1 
local ipa_ans = `r(N)'

count if ckw == 0 & recorded_answer==1  & data_sense == 1 
local ipa_ans_sense = `r(N)'

count if ckw == 0 & recorded_answer==1  & data_neutral == 1 
local ipa_ans_neutral = `r(N)'

count if ckw == 0 & recorded_answer==1  & data_local == 1 
local ipa_ans_local = `r(N)'

**Recorded_answer is accurate
count if ckw == 0 & recorded_accurate==1 
local ipa_acc = `r(N)'

count if ckw == 0 & recorded_accurate==1  & data_sense == 1 
local ipa_acc_sense = `r(N)'

count if ckw == 0 & recorded_accurate==1  & data_neutral == 1 
local ipa_acc_neutral = `r(N)'

count if ckw == 0 & recorded_accurate==1  & data_local == 1 
local ipa_acc_local = `r(N)'

***CKW
**Assigned
count if ckw == 1 //ckw
local ckwn = `r(N)'

** Recorded_answers
count if ckw == 1 & recorded_answer==1 
local ckw_ans = `r(N)'

count if ckw == 1 & recorded_answer==1  & data_sense == 1 
local ckw_ans_sense = `r(N)'

count if ckw == 1 & recorded_answer==1 & data_neutral == 1 
local ckw_ans_neutral = `r(N)'

count if ckw == 1 & recorded_answer==1 & data_local == 1 
local ckw_ans_local = `r(N)'

** Recorded_answer is accurate
count if ckw == 1 & recorded_accurate==1 
local ckw_acc = `r(N)'

count if ckw == 1 & recorded_accurate==1  & data_sense == 1 
local ckw_acc_sense = `r(N)'

count if ckw == 1 & recorded_accurate==1 & data_neutral == 1
local ckw_acc_neutral = `r(N)'

count if ckw == 1 & recorded_accurate==1 & data_local == 1 
local ckw_acc_local = `r(N)'

count if _N
loc N `r(N)'
count if data_sense == 1
loc sense `r(N)'
count if data_local == 1
loc local `r(N)'
count if data_neutral == 1
loc neutral `r(N)'

count if recorded_answer==1
loc ans `r(N)'
count if recorded_answer==1 & data_sense == 1
loc ans_sense `r(N)'
count if recorded_answer==1 & data_local == 1
loc ans_local `r(N)'
count if recorded_answer==1 & data_neutral == 1
loc ans_neutral `r(N)'

count if recorded_accurate==1
loc acc `r(N)'
count if recorded_accurate==1 & data_sense == 1
loc acc_sense `r(N)'
count if recorded_accurate==1 & data_local == 1
loc acc_local `r(N)'
count if recorded_accurate==1 & data_neutral == 1
loc acc_neutral `r(N)'

cap matrix drop attrition

matrix attrition = (nullmat(attrition)\(`N', `ipan', `ckwn', `=`ckwn'-`ipan''))
*	matrix attrition = (nullmat(attrition)\(`sense', `ipan_sense', `ckwn_sense', `=`ckwn_sense'-`ipan_sense''))
*	matrix attrition = (nullmat(attrition)\(`neutral', `ipan_neutral', `ckwn_neutral', `=`ckwn_neutral'-`ipan_neutral''))
*	matrix attrition = (nullmat(attrition)\(`local', `ipan_local', `ckwn_local', ///
	`=`ckwn_local'-`ipan_local''))

matrix attrition = (nullmat(attrition)\(`ans', `ipa_ans', `ckw_ans', `=`ckw_ans'-`ipa_ans''))
matrix attrition = (nullmat(attrition)\(`acc', `ipa_acc', `ckw_acc', `=`ckw_acc'-`ipa_acc''))

matrix attrition = (nullmat(attrition)\(`ans_sense', `ipa_ans_sense', `ckw_ans_sense', ///
	`=`ckw_ans_sense'-`ipa_ans_sense''))
matrix attrition = (nullmat(attrition)\(`acc_sense', `ipa_acc_sense', `ckw_acc_sense', ///
	`=`ckw_acc_sense'-`ipa_acc_sense''))
	
matrix attrition = (nullmat(attrition)\(`ans_neutral', `ipa_ans_neutral', `ckw_ans_neutral', ///
	`=`ckw_ans_neutral'-`ipa_ans_neutral''))
matrix attrition = (nullmat(attrition)\(`acc_neutral', `ipa_acc_neutral', `ckw_acc_neutral', ///
	`=`ckw_acc_neutral'-`ipa_acc_neutral''))
	
matrix attrition = (nullmat(attrition)\(`ans_local', `ipa_ans_local', `ckw_ans_local', ///
	`=`ckw_ans_local'-`ipa_ans_local''))
matrix attrition = (nullmat(attrition)\(`acc_local', `ipa_acc_local', `ckw_acc_local', ///
	`=`ckw_acc_local'-`ipa_acc_local''))
	
/*
matrix attrition = nullmat(attrition)\(`=`comp'/`N'', `=`ipaint'/`ipan'', `=`ckwint'/`ckwn'', ///
	`=`=`ckwint'/`ckwn''-`=`ipaint'/`ipan''')
matrix attrition = nullmat(attrition)\(`=`comp_sense'/`sense'', `=`ipaint_sense'/`ipan_sense'', ///
	`=`ckwint_sense'/`ckwn_sense'', `=`=`ckwint_sense'/`ckwn_sense''-`=`ipaint_sense'/`ipan_sense''')
matrix attrition = nullmat(attrition)\(`=`comp_neutral'/`neutral'', `=`ipaint_neutral'/`ipan_neutral'', ///
	`=`ckwint_neutral'/`ckwn_neutral'', `=`=`ckwint_neutral'/`ckwn_neutral''-`=`ipaint_neutral'/`ipan_neutral''')
matrix attrition = nullmat(attrition)\(`=`comp_local'/`local'', `=`ipaint_local'/`ipan_local'', ///
	`=`ckwint_local'/`ckwn_local'', `=`=`ckwint_local'/`ckwn_local''-`=`ipaint_local'/`ipan_local''')
*/
matrix rownames attrition = "# of respondents assigned" ///
	"Recorded an answer" "Recorded an accurate answer" ///
	"Recorded an answer, S" "Recorded an accurate answer, S" ///
	"Recorded an answer, N" "Recorded an accurate answer, N" ///
	"Recorded an answer, L" "Recorded an accurate answer, L"  ///

matrix colnames attrition = "Total" "IPA" "CKW" "Difference"

xml_tab attrition using "Analysis/results/summstats_response.xls", replace

gen recans_sense = recorded_answer * data_sense
gen recans_local = recorded_answer * data_local
gen recans_neutral = recorded_answer * data_neutral
gen recacc_sense = recorded_accurate * data_sense
gen recacc_local = recorded_accurate * data_local
gen recacc_neutral = recorded_accurate * data_neutral

orth_out recorded_answer recorded_accurate recans_sense recacc_sense recans_local recacc_local recans_neutral recacc_neutral completeness using "summstats by type.xls", by(ckw) se compare stars replace
tab data_sense condom_received

****	Balance Test of Variables? Uncontaminated by treatment ****

use "Analysis/data/FinalData_ForD2D",clear

sum bednet_date_recieved
gen bednet_numberofdays = bednet_date_recieved - r(min)
la var bednet_numberofdays "Number of days since first reported bednet receipt" 

sum loan1_date 
gen loan_numberofdays = loan1_date - r(min)
la var loan_numberofdays "Number of days since first reported loan date"

** Panel B 	**
#d;
loc true
	seedskindnum					
	zscBednetDate
	bednet_numberofdays
	age_true
	loanamt
	zscLoanDate
	loan_numberofdays
	gender_true
;
#d cr

*cap mat drop ttests
*loc notes

orth_out `true' using "Analysis/results/revised results/balance_test2", by(ckw) se pcompare replace vcount

/* this is to add a row at the bottom with the joint f-test

reg ckw seedskindnum bednet_numberofdays age_true loanamt loan_numberofdays gender_true
test seedskindnum bednet_numberofdays age_true loanamt loan_numberofdays gender_true
estout r(F) r(p) using "Analysis/results/revised results/balance_test2", append

error: no observations- no respondent has answered all the variables above, can't do the combined f-test. what shoudk be done instead?
*/

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
	cap loc N_total_`var'= r(N_2) + r(N_1)
	di "`N_total_`var''"
	matrix ttests = (nullmat(ttests) \ (r(mu_2), r(mu_1), `=r(mu_2) - r(mu_1)', r(p), `N_total_`var''))

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
matrix colnames ttests = "Mean of CKW" "Mean of IPA" "Difference" "P-value" "Total N"

mata: ttests = st_matrix("ttests")
xml_tab ttests using "Analysis/results/revised results/balance test.xls",  replace 


/*
**	 Generates same table as above but with FDR- not needed, as per Dean's email

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

xml_tab ttests using "`root'/Analysis/results/balance2.xml", notes(`notes') /*stars(.1 .05 .01)*/ replace //VBA is formatBalance.xmls
*/


