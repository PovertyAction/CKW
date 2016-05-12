**************************************************************************************
****************************    MASTER Cleaning DO FILE - CKW PROJECT **********************
**************************************************************************************

/***************
Author: Hideto Koizumi (copied and pasted some part of the Trina Gorman's do files)
Project: CKW (Rural Information - Uganda)
Purpose: Cleans and begins analysis of CKW submitted data against true data sources. More specifically these do files:
1. Bring together submitted data from IPA and CKW.
2. Manually change data from audits and scrutiny.
3. Merge submiited data with true data using reclink (sweet), D2D data, and enumerator data.
4. Start analysis of key indicators.
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
set varabbrev on

loc root "../Dropbox/CKW"
loc do "`root'/Analysis/dofiles/cleaning"
cap truecrypt "../Dropbox/CKW/Old/CKW Data Collection/STATA.tc", mount drive(T)

cap truecrypt "T:/Encrypted_Data/Encrypted_Data_File_2.tc", mount drive(P)
conf f "P:/Encrypted_Data_File_2.txt"

cap truecrypt "../Dropbox/CKW/incompIPA_Reviewed.tc", mount drive(M)
conf f "M:/ipacheck.txt"

cap truecrypt "../Dropbox/CKW/Data/PII_info.tc", mount drive(W)
conf file "W:/all_ckw_info/all_ckw_infoSOL_11132012_Final_clean.dta"

capture truecrypt "../Dropbox/CKW/Data/Data_unique.tc", mount drive(Y)
conf f "Y:/test.txt"
//mata: assert(direxists("P:/CKW_Data"))
//mata: assert(direxists("P:/Combined_Data"))

/********** CREATING GLOBALS ***********/

// where IPA data and output is stored
gl ipa_cleaning = "P:/IPA_Data"
// where CKW data and output is stored
gl ckw_cleaning "P:/CKW_Data"
// where the true data is stored
gl true_data "P:/True_Data (do)"
// where Trina stores data w/ identifying info
gl encrypted_data "P:/Combined_Data"
// Where data w/o identifying information + all dos are stored.
gl master "T:/MASTER"
// where the demographic data about enumerators is stored - this directory has its own do file that creates $enum_info/data/enum_info.dta.
gl enum_info = "T:/Enum_Info (do)"
// where Adam's data is stored
gl d2d_data "T:/D2D_Data"
// where Adam's data is stored
gl audit_data "T:/Auditing_Data (do)"

/*********** STEP (1) COMBINE ALL SUBMISSIONS INTO ONE DATASET ***********************************/


**************************************************************************************
****************************    COMBINE SUBMITTED DATA  **************************
**************************************************************************************

/***************
Author: Trina Gorman
Project: CKW (Rural Information - Uganda)
Purpose: Combines IPA data, CKW data, and Joe's extra submissions into one dataset
***************/

/* PREPARE IPA SUBMISSIONS */

insheet using "$ipa_cleaning/raw/SubmissionCSV-NoStartDate-NoEndDate-NoStatus.csv"
gen ipa_mark = 1
// Need to change variable types to match eachother
#delimit;

foreach var of varlist future_health_org time_begins respondent_id resp_age  bednets beddings
chairs  tables stoves goats chickens cows bikes
subcounty male interview_alone suspicious mental_state
consent_signed converstation related how_well_know rel_family from_geo same_named_villager
hoh children_16 bio_children alive_children deworm_used_2 deworm_house deworm_free
pan_used_2 pan_used_6 pan_house pan_free ors_used_2 or_hh ors_free z_used_2 z_hh z_free
market_approach approached_free condom today_health_action today_health_org future_health_action
member_vsla have_applied_loan taken_loans member_of_group training group_inputs personal_support
received_seedlings heard_ckw researcher_times research_sat type_stove where_cook sleep_night
sleep_day spend_time better_stove hh_consent bednets_seen beddings_seen stoves_seen bikes_seen
goats_seen  time_ends{ ;
	#delimit cr
	tostring `var', replace
}
saveold "$ipa_cleaning/data/ipa_submissions.dta", replace

/* PREPARE IPA SUBMISSIONS THAT WERE ACCIDENTALLY SUBMITTED TO GRAMEEN */

clear
insheet using "$ipa_cleaning/raw/IPA_DATA_TO_ADD.csv"
gen ipaadd_mark = 1
// Need to change variable types to match

#delimit;

foreach var of varlist future_health_org time_begins respondent_id resp_age  bednets beddings
chairs  tables stoves goats chickens cows bikes
subcounty male interview_alone suspicious mental_state
consent_signed converstation related how_well_know rel_family from_geo same_named_villager
hoh children_16 bio_children alive_children deworm_used_2 deworm_house deworm_free
pan_used_2 pan_used_6 pan_house pan_free ors_used_2 or_hh ors_free z_used_2 z_hh z_free
market_approach approached_free condom today_health_action today_health_org future_health_action
member_vsla have_applied_loan taken_loans member_of_group training group_inputs personal_support
received_seedlings heard_ckw researcher_times research_sat type_stove where_cook sleep_night
sleep_day spend_time better_stove hh_consent bednets_seen beddings_seen stoves_seen bikes_seen
goats_seen  time_ends interviewerintervieweedistance{ ;
	#delimit cr
	tostring `var', replace
}

saveold "$ipa_cleaning/data/IPA_DATA_TO_ADD.dta", replace

/* PREPARE CKW SUBMISSIONS*/

clear
insheet using "$ckw_cleaning/raw/SubmissionCSV-NoStartDate-NoEndDate-NoStatus.csv"
gen ckw_mark = 1
// These are the same ones in "IPA DATA TO ADD" -- Joe submitted to the wrong database.
drop if ckwname=="Komakech Polycarp - 3 (IDEOS)"

saveold "$ckw_cleaning/data/ckw_submissions.dta",replace

/* UNITE!*/

clear
use "$ckw_cleaning/data/ckw_submissions.dta"
// Generate a variable the designates if a survey is IPA or CKW
gen IPA_CKW="CKW"
append using "$ipa_cleaning/data/ipa_submissions.dta"
append using "$ipa_cleaning/data/IPA_DATA_TO_ADD.dta"

// Changing those for CKWs
replace IPA_CKW="IPA" if IPA_CKW!="CKW"

saveold "$encrypted_data/data/all_submissions.dta",replace


/*********** STEP (2) ORGANIZE AND LABEL VARIABLE NAMES WITH SURVEY QUESTIONS *****************/
**************************************************************************************
**********************************    LABEL DATA  ************************************
**************************************************************************************

/***************
Author: Trina Gorman
Project: CKW (Rural Information - Uganda)
Purpose: Organizes data; labels variables and entries; Cleans up parish/village names for merging
***************/

/*********** ORGANIZING AND LABELLING VARIABLES ***********/

/* GENERATE SECTION BREAKS  */

gen INTRODUCTION = .
label var INTRODUCTION "=========="
move INTRODUCTION surveyid
gen DEMOGRAPHICS = .
label var DEMOGRAPHICS "=========="
move DEMOGRAPHICS info_module
gen HEALTH_SERVICES = .
label var HEALTH_SERVICES "=========="
move HEALTH_SERVICES health_serv_module
gen FINANCIAL_SERVICES = .
label var FINANCIAL_SERVICES "=========="
move FINANCIAL_SERVICES financial_module
gen HEALTH_PRODUCTS = .
label var HEALTH_PRODUCTS "=========="
move HEALTH_PRODUCTS health_prod_intro
gen FARMING = .
label var FARMING "=========="
move FARMING farming_module
gen SEEDLINGS = .
label var SEEDLINGS "=========="
move SEEDLINGS seedlings_module
gen RESEARCH = .
label var RESEARCH "=========="
move RESEARCH research_module
gen COOK_STOVES = .
label var COOK_STOVES "=========="
move COOK_STOVES cooking
gen HH_VERIFICATION = .
label var HH_VERIFICATION "=========="
move HH_VERIFICATION hh_verify
gen LET_THE_ANALYSIS_BEGIN = .
label var LET_THE_ANALYSIS_BEGIN "=========="


/* DROP TRANSITIONAL VARS FROM GRAMEEN'S PLATFORM */
#delimit;

drop interviewerintervieweedistance surveyid submissionlocation location market_transition
conf_reminder thank_you thankyou_2 turn_off age_of_child_1 age_of_child_2 age_of_child_3 age_of_child_4 age_of_child_5
age_of_child_6 age_of_child_7 age_of_child_8 age_of_child_9 age_of_child_10 age_of_child_11 age_of_child_12 age_of_child_13 age_of_child_14
age_of_child_15 age_of_child_16 age_of_child_17 age_of_child_18 age_of_child_19 before_transition
info_module health_serv_module health_prod_intro deworm_intro pan_intro ors_intro zinkid_intro market_module free financial_module
seedlings_module research_module hh_poss_module cooking hh_verify farming_module loan1_transition loan2_transition sacco_transition vsla_transition;

#delimit cr
foreach var of varlist _all {
	capture qui replace `var' = "." if `var'=="[No Answer]"
}

/* COMBINE NAMES INTO ONE VARIABLE  */

gen name= surname+" "+ first_name
move name surname
move IPA_CKW LET_THE_ANALYSIS_BEGIN
capture destring _all, replace

/* LABELING THE VARS AND ENTRIES */
ren amount_borrow_loan2 amount_borrowed_loan2
move what_is_the_childs_age_18 bio_children
move what_is_the_childs_age_19 bio_children
label var submissionid "Unique ID for the survey"
label var ckwname "Name of the enumerator or CKW"
label var date "Date of Interview"
label var time_begins "Time Interview Begins"
label var subcounty "Subcounty of Interview"
label var parish "Parish of Interview"
label var village "Village of Interview"
label var respondent_id "Respondent ID Number"
label var male "Respondent's Gender"
label var interview_alone "Is the interview conducted with resp alone?"
label var suspicious "Are you suspicious this wrong person? "
label var mental_state "Is resp in suitable mental state?"
move mental_other consent_signed
label var mental_other "Other comments about resp's mental state."
label var consent_signed "Has the resp signed informed consent?"
label var converstation "Before today, had you had convo with resp?"
label var related "Are you related to the resp?"
label var how_well_know "How well do you know the resp?"
label var get_along "Do you get along well with resp?"
label var rel_family "What is your relationship to family of resp?"
label var from_geo "Are you from, or live, close to resp?"
label var name "What first and surname?"
label var surname "21) What is your surname?"
label var first_name "22) What is your first name?"
label var nickname "23) Do you have a nickname?"
label var resp_age "24) How old are you?"
label var same_named_villager "24) Anyone in village have same name?"
label var same_villager_age "What is his/her age?"
label var hoh "26) Are you the HH?"
label var rel_hoh"27) What is your relationship to HH?"
label var name_hoh "28) What is the name of the HH?"
label var children_16 "29) Number children in HH 16 or below?"
label var childageintro "30) Nothing should be entered here - Introduction"
label var what_is_the_childs_age_1 "What is the child's age?"
label var what_is_the_childs_age_2 "What is the next child's age?"
label var what_is_the_childs_age_3 "What is the next child's age?"
label var what_is_the_childs_age_4 "What is the next child's age?"
label var what_is_the_childs_age_5 "What is the next child's age?"
label var what_is_the_childs_age_6 "What is the next child's age?"
label var what_is_the_childs_age_7 "What is the next child's age?"
label var what_is_the_childs_age_8 "What is the next child's age?"
label var what_is_the_childs_age_9 "What is the next child's age?"
label var what_is_the_childs_age_10 "What is the next child's age?"
label var what_is_the_childs_age_11 "What is the next child's age?"
label var what_is_the_childs_age_12 "What is the next child's age?"
label var what_is_the_childs_age_13 "What is the next child's age?"
label var what_is_the_childs_age_14 "What is the next child's age?"
label var what_is_the_childs_age_15 "What is the next child's age?"
label var what_is_the_childs_age_16 "What is the next child's age?"
label var what_is_the_childs_age_17 "What is the next child's age?"
label var what_is_the_childs_age_18 "What is the next child's age?"
label var what_is_the_childs_age_19 "What is the next child's age?"
label var bio_children "31) Do you have biological children?"
label var alive_children "32) How many alive bio children do you have?"
label var pregnant_since_2009 "33) Have you been preg since beg of 2009?"
label var times_pregnant "34) How many times pregnant since 2009?"
label var hc_visit_once "35) Visit clinic for pre/post natal care?"
label var rec_net_once "36) Receive a net from clinic?"
label var number_nets "37) How many nets received?"
label var use_net "Last night, someone sleep under net?"
label var why_no_slept "Why no one slept under net?"
label var slept_other "Enter reason noone slept under:"
label var deworm_used_2 "41) Has anyone in HH used deworm 2 years?"
label var deworm_used_6 "Has anyone in HH used deworm 6 months?"
label var deworm_house "Is there any deworming in this HH now?"
label var deworm_free "You/spouse received deworming for free?"
label var deworm_times "How many times deworming for free?"
label var pan_used_2 "42) Has anyone in your HH used Panadol in 2 years?"
label var pan_used_6 "Has anyone in your HH used Panadol in 6 months?"
label var pan_house "Is there any Panadol in this HH now?"
label var pan_free "You/spouse received Panadol for free?"
label var pan_free_times "How many times received Panadol free?"
label var ors_used_2 "43) Has anyone in HH used ORS 2 years?"
label var ors_used_6 "Has anyone in HH used ORS 6 months?"
label var or_hh "Is there any ORS in this HH right now?"
label var ors_free "You/spouse received ORS free?"
label var ors_free_times "How many times received ORS for free?"
label var z_used_2 "44) Has anyone in HH used Zinkid 2 years?"
label var z_used_6 "Has anyone in HH used Zinkid 6 months?"
label var z_hh "Is there any Zinkid  in this HH now?"
label var z_free "You/spouse received Zinkid free?"
label var z_free_times "How many times received Zinkid for free?"
label var market_approach "45) You/spouse approached by marketer?"
label var market_last "46) Last time marketer came?"
label var market_date "Enter the specific date:"
label var where_market "48) What org was this person from?"
label var market_org_other "Enter the other place the person from:"
label var market_purchase "49) Did you/spouse purchase?"
label var market_name "50) What did you/spouse purchase?"
label var other_prod_purch "Enter product purchased:"
label var product_used "51) Has some of product been used? (sell)"
label var amount_used "52) How much has been used? (sell)"
label var approached_free "54) You/spouse had someone offer free product ?"
label var market_last_free "55) When last time someone free at door?"
label var free_spec_date "Enter the specific date:"
label var free_products "56) What product did person give for free?"
label var namefreeproduct "Enter the name of the product:"
label var where_free "57) What org was this person from?"
label var nameorgfree "Enter the other organization:"
label var accept "58) Did you/spouse accept product?"
label var product_used_free "59) Has some of product been used? (free)"
label var amount_used_free "60) How much has been used? (free)"
label var condom "62) In 6 mos, received condom free?"
label var today_health_action "63) Today, buy products or free?"
label var today_health_org "64) Today, what orgs - NGOs/govt/forprofits??"
label var other_health_org "Enter other place where receive products:"
label var future_health_action "65) Future, buy or free?"
label var future_health_org "66) Future, what orgs - NGOs/govt/forprofits?"
label var other_health_org_future "Enter other place future receive products:"
label var member_vsla "67) Are you member of a VSLA/SACCO?"
label var vsla_groups "68) How many VSLAs member of?"
label var saccos_number "69) How many SACCOs member of?"
label var vsla_join "70) When join this VSLA?"
label var vsla_savings "Do you have savings with VSLA?"
label var vsla_deposit "How often deposit money with VSLA?"
label var vsla_deposit_other "Enter other frequency deposits money VSLA:"
label var sacco_date "71) When join SACCO?"
label var sacco_savings "Do you have savings with SACCO?"
label var sacco_deposit "How often do deposit money with SACCO?"
label var sacco_deposit_other "Enter other frequency deposits money SACCO:"
label var have_applied_loan "71) Ever applied loan from a VSLA/SACCO?"
label var have_denied_loan "72) Ever been denied loan?"
label var why_denied "74) Why were you denied?"
label var other_denial_reason "Enter other reason resp denied loan:"
label var taken_loans "75) Since 2010, taken loans VSLA/SACCO?"
label var number_loans "76) Number loans 2010 VSLA/SACCO?"
label var amount_borrowed_loan1 "77) Amount borrowed - 1st?"
label var total_loan1 "78) Amount pay back w interest - 1st?"
label var how_long_loan1 "79) How long to pay back - 1st?"
label var why_borrow_loan1 "80) Why did borrow - 1st?"
label var first_loan_reason "Enter other reason - 1st"
label var main_use_loan1 "81) Main thing used for - 1st?"
label var first_loan_used "Enter other reason - 1st"
label var amount_borrowed_loan2 "Amount borrowed - 2nd?"
label var total_loan2 "Amount pay back w interest - 2nd"
label var how_long_loan2 "How long to pay back - 2nd?"
label var main_reason_loan2 "Why did you borrow - 2nd?"
label var second_loan_reason "Enter other reason - 2nd"
label var main_use_loan2 "Main thing used for - 2nd?"
label var second_loan_used "Enter other reason - 2nd"
label var loan_3 "82) Amount 3rd loan since 2010?"
label var loan_4 "Amount 4th loan since 2010?"
label var loan_5 "Amount 5th loan since 2010?"
rename loan_3 amount_borrowed_loan3
rename loan_4 amount_borrowed_loan4
rename loan_5 amount_borrowed_loan5
label var sacco_sat "83) How satisfied been with SACCO service?"
label var member_of_group "84) Been member farm group since 2010?"
label var number_of_groups "85) Number groups since 2010?"
label var groups_supprted_by_ngo "86) Number groups supp by org since 2010?"
label var training "87) Orgs group training since 2010?"
label var group_inputs "Orgs given group inputs since 2010?"
label var personal_support "Orgs given personal inputs since 2010?"
label var received_seedlings "88) Seedlings from forestry since 2009?"
label var total_seeds "91) Number seedlings since 2009??"
label var successful_seeds "92) Number successful seedlings?"
label var heard_ckw "93) Before today, heard CKW?"
label var ckw_times "Before today, times CKW service (11=more than 10)?"
label var ckw_sat "94) Before today, sat level CKW?"
label var why_ckw "95) Why CKW sat"
label var researcher_times "96) Before today, times researcher? (11=more than 10)"
label var research_sat "97) Before today, sat level researchers?"
label var why_researcher "98) Why research sat"
label var bednets "99) Number bednets used last night?"
label var beddings "100) Number beddings do you have?"
label var chairs "101) Number chairs do you have?"
label var tables "102) Number tables do you have?"
label var stoves "103) Number stoves do you have?"
label var goats "104) Number goats do you have?"
label var chickens "105) Number chickens do you have?"
label var cows "106) Number cows do you have?"
label var bikes "107) Number bicycles do you own?"
label var type_stove "108) Kind of stove use?"
rename q184 type_stove_other
label var type_stove_other "Other type of stove:"
label var where_cook "109) Where do you cook?"
label var sleep_night "110) In cooking hut, anyone sleep night?"
label var sleep_day "112) In cooking hut, anyone sleep day?"
label var spend_time "114) Besides cook, people do anything in hut?"
label var better_stove "116) Heard about better stove?"
label var hh_consent "118) Permission to enter home?"
label var bednets_seen "How many bednets did you see?"
label var beddings_seen "How many beddings did you see?"
label var stoves_seen "How many stoves did you see?"
label var bikes_seen "How many bicycles did you see?"
label var goats_seen "How many goats did you see?"
label var time_ends "124) Time Interview Ended"
label var phone_number "125) Phone Number?"
label var gps "Capture the GPS coordinates of this location:"
label var IPA_CKW "Is this enumerator a CKW or from IPA?"
rename ckwname enumerator

// Now onto the multiple choice questions:
label var hc_name_once_1 "38) Received net Awach HC?"
label var hc_name_once_2 "38) Received net Bobi HC?"
label var hc_name_once_3 "38) Received net Lakwana Awoo HC?"
label var hc_name_once_4 "38) Received net Lakwana Lan-Ber HC?"
label var hc_name_once_5 "38) Received net Lalogi HC IV?"
label var hc_name_once_6 "38) Received net Lalogi Opit HC?"
label var hc_name_once_7 "38) Received net Laroo HC?"
label var hc_name_once_8 "38) Received net Ongako HC?"
label var hc_name_once_9 "38) Received net Odek HC?"
label var hc_name_once_10 "38) Received net Patiko HC?"
label var hc_name_once_11 "38) Received net Palaro Labw HC?"
label var hc_name_once_12 "38) Received net Piacho Kal-Alii HC?"
label var hc_name_once_13 "38) Received net - Other?"
label var hc_name_once_14 "38) Received net - Does not know?"
label var hc_other_names "Other clinic received nets:"
rename hc_name_once_1  hc_name_awach
rename hc_name_once_2  hc_name_bobi
rename hc_name_once_3  hc_name_lak_awoo
rename hc_name_once_4  hc_name_lak_laneno
rename hc_name_once_5  hc_name_lalogi
rename hc_name_once_6  hc_name_lalogi_opit
rename hc_name_once_7  hc_name_laroo
rename hc_name_once_8  hc_name_ongako
rename hc_name_once_9  hc_name_odek
rename hc_name_once_10  hc_name_patiko
rename hc_name_once_11  hc_name_palaro
rename hc_name_once_12  hc_name_paicho
rename hc_name_once_13  hc_name_other
rename hc_name_once_14  hc_name_doesnotknow
rename hc_other_names hcother_specify

label var market_products_1 "47) Did marketer sell Panadol?"
label var market_products_2 "47) Did marketer sell Deworming?"
label var market_products_3 "47) Did marketer sell ORS?"
label var market_products_4 "47) Did marketer sell Zinkid?"
label var market_products_5 "47) Did marketer sell Soap?"
label var market_products_6 "47) Did marketer sell Watergaurd?"
label var market_products_7 "47) Did marketer sell Aquasafe?"
label var market_products_8 "47) Did marketer sell Contraceptives?"
label var market_products_9 "47) Did marketer sell - Other?"
label var market_products_10 "47) Did marketer sell - Does not know?"
label var other_sell_product "What other drug did marketer sell?"
rename market_products_1  sell_prod_pan
rename market_products_2  sell_prod_deworm
rename market_products_3  sell_prod_ors
rename market_products_4  sell_prod_zinkid
rename market_products_5  sell_prod_soap
rename market_products_6  sell_prod_waterg
rename market_products_7  sell_prod_aquas
rename market_products_8  sell_prod_contra
rename market_products_9  sell_prod_other
rename market_products_10  sell_prod_doesnotknow
rename other_sell_product  sellother_specify

label var who_used_1 "53) Did children use drug? (sell)"
label var who_used_2 "53) Did adults use drug? (sell)"
label var who_used_3 "53) Did the elderly use drug? (sell)"
label var who_used_4 "53) Who used drug - Does Not Know (sell)"
rename who_used_1 sell_used_children
rename who_used_2 sell_used_adults
rename who_used_3 sell_used_elderly
rename who_used_4 sell_used_doesnotknow

label var who_used_free_1 "61) Did children use drug? (free)"
label var who_used_free_2 "61) Did adults use drug? (free)"
label var who_used_free_3 "61) Did the elderly use drug? (free)"
rename who_used_free_1 free_used_children
rename who_used_free_2 free_used_adults
rename who_used_free_3 free_used_elderly

label var what_inputs_1 "Group inputs 2010 - Tools?"
label var what_inputs_2 "Group inputs 2010 - Seeds?"
label var what_inputs_3 "Group inputs 2010 - Machinery?"
label var what_inputs_4 "Group inputs 2010 - Animals?"
label var what_inputs_5 "Group inputs 2010 - Storage Facility?"
label var what_inputs_6 "Group inputs 2010 - Money?"
label var what_inputs_7 "Group inputs 2010 - Other?"
label var other_inputs_group "Enter other inputs the resp received:"
rename what_inputs_1 grp_tools
rename what_inputs_2 grp_seeds
rename what_inputs_3 grp_machinery
rename what_inputs_4 grp_animals
rename what_inputs_5 grp_storage
rename what_inputs_6 grp_money
rename what_inputs_7 grp_other
rename other_inputs_group grpother_specify

label var what_personal_inputs_1 "Personal inputs 2010 - Tools?"
label var what_personal_inputs_2 "Personal inputs 2010 - Seeds?"
label var what_personal_inputs_3 "Personal inputs 2010 - Machinery?"
label var what_personal_inputs_4 "Personal inputs 2010 - Animals?"
label var what_personal_inputs_5 "Personal inputs 2010 - Storage Facility?"
label var what_personal_inputs_6 "Personal inputs 2010 - Money?"
label var what_personal_inputs_7 "Personal inputs 2010 - Other?"
label var other_inputs "Enter other personal inputs:"
rename what_personal_inputs_1 pers_tools
rename what_personal_inputs_2 pers_seeds
rename what_personal_inputs_3 pers_machinery
rename what_personal_inputs_4 pers_animals
rename what_personal_inputs_5 pers_storage
rename what_personal_inputs_6 pers_money
rename what_personal_inputs_7 pers_other
rename other_inputs persother_specify

label var names_of_supporting_org_1 "Did CARE give agric support 2010?"
label var names_of_supporting_org_2 "Did ACTED give agric support 2010?"
label var names_of_supporting_org_3 "Did NAADS give agric support 2010?"
label var names_of_supporting_org_4 "Did NRC give agric support 2010?"
label var names_of_supporting_org_5 "Did NUSAF give agric support 2010?"
label var names_of_supporting_org_6 "Did Gulu District Assoc give agric support 2010?"
label var names_of_supporting_org_7 "Did World Vision give agric support 2010?"
label var names_of_supporting_org_8 "Did AVSI give agric support 2010?"
label var names_of_supporting_org_9 "Did ACDI VOCA give agric support 2010?"
label var names_of_supporting_org_10 "Did DRC give agric support 2010?"
label var names_of_supporting_org_11 "Did Red Cross give agric support 2010?"
label var names_of_supporting_org_12 "Did Caritas give agric support 2010?"
label var names_of_supporting_org_13 "Did Action Fame give agric support 2010?"
label var names_of_supporting_org_14 "Did Other give agric support 2010?"
label var names_of_supporting_org_15 "Does not know name of agric supp org?"
label var other_org "Enter name of the other organization:"
rename names_of_supporting_org_1  supp_by_care
rename names_of_supporting_org_2  supp_by_acted
rename names_of_supporting_org_3  supp_by_naads
rename names_of_supporting_org_4  supp_by_nrc
rename names_of_supporting_org_5  supp_by_nusaf
rename names_of_supporting_org_6  supp_by_guludistfarm
rename names_of_supporting_org_7  supp_by_worldvision
rename names_of_supporting_org_8  supp_by_avsi
rename names_of_supporting_org_9  supp_by_acdivoca
rename names_of_supporting_org_10  supp_by_drc
rename names_of_supporting_org_11  supp_by_redcross
rename names_of_supporting_org_12  supp_by_caritas
rename names_of_supporting_org_13  supp_by_actionfame
rename names_of_supporting_org_14  supp_by_other
rename names_of_supporting_org_15  supp_by_doesnotknow
rename other_org suppother_specify

label var seedling_type_1 "89) Did receive Jackfruit?"
label var seedling_type_2 "89) Did receive Orange?"
label var seedling_type_3 "89) Did receive Mangoes?"
label var seedling_type_4 "89) Did receive Avocados?"
label var seedling_type_5 "89) Did receive Pine?"
label var seedling_type_6 "89) Did receive Citrus?"
label var seedling_type_7 "89) Did receive Eucalyptus?"
label var seedling_type_8 "89) Did receive Musisi?"
label var seedling_type_9 "89) Did receive Mahogany?"
label var seedling_type_10 "89) Did receive Teak?"
label var seedling_type_11 "89) Did receive another type?"
label var other_tree_type "Enter other type seedling:"
rename seedling_type_1 seed_jackfruit
rename seedling_type_2 seed_orange
rename seedling_type_3 seed_mangoes
rename seedling_type_4 seed_avacados
rename seedling_type_5 seed_pine
rename seedling_type_6 seed_citrus
rename seedling_type_7 seed_eucalyptus
rename seedling_type_8 seed_musisi
rename seedling_type_9 seed_mahogany
rename seedling_type_10 seed_teak
rename seedling_type_11 seed_other
rename other_tree_type seedother_specify

label var years_rec_seed_1 "90) Receive seedlings 2009?"
label var years_rec_seed_2 "90) Receive seedlings 2010?"
label var years_rec_seed_3 "90) Receive seedlings 2011?"
rename years_rec_seed_1 years_seed_2009
rename years_rec_seed_2 years_seed_2010
rename years_rec_seed_3 years_seed_2011

label var stove_sleeps_night_1 "111) Children sleep in hut - night?"
label var stove_sleeps_night_2 "111) Adults sleep in hut - night?"
label var stove_sleeps_night_3 "111) Elderly sleep in hut - night?"
rename stove_sleeps_night_1 sleeps_night_children
rename stove_sleeps_night_2 sleeps_night_adults
rename stove_sleeps_night_3 sleeps_night_elderly

label var stove_sleeps_day_1 "113) Children sleep in hut - day?"
label var stove_sleeps_day_2 "113) Adults sleep in hut - day?"
label var stove_sleeps_day_3 "113) Elderly sleep in hut - day?"
rename stove_sleeps_day_1 sleeps_day_children
rename stove_sleeps_day_2 sleeps_day_adults
rename stove_sleeps_day_3 sleeps_day_elderly

label var what_do_stove_hut_1 "115) People Socialize in cook hut? "
label var what_do_stove_hut_2 "115) People Play in cook hut? "
label var what_do_stove_hut_3 "115) People Sleep in cook hut? "
label var what_do_stove_hut_4 "115) People Shelter from Rain in cook hut? "
label var what_do_stove_hut_5 "115) People Work  in cook hut? "
label var what_do_stove_hut_6 "115) People do - other "
rename q189 whatdo_specify
label var whatdo_specify "Specify what else do in hut?"
rename what_do_stove_hut_1 what_do_socialize
rename what_do_stove_hut_2 what_do_play
rename what_do_stove_hut_3 what_do_sleep
rename what_do_stove_hut_4 what_do_shelter
rename what_do_stove_hut_5 what_do_work
rename what_do_stove_hut_6 what_do_other

label var who_hear_betstove_1 "117) Hear better stove - NGO? "
label var who_hear_betstove_2 "117) Hear better stove - Friend/Family? "
label var who_hear_betstove_3 "117) Hear better stove - Govt Official? "
label var who_hear_betstove_4 "117) Hear better stove - Radio? "
label var who_hear_betstove_5 "117) Hear better stove - Other? "
label var cook_hear_other "Enter where heard better stove:"
rename who_hear_betstove_1 hear_ngo
rename who_hear_betstove_2 hear_friend
rename who_hear_betstove_3 hear_govt
rename who_hear_betstove_4 hear_radio
rename who_hear_betstove_5 hear_other
rename cook_hear_other hearother_specify

/* LABELLING: Before Interview - Identification Module */

label define yes1no0 1 "1) Yes" 0 "0) No"
label define yes1no0dkn999 1 "1) Yes" 0 "0) No" -999 "-999) Does not know"

label define subcountyL 1 "1) Awach" 2 "2) Bobi" 3 "3) Lakwana" 4 "4) Lalogi" 5 "5) Laroo" 6 "6) Ongako" 7 "7) Odek" 8 "8) Patiko" 9 "9) Palaro" 10 "10) Paicho" 11 "11) Bungatira" 12 "12) Koro" 13 "13) Layibi"
label values subcounty subcountyL

label define maleL 1 "1) Male" 0 "0) Female"
label values male maleL

label values interview_alone yes1no0

label define suspiciousL 1 "1) No, not at all" 2 "2) A little suspicious" 3 "3) Very suspicious"
label values suspicious suspiciousL

label define mental_stateL 1 "1) Yes" 2 "2) No, intoxicated" 3 "3) No, mentally impaired" 4 "4) No, in pain" 5 "5) No, other" -996 "-996) Other"
label values mental_state mental_stateL

label values consent_signed yes1no0
label values converstation yes1no0
rename converstation conversation
label values related yes1no0

label define how_well_knowL 1 "1) I do not know" 2 "2) I know who is" 3 "3) Person is acquaintance" 4 "4) I know fair amount" 5 "5) I know very well"
label values how_well_know how_well_knowL

tab get_along
// Binding was 998 but I don't like it
replace get_along=2 if get_along==998
label define get_alongL 0 "0) No" 1 "1) Yes" 2 "2) I prefer not to answer"
label values get_along get_alongL

label define rel_familyL 1 "1) I do not know them" 2 "2) I know about them" 3 "3) They are aquaintance" 4 "4) I know fair amount" 5 "5) I know very well"
label values rel_family rel_familyL

label define from_geoL 1 "1) Yes, same subcounty" 2 "2) Yes, same parish" 3 "3) Yes, same village" 4 "4) No"
label values from_geo from_geoL

/* LABELLING: Respondent Information Module */

label values same_named_villager yes1no0dkn999
label values hoh yes1no0

label define rel_hohL 1 "First wife" 2 "Husband" 3 "Son or daughter" 4 "Parent" 5 "Grandparent" 6 "Brother or sister" 7 "Uncle or aunt" 8 "Cousin" 9 "Grandchild" 10 "Sister-in-law" 15 "Brother-in-law" 11 "Nephew or niece" 12 "Boyfriend/Girlfriend" 13 "Other (related)" 14 "Other (Non-related)"
label values rel_hoh rel_hohL

/* LABELLING: Health Services Module */

label values bio_children yes1no0
label values pregnant_since_2009 yes1no0
label values hc_visit_once yes1no0
label values rec_net_once yes1no0

// Grameen's platform uses my binding instead of a 1 for multiple choice binaries. I'm changing all entries where the person chose that binary answer to be a 1 instead of a 1,2,3,-999, etc as it is now
foreach var of varlist hc_name_* {
	qui replace `var'=1 if `var'!=.
}

label values use_net yes1no0dkn999

// Forgot the minus
replace why_no_slept=-996 if why_no_slept==996
label define why_no_sleptL 1 "1) Lost or stolen" 2 "2) Used for another purpose." 3 "3) It is uncomfortable" 4 "4) Saving it" 5 "5) It is old" -996 "-996) Other"
label values why_no_slept why_no_sleptL

/* LABELLING: Health Products Module */

label values deworm_used_2 yes1no0dkn999
label values deworm_used_6 yes1no0dkn999
label values deworm_house yes1no0
label values deworm_free yes1no0dkn999

label define deworm_timesL 1 "1) 1-3 times" 2 "2) 4-7 times" 3 "3) 8-10 times" 4 "4) More than 10 times" -999 "-999) Does not know"
label values deworm_times deworm_timesL
label values pan_used_2 yes1no0dkn999
// No was 2, oops
replace pan_used_6=0 if pan_used_6==2
label values pan_used_6 yes1no0dkn999
label values pan_house yes1no0
label values pan_free yes1no0dkn999

label define pan_free_timesL 1 "1) 1-3 times" 2 "2) 4-7 times" 3 "3) 8-10 times" 4 "4) More than 10 times" -999 "-999) Does not know"
label values pan_free_times pan_free_timesL

// Used 996 for Does Not Know
replace ors_used_2=-999 if ors_used_2==-996
label values ors_used_2 yes1no0dkn999
label values ors_used_6 yes1no0
label values or_hh yes1no0
label values ors_free yes1no0

label define ors_free_timesL 1 "1) 1-3 times" 2 "2) 4-7 times" 3 "3) 8-10 times" 4 "4) More than 10 times" -999 "-999) Does not know"
label values ors_free_times ors_free_timesL

// Used 996 for Does Not Know
replace z_used_2=-999 if z_used_2==-996
label values z_used_2 yes1no0dkn999
label values z_used_6 yes1no0dkn999
label values z_hh yes1no0
label values z_free yes1no0

label define z_free_timesL 1 "1) 1-3 times" 2 "2) 4-7 times" 3 "3) 8-10 times" 4 "4) More than 10 times" -999 "-999) Does not know"
label values z_free_times z_free_timesL

/* LABELLING: Sell Module */

label values market_approach yes1no0dkn999

label define market_lastL 1 "1) 2 weeks ago or less" 2 "2) 3-4 weeks ago" 3 "3) 5-7 weeks ago" 4 "4) 2-3 months ago" 5 "5) 4-5 months ago" 6 "6) 6 months ago+" 7 "7) Specific date" -999 "-999) Does not know"
label values market_last market_lastL

// Grameen's platform uses my binding instead of a 1 for multiple choice dummys. Instead of the binding, I want a 1 when the respondent chose this answer
foreach var of varlist free_used_* sell_used_* sell_prod_* {
	qui replace `var'=1 if `var'!=.
}


label define where_marketL 1 "1) NGO" 2 "2) For profit" 3 "3) Government HC" 4 "4) Village health team" 5 "5) LC1" -996 "-996) Other" -999 "-999) Does not know"
label values where_market where_marketL

tab market_purchase
// No was 2, oops.
replace market_purchase=0 if market_purchase==2
label values market_purchase yes1no0dkn999

label define market_nameL 1 "1) Panadol" 2 "2) Deworming" 3 "3) ORS" 4 "4) Zinkid" 5 "5) Soap" 6 "6) Watergaurd" 7 "7) Aquasafe" 8 "8) Contraceptrives" -996 "-996) Other" -999 "-999) Does not know"
label values market_name market_nameL

// No was 2, oops.
replace product_used=0 if product_used==2
label values product_used yes1no0dkn999

label define amount_usedL 1 "1) Less than 1/4" 2 "2) About 1/4" 3 "3) About 1/2 " 4 "4) About 3/4" 5 "5) All" -999 "-999) Does not know"
label values amount_used amount_usedL

label values approached_free yes1no0

label define market_last_freeL 1 "1) 2 weeks ago or less" 2 "2) 3-4 weeks ago" 3 "3) 5-7 weeks ago" 4 "4) 2-3 months ago" 5 "5) 4-5 months ago" 6 "6) 6 months ago or longer" 7 "7) Specific date" -999 "-999) Does not know"
label values market_last_free market_last_freeL

label define free_productsL 1 "1) Panadol" 2 "2) Deworming" 3 "3) ORS" 4 "4) Zinkid" 5 "5) Soap" 6 "6) Watergaurd" 7 "7) Aquasafe" 8 "8) Contraceptrives " -996 "-996) Other" -999 "-999) Does not know"
label values free_products free_productsL

label define where_freeL 1 "1) NGO" 2 "2) For profit" 3 "3) Government health center" 4 "4) Village health team" 5 "5) LC1" -996 "-996) Other" -999 "-999) Does not know"
label values where_free where_freeL

label values accept yes1no0
label values product_used_free yes1no0

label define amount_used_freeL 1 "1) Less than 1/4" 2 "2) About 1/4" 3 "3) About 1/2" 4 "4) About 3/4" 5 "5) All" -999 "-999) Does not know"
label values amount_used_free amount_used_freeL

tab condom
replace condom=2 if condom==-998
label define condomL 0 "0) No" 1 "1) Yes" 2 "2) Prefers to not answer" -999 "-999) Does not know"
label values condom condomL

label define today_health_actionL 1 "1) Typically buys" 2 "2) Typically gets free"
label values today_health_action today_health_actionL

label define today_health_orgL 1 "1) NGOs or village health team" 2 "2) For profits" 3 "3) Government" -996 "-996) Other"
label values today_health_org today_health_orgL

label define future_health_actionL 1 "1) Expects buy" 2 "2) Expects get free"
label values future_health_action future_health_actionL

label define future_health_orgL 1 "1) NGOs or village health team" 2 "2) For profits" 3 "3) Government" -996 "-996) Other"
label values future_health_org future_health_orgL

/* LABELLING: Financial Services Module */

label define member_vslaL 0 "0) No" 1 "1) Yes, VSLA" 2 "2) Yes, SACCO" 3 "3) Yes, VSLA and SACCO"
label values member_vsla member_vslaL

replace vsla_savings=0 if vsla_savings==2
label values vsla_savings yes1no0dkn999

replace vsla_deposit=-996 if vsla_deposit==996
label define vsla_depositL 1 "1) Daily" 2 "2) Once a week" 3 "3) Twice a week" 4 "4) Once a month" 5 "5) Once a year" 6 "6) As desired" -999 "-999) Does not know" -996 "-996) Other"
label values vsla_deposit vsla_depositL

// no was 2
replace sacco_savings=0 if sacco_savings==2
label values sacco_savings yes1no0dkn999

label define sacco_depositL 1 "1) Daily" 2 "2) Once a week" 3 "3) Twice a week" 4 "4) Once a month" 5 "5) Once a year" 6 "6) As desired" -999 "-999) Does not know" -996 "-996) Other"
label values sacco_deposit sacco_depositL

/* LABELLING: Borrowing Module */

// No was 2
replace have_applied_loan=0 if have_applied_loan==2
label values have_applied_loan yes1no0

// No was 2
replace have_denied_loan=0 if have_denied_loan==2
label values have_denied_loan yes1no0

tab why_denied
// Just following numbering
replace why_denied=4 if why_denied==6
// Just following conventions for other
replace why_denied=-996 if why_denied==5
label define why_deniedL 1 "1) Not enough funds available" 2 "2) I didn't have collateral" 3 "3) I was not eligible" 4 "4) I asked too much $" -996 "-996) Other" -999 "-999) Does not know"
label values why_denied why_deniedL

// No was 3, not sure why
replace taken_loans=0 if taken_loans==3
label values taken_loans yes1no0

label define how_long_loan1L 1 "1) 1 week" 2 "2) 2 weeks" 3 "3) 3 weeks" 4 "4) 4 weeks" 5 "5) 1-2 month" 6 "6) 3-4 months" 7 "7) 5-6 months" 8 "8) 7-8 months" 9 "9) 9 months or longer"
label values how_long_loan1 how_long_loan1L

// Other was 10
replace why_borrow_loan1=-996 if why_borrow_loan1==10
// Loan to another was 11 - don't want to skip
replace why_borrow_loan1=10 if why_borrow_loan1==11
label define why_borrow_loan1L 1 "1) Pay for a child's educ" 2 "2) Pay emergency" 3 "3) Invest own business/garden" 4 "4) Invest other business/garden" 5 "5) Buy non-essentials" 6 "6) Basic needs" 7 "7) Household possessions" 8 "8) Home improvement" 9 "9) Health related" 10 "10) Loan it another" -996 "-996) Other"
label values why_borrow_loan1 why_borrow_loan1L

// Other was 10
replace main_use_loan1=-996 if main_use_loan1==10
// Loan to another was 11 - don't want to skip
replace main_use_loan1=10 if main_use_loan1==11
label define main_use_loan1L 1 "1) Pay for child's educ" 2 "2) Pay emergency" 3 "3) Invest own business/garden" 4 "4) Invest other's business/garden" 5 "5) Buy non-essentials" 6 "6) Basic needs" 7 "7) Household possessions" 8 "8) Home improvement" 9 "9) Health related" 10 "10) Loan it another" -996 "-996) Other"
label values main_use_loan1 main_use_loan1L

label define how_long_loan2L 1 "1) 1 week" 2 "2) 2 weeks" 3 "3) 3 weeks" 4 "4) 4 weeks" 5 "5) 1-2 month" 6 "6) 3-4 months" 7 "7) 5-6 months" 8 "8) 7-8 months" 9 "9) 9 months or longer"
label values how_long_loan2 how_long_loan2L

// Other was 10
replace main_reason_loan2=-996 if main_reason_loan2==10
// Loan to another was 11 - don't want to skip
replace main_reason_loan2=10 if main_reason_loan2==11
label define main_reason_loan2L 1 "1) Pay for child's educ" 2 "2) Pay emergency" 3 "3) Invest own business/garden" 4 "4) Invest other's business/garden" 5 "5) Buy non-essentials" 6 "6) Basic needs" 7 "7) Household possessions" 8 "8) Home improvement" 9 "9) Health related" 10 "10) Loan it another" -996 "-996) Other"
label values main_reason_loan2 main_reason_loan2L

// Other was 11, Loan was correct at 10
replace main_use_loan2=-996 if main_use_loan2==11
label define main_use_loan2L 1 "1) Pay for child's educ" 2 "2) Pay emergency" 3 "3) Invest own business/garden" 4 "4) Invest other's business/garden" 5 "5) Buy non-essentials" 6 "6) Basic needs" 7 "7) Household possessions" 8 "8) Home improvement" 9 "9) Health related" 10 "10) Loan it another" -996 "-996) Other"
label values main_use_loan2 main_use_loan2L

label define sacco_satL 1 "1) Not at all sat" 2 "2) Moderately unsat" 3 "3) Neither sat/unsat" 4 "4) Moderately sat" 5 "5) Very sat"
label values sacco_sat sacco_satL

/* LABELLING: Farming Module */

// No was 2
replace member_of_group=0 if member_of_group==2
label values member_of_group yes1no0

// I need to fix the numbers so this can be analyzed - my bindings were off. This makes the number entered the number of groups.
replace groups_supprted_by_ngo=0 if groups_supprted_by_ngo==4
replace groups_supprted_by_ngo=4 if groups_supprted_by_ngo==5
replace groups_supprted_by_ngo=5 if groups_supprted_by_ngo==6

label values training yes1no0
label values group_inputs yes1no0

// Grameen's platform uses my binding instead of a 1 for multiple choice dummys. Instead of the binding, I want a 1 when the respondent chose this answer
foreach var of varlist grp_* pers_* supp_by_* {
	qui replace `var'=1 if `var'!=.
}

tab personal_support
// No was 2
replace personal_support=0 if personal_support==2
label values personal_support yes1no0

/* LABELLING: Seedling Module */

// 2 was No
replace received_seedlings=0 if received_seedlings==2
label values received_seedlings yes1no0

// Grameen's platform uses my binding instead of a 1 for multiple choice dummys. Instead of the binding, I want a 1 when the respondent chose this answer
foreach var of varlist seed_* years_seed_* {
	qui replace `var'=1 if `var'!=.
}

/* LABELLING: Research Experience Module */
replace heard_ckw=0 if heard_ckw==2
label values heard_ckw yes1no0

label define ckw_timesL 1 "1" 2 "2" 3 "3" 4 "4" 5 "5" 6 "6" 7 "7" 8 "8" 9 "9" 10 "10" 11 "11) More than 10"
label values ckw_times ckw_timesL

// zero was 12
replace researcher_times=0 if researcher_times==12
label define researcher_timesL 0 "0" 1 "1" 2 "2" 3 "3" 4 "4" 5 "5" 6 "6" 7 "7" 8 "8" 9 "9" 10 "10" 11 "11) More than 10"
label values researcher_times researcher_timesL

// 996 should stand for OTHER always.
replace ckw_sat=-999 if ckw_sat==-996
label define ckw_satL 1 "1) Not at all sat" 2 "2) Moderately unsat" 3 "3) Neither sat/unsat" 4 "4) Moderately sat" 5 "5) Very sat" -999 "-999) Does not know"
label values ckw_sat ckw_satL

// 996 should stand for OTHER always.
replace research_sat=-999 if research_sat==-996
label define research_satL 1 "1) Not at all sat" 2 "2) Moderately unsat" 3 "3) Neither sat/unsat" 4 "4) Moderately sat" 5 "5) Very sat" -999 "-999) Does not know"
label values research_sat research_satL

/* LABELLING: Cook Stove Module */
// Other was 5, making consistent
replace type_stove=-996 if type_stove==5
label define type_stoveL 1 "1) Local fix / traditional" 2 "2) Round portable clay" 3 "3) Permanent energy saver" 4 "4) Metallic energy saver" -996 "-996) Other"
label values type_stove type_stoveL

label define where_cookL 1 "1) Always outdoors" 2 "2) Sometimes in/out" 3 "3) Always indoors"
label values where_cook where_cookL

// No was 2
replace sleep_night=0 if sleep_night==2
label values sleep_night yes1no0

// No was 2
replace sleep_day=0 if sleep_day==2
label values sleep_day yes1no0

// No was 2
replace spend_time=0 if spend_time==2
label values spend_time yes1no0

// No was 2
replace better_stove=0 if better_stove==2
label values better_stove yes1no0

// Grameen's platform uses my binding instead of a 1 for multiple choice dummys. Instead of the binding, I want a 1 when the respondent chose this answer
foreach var of varlist sleeps_night_* sleeps_day_* what_do_* hear_*  {
	qui replace `var'=1 if `var'!=.
}

/* LABELLING: Household Verification Module */

label define hh_consentL 1 "1) Yes" 2 "2) No, refused" 3 "3) No, can't reach home"
label values hh_consent hh_consentL
// Need to format phone numbers to keep precision/ability to view
format phone_number %9.0f

/* LABELLING: Making Other/Don'tKnow Consistent */

// These are all of those that I know have -999 in them:
foreach var of varlist same_named_villager use_net deworm_used_2 deworm_used_6 deworm_free pan_used_2 pan_used_6 pan_free ors_used_2 z_used_2 z_used_6 market_approach market_purchase product_used vsla_savings sacco_savings deworm_times pan_free_times ors_free_times z_free_times market_last where_market market_name amount_used market_last_free free_products where_free amount_used_free condom vsla_deposit sacco_deposit why_denied ckw_sat research_sat {
	// The following statement says if you can confirm that the variable is a string, take the first action, otherwise do the next set of brackets
	capture confirm string variable `var'

	if !_rc {
		replace `var' = ".d" if `var'=="-999"
		replace `var' = ".o" if `var'=="-996"
	}

	else {
		replace `var' = .d if `var'==-999
		replace `var' = .o if `var'==-996
	}
}
// These are all of those that I
foreach var of varlist why_no_slept today_health_org future_health_org why_borrow_loan1 main_use_loan1 main_reason_loan2 main_use_loan2 type_stove {
	// The following statement says if you can confirm that the variable is a string, take the first action, otherwise do the next set of brackets
	capture confirm string variable `var'

	if !_rc {
		replace `var' = ".d" if `var'=="-999"
		replace `var' = ".o" if `var'=="-996"
	}

	else {
		replace `var' = .d if `var'==-999
		replace `var' = .o if `var'==-996
	}
}


/* CLEANING UP NAMES, VILLAGE NAMES, AND PARISH NAMES FOR BOTH IPA AND CKW */

// Replace these names to lower case for easier merging later
replace name=lower(name)
replace village=lower(village)
replace parish=lower(parish)

// Get rid of funky punctuation
// This replaces all instances of "," in newcaste with "":
replace name=subinstr(name,"(","",1)
replace name=subinstr(name,")","",1)
replace name=subinstr(name,"-","",1)
replace name=subinstr(name,"'","",1)
replace name=subinstr(name,".","",1)
replace village=subinstr(village,"-","",1)
replace village=subinstr(village," ","",1)
replace parish=subinstr(parish,"-","",1)
replace parish=subinstr(parish," ","",1)

// Clean village names
replace village = "kitimotima" if village=="kitinotima"
replace village = "laminokure1" if village=="laminokure"
replace village = "teolam" if village=="teeolam"
replace village = "olee (omel a)" if village=="olee"
replace village = "abolle" if village=="bolle"
replace village="awimon" if village=="awiimon"
replace village="owak" if village=="0wak"
replace village = "obwobo" if village=="Obwobo"
replace village = "abolle" if village=="abole"
replace village = "abwoch" if village=="abwochkal"
replace village = "acutomer" if village=="acutmer"
replace village = "acutomer" if village=="acutomerl"
replace village = "aitakonyakiting" if village=="aitakony kiting"
replace village = "aitakonyakiting" if village=="aitakonya kiting"
replace village = "aitakonyakiting" if village=="aitakonyakiting."
replace village = "aitakonyakiting" if village=="aitakonyali ting"
replace village = "aitakonyakiting" if village=="aitamonths kiting"
replace village = "onyayorwot" if village=="anyayorwot"
replace village = "anyomotwon" if village=="anyomotowon"
replace village = "awalkok" if village=="awalkol"
replace village = "awimon" if village=="awmon"
replace village = "barlimo" if village=="baralimo"
replace village = "bolipi" if village=="bolipii"
replace village = "kuluotit" if village=="kulluotit"
replace village = "kuluotit" if village=="kulutit"
replace village = "omela" if village=="omela."
replace village = "omela" if village=="omelet.a"
replace village = "onekdyel" if village=="onekddyel"
replace village = "onyayorwot" if village=="onyeyorwot"
replace village = "aitakonyakiting" if village=="sitskonya kiting"
replace village = "aitakonyakiting" if village=="sitskonya kitng"
replace village = "aitakonyakiting" if village=="aitakonyaki ting"
replace village = "teolam" if village=="teolam."
replace village = "teopokcentral" if village=="teopok central"
replace village = "teopokcentral" if village=="teopkok central"
replace village = "tradingcentrekalamoma" if village=="tradingcentre kalamoma"
replace village = "tulaliya" if village=="tulalaya"
replace village = "tulaliya" if village=="tulalalya"
replace village = "twonokun" if village=="twon o kun"
replace village = "twonokun" if village=="twono kun"
replace village = "twonokun" if village=="twon okun"
replace village = "wiiaworanga" if village=="wiiawaranga"
replace village = "wiiaworanga" if village=="wiiworanga"
replace village = "arutcentral" if village=="arutcentra"
replace village = "oguru" if village=="pukonyoguru"
replace village = "oratido" if village=="oradito"
replace village = "oratido" if village=="oradido"

// Clean parish names
replace parish = "laliya" if parish=="Laliya"
replace parish = "abwoch" if parish=="abeoch"
replace parish = "abwoch" if parish=="abwoh"
replace parish = "atiabar" if parish=="atiabr"
replace parish = "atiabar" if parish=="atisbar"
replace parish = "gwendiya" if parish=="gwengdiya"
replace parish = "gwendiya" if parish=="gweng diya"
replace parish = "ibakara" if parish=="ibakaraq"
replace parish = "kalalii" if parish=="kalali"
replace parish = "kalalii" if parish=="kalall."
replace parish = "kalalii" if parish=="kalalii."
replace parish = "lapainateast" if parish=="laipanateast"
replace parish = "lapainateast" if parish=="laipaneteast"
replace parish = "lujorongole" if parish=="lujoronge"
replace parish = "lujorongole" if parish=="lujoronge"
replace parish = "lukwir" if parish=="lukkwir"
replace parish = "paidwe" if parish=="paidew"
replace parish = "paidwe" if parish=="paidwd"
replace parish = "pugwinyi" if parish=="puginyi"
replace parish = "pugwinyi" if parish=="pugwiny"
replace parish = "pugwinyi" if parish=="pungwingi"
replace parish = "pugwinyi" if parish=="pungwinyi"
replace parish = "pugwinyi" if parish=="pungwini"
replace parish = "atiabar" if parish=="stiabar"
replace parish="laliya" if parish=="laliyabungatira"
replace parish="laliya" if parish=="laliyaoguru"

saveold "$encrypted_data/data/all_submissions.dta",replace

/************ STEP (3) CORRECT DATA FROM SCRUTINY AND BACKCHECKS ********************************/
**************************************************************************************
****************************    CORRECT IPA SUBMISSIONS  **************************
**************************************************************************************

/***************
Author: Trina Gorman
Project: CKW (Rural Information - Uganda)
Purpose: Corrects mistakes or inaccuracies in IPA's submitted data -- many to ensure merge works correctly
***************/

/* REASSIGNING WHEN SWITCHED PHONES */

// 8 October
replace enumerator = "Angom Evelyn - 2 (Black and Teal)" if submissionid==37078
replace enumerator = "Angom Evelyn - 2 (Black and Teal)" if submissionid==37076
replace enumerator = "Angom Evelyn - 2 (Black and Teal)" if submissionid==37080
replace enumerator = "Angom Evelyn - 2 (Black and Teal)" if submissionid==37077
replace enumerator = "Angom Evelyn - 2 (Black and Teal)" if submissionid==37079

// From Joe's that he submitted to the CKW database (on Polycarp's phone)
replace enumerator = "Karic Joe - 4 (White)" if submissionid==37154
replace enumerator = "Karic Joe - 4 (White)" if submissionid==37155
replace enumerator = "Karic Joe - 4 (White)" if submissionid==37156
replace enumerator = "Karic Joe - 4 (White)" if submissionid==37157
replace enumerator = "Karic Joe - 4 (White)" if submissionid==37158
replace enumerator = "Karic Joe - 4 (White)" if submissionid==37159
replace enumerator = "Karic Joe - 4 (White)" if submissionid==37160
replace enumerator = "Karic Joe - 4 (White)" if submissionid==37161
replace enumerator = "Karic Joe - 4 (White)" if submissionid==37162
replace enumerator = "Karic Joe - 4 (White)" if submissionid==37163
replace enumerator = "Karic Joe - 4 (White)" if submissionid==37164
replace enumerator = "Karic Joe - 4 (White)" if submissionid==37165

// Same for Joe just before he quit
replace enumerator = "Karic Joe - 4 (White)" if submissionid==38202
replace enumerator = "Karic Joe - 4 (White)" if submissionid==38201
replace enumerator = "Karic Joe - 4 (White)" if submissionid==38204
replace enumerator = "Karic Joe - 4 (White)" if submissionid==38205
replace enumerator = "Karic Joe - 4 (White)" if submissionid==38203

// Eunice's phone hiccuped while spot checking with Polycarp
replace enumerator = "Laker Eunice - 8 (Grey Front)" if submissionid==38665
replace enumerator = "Laker Eunice - 8 (Grey Front)" if submissionid==38685
replace enumerator = "Laker Eunice - 8 (Grey Front)" if submissionid==38666

// Irene and Eunice switched phones for two days
replace enumerator = "Laker Eunice - 8 (Grey Front)" if enumerator == "Acayo Irene Odoki - 7 (Dark Grey)" & village=="dwere"
replace enumerator = "Laker Eunice - 8 (Grey Front)" if enumerator == "Acayo Irene Odoki - 7 (Dark Grey)" & village=="bolipi"
replace enumerator = "Acayo Irene Odoki - 7 (Dark Grey)" if enumerator == "Laker Eunice - 8 (Grey Front)" & village=="laban"
replace enumerator = "Acayo Irene Odoki - 7 (Dark Grey)" if enumerator == "Laker Eunice - 8 (Grey Front)" & village=="twonokun"

// Clean up enumerator names
replace enumerator = "Laker Eunice (IPA)" if enumerator == "Laker Eunice - 8 (Grey Front)"
replace enumerator = "Acayo Irene Odoki (IPA)" if enumerator == "Acayo Irene Odoki - 7 (Dark Grey)"
replace enumerator = "Karic Joe (IPA)" if enumerator == "Karic Joe - 4 (White)"
replace enumerator = "Angom Evelyn (IPA)" if enumerator == "Angom Evelyn - 2 (Black and Teal)"
replace enumerator = "Oneka Brian (IPA)" if enumerator == "Oneka Brian - 4 (White)"
replace enumerator = "Ogonya Emmanuel (IPA)" if enumerator == "Ogonya Emmanuel - 1 (Black and Teal)"
replace enumerator = "Lanyero Concy (IPA)" if enumerator == "Lanyero Concy - 6 (Crazy B/W)"

/* FIXING WHEN ENUM ENTERED AGE IN CHILD AGE INTRO */

/* Note: Trina is taking these out after discussion about how I should not clean
// Moving ages to next available child
replace  what_is_the_childs_age_2=1 if submissionid==42124
replace  what_is_the_childs_age_5=13 if submissionid==35436
replace  what_is_the_childs_age_6=3 if submissionid==34112
replace  what_is_the_childs_age_2=2 if submissionid==34110
replace  what_is_the_childs_age_4=3 if submissionid==34111
replace  what_is_the_childs_age_1=3 if submissionid==34719
replace childageintro="." if submissionid==42124 | submissionid==35436 | submissionid==34112 | submissionid==34110| submissionid==34111 | submissionid==34719
*/

/* I told my enumerators to enter 999 if they accidentally added a child group
foreach var of varlist what_is_the_childs* {
qui replace `var'=. if `var'==999
}

foreach var of varlist what_is_the_childs* {
qui replace `var'=. if `var'==9999
}

*/
/* FIXING TYPOS IN NAMES/VILLAGES PER RECLINK RESULTS TO FACILITATE MERGE */
// Fixing after reconciling
replace surname = "omara" if submissionid==35404
// Fixing after reconciling
replace surname = "oloya" if submissionid==35283
// Fixing after reconciling
replace surname = "okello" if submissionid==36360
// Emma mistake
replace respondent_id = 26 if submissionid==36792
// Fixing after reconciling
replace first_name = "charles (opio)" if submissionid==35619
// Fixing after reconciling
replace first_name = "molkene (charles)" if submissionid==36032

// Typo by enum (had put xxx)
replace name = "adiyo atoyo" if submissionid==43378
// Typo by enum - had put opiya (Irene)
replace name = "apiya patrick" if submissionid==45258
// Typo by enum - used zero instead of O.
replace name = "opoka teresio" if submissionid==34408
// The match isn't working -- the enum entered 15 for surname and the other names matched.
replace name = "oryem tibiri" if submissionid==47636
// The enumerator entered a zero instead of an O.
replace name = "oloya christine" if submissionid==35283

// Entered the parish name
replace village = "obwobo" if submissionid==34410
// Entered 1140 (time). Bargh.
replace village = "Obwobo" if submissionid==34409
// Concy's mistake
replace village = "Obwobo" if submissionid==34595
// Error -- entered "Dire"
replace village = "dika" if submissionid==36022
// Emma's mistake - he put parish into village
replace village = "atyang " if submissionid==39247
// Typo by enum
replace village = "lamin lupabo" if submissionid==39596

// Emma's mistake - he put sc into parish
replace parish = "lujorongole " if submissionid==39247
// Enum typed the time
replace parish = "lukwor" if submissionid==46135
// Entered SC name.
replace parish = "laliya" if submissionid==34410

// Fixing after reconciling
replace subcounty = 11 if submissionid==36950
// Fixing after reconciling - Bobi
replace subcounty =2 if submissionid==36448

/* FIXING RESPONDENT IDs PER RECLINK  */

// Fixing after reconciling
replace respondent_id=2 if submissionid==36950
// I had copied 35 in from Adam when it should be 36
replace respondent_id=36 if submissionid==36640
// Fixing after reconciling
replace respondent_id=16 if submissionid==36642
replace respondent_id=1 if submissionid==38657
// Enum entered 999
replace respondent_id=29 if submissionid==44588
// Brian's mistake
replace respondent_id= 126 if submissionid==44343
replace respondent_id=105 if submissionid==41065
replace respondent_id=2 if submissionid==40586
replace respondent_id=123 if submissionid==39830
// There were two people with the same name, and this age matches (changing from 2)
replace respondent_id=17 if submissionid==47637
// I screwed up the ID in handoff so now fixing to match true data (Bednet name)
replace respondent_id=124 if submissionid==44127
// Enum entered 109. akera florence	PAICHO	omel	olee (omel a)
replace respondent_id=111 if submissionid==48956
// Enum entered 11 in Te Olam
replace respondent_id=4 if submissionid==48094
// Enum entered 104. C'mon guys. Sloppy.
replace respondent_id=102 if submissionid==48985
// Obol Benjamin - Joe entered 217 incorrectly.
replace respondent_id=207 if submissionid==37155
// Irene entered 9 when it should be 5 for Okot Mark
replace respondent_id=5 if submissionid==53991
// Owiny John - There were two in Adam's data with two different IDs. I had told Eunice to use 25, but Adam used 34.
replace respondent_id=34 if submissionid==35950
// Eunice entered 100 when she didn't have the form
replace respondent_id=33 if submissionid==46584
// Enum entered 42
replace respondent_id=46 if submissionid==46981
// The enumerator entered 15 instead.
replace respondent_id=22 if submissionid==53351

// Tracking these errors
generate wrong_id_by_enum = .
label var wrong_id_by_enum "1=Enumerator entered wrong ID"
local wrong_id_by_ipa "36792 37155  36950 36642 38657 44588 44343  41065 40586 39830 48956 48985 53991 46584 46981 53351"
foreach x of local wrong_id_by_ipa {
	replace wrong_id_by_enum = 1 if submissionid==`x'
}


// Fixing Ids in Ajanyi to match D2D data

// Ayoo Nancy - Changed from 017 to: 1848199025. ID: 42460
replace respondent_id=25 if submissionid==42460
// Lawino Florence - Changed from 020 to: 1848199030. ID: 42462
replace respondent_id=30 if submissionid==42462
// Margaret Komakech. This was a match but should not be with Adam - I think Stephen copied them in wrong.
replace respondent_id=202 if submissionid==36593
// Akumu Richard - Stephen's copy error. Changing to match
replace respondent_id=104 if submissionid==44917
// Patricia was matching with Adam but should not - he changed IDs after I grabbed them. Diff person. Changing to be unique.Odek	binya	lukoto
replace respondent_id=200 if submissionid==28762
// Opira Michael from Dino. Copy error from Stephen. Making it match.
replace respondent_id=110 if submissionid==56139
// Opiyo Richard from Dino. Copy error from Stephen. Making it NOT match.
replace respondent_id=200 if submissionid==56138
// Okidi Mayor -- making it NOT match with Adam's data. Diff names.
replace respondent_id=200 if submissionid==47220

// Not in Ajanyi. Moro Mark Paicho	kalalii	laminto. Found manually when reviewing data - modifing ID to match with Adam
replace respondent_id=15 if submissionid==39946
// Not in Ajanyi. Ajok Grace Odek	lamola	akoyo. Found manually when reviewing data - modifing ID to match with Adam
replace respondent_id=48 if submissionid==64721
// Not in Ajanyi. Anena Irene. Paicho	pagik	ajanyi. Found manually when reviewing data - modifing ID to match with Adam
replace respondent_id=74 if submissionid==42463

/* DROPPING SUBMISSIONS */

//All Drops are added back later with dataconcern==1 except for the first two
gen dataconcern="."
destring dataconcern, replace
label var dataconcern "Do not analyze - wrong/unclear resp"

// The following were from training or testing the phones or technical problems - I do not add these back
// Jibberish
drop if submissionid==35294 |  submissionid==38823

// We have to drop one of these to match on age - two people interviewed or two submissions for one person - I add these back later (7 total)
// Eunice interviewed two Akello Irene's - there was a duplicate in the data. I am dropping the one that was 20, because we did not have her age (the other was 29 and matched) -- this is what I should have done before handoff.
drop if submissionid==38875
// Okwera Janani. There are two men in the village with the same name - we did have an age of 33 here, and so I'm keeping the one where the ages match.
drop if submissionid==41768
// Agonga Owak - Akot Grace from Forestry. Two women with same name: 46 and 62. Eunice and Evelyn both. We have no age for the single name (true data).
drop if submissionid==35285
// There are two Richard Odong's in Laroo>Boke - only have true data about one person. 35113 I have made a data concern below.  Shame.
drop if submissionid==35383
// Evelyn had two entries from the same person - they were identical. Dropping one.
drop if submissionid==38190
// Concy re-entered an interview for Teresa Opika, deleting the second one.
drop if submissionid==34409
// This is identical to 44642 but has GPS. Must have been sent twice.
drop if submissionid==44641

// The following are instances when we were not sure we were interviewing the right person
// (Related to a Dropped Resp, Above) There are two Richard Odong's in Laroo>Boke and Adam's data does not have the age to clarify which was marketed to. Should drop both - looking at the data seems like cheating. Marking this as concern and dropped the other one above.
replace dataconcern=1 if submissionid==35113
// (Related to a Dropped Resp, Above) Agonga Owak - Akot Grace from Forestry. This is the one that did recieve seedlings. But how would we know it was the right person? Dropping both.
replace dataconcern=1 if submissionid==35224
// Dropping Acen Joyce, name is too different so I don't trust its the same person.
replace dataconcern=1 if submissionid==45266
// Dropping because the name is too different to "oroma hima"
replace dataconcern=1 if submissionid==43369
// Dropping because the name is too different -- Zakeo
replace dataconcern=1 if submissionid==46631
// Dropping because the name is too different -- Godfrey and Geoffrey
replace dataconcern=1 if submissionid==46659
// Dropping because this is too different to "aero nighty"
replace dataconcern=1 if submissionid==47324
// Emma interviewed a girl who was 21 instead of 37 with same name. USCSU recipient. Reject. (Emma noted that we should confirm identity on the tracking form)
replace dataconcern=1 if submissionid==46653
// "Obol Rose" was assigned (true data, loan) but Brian only found Abalo Rose with about the same age. She did also take a loan, but I'm just not sure enough about the name. If I knew nothing else, I couldn't be sure this is the right person.
replace dataconcern=1 if submissionid==55606
// Odong Michael. There are two in village, we interviewed one and the other is 76 years old (did not interview). However, Adam's data didn't have an age so there is no way to be 100% sure they didn't go to the old man. Patuda, Aitakonyakiting
replace dataconcern=1 if submissionid==38682

// The following are cases where CKWs and IPA both interviewed the person either because of duplicates in data or my assignment error
// Oringa Stephen was interviewed both by CKWs and IPA - duplicate in data. I am dropping the one from IPA which came after CKWs.
replace dataconcern=1 if submissionid==46977
// Dangit. I double assigned Alanyo Hilder in Odek Lamola Akoyo - just a stupid filter mistake. The CKW interviewed her first on the 10th of Dec so I'm deleting the IPA interview.
replace dataconcern=1 if submissionid==68767
// Helix walter. Patuda	Aita Konya Kiting. These weren't listed as CKW data points in Adam's file, he must have fixed it later to correct the IDs to match mine. So there ended up being two of the same, assigned / completed by both orgs. CKW interviewed before marketing (early Sept); IPA interviewed early Oct - after marketing. Dropping the IPA - second.
replace dataconcern=1 if submissionid==38679
// Hellen latigo. Patuda	Aita Konya Kiting. Same as above.
replace dataconcern=1 if submissionid==38684

/* FIXING INTERVIEW DATE SO PRODUCTIVITY IS CORRECT */
generate date_interviewed_original = date
label var date_interviewed_original "Dirty 'date_interviewed' (not cleaned)"
move date_interviewed_original date

replace date="11/2/2011" if submissionid==43978
replace date="11/2/2011" if submissionid==43981
replace date="11/14/2011" if submissionid==46036
// Oct not Nov
replace date="10/12/2011" if submissionid==38184
// Moved two weeks up to handset time based on server/handset time.
replace date="10/24/2011" if submissionid==44457
// Clearly wrong month (one off)
replace date="11/5/2011" if submissionid==45358
// Clearly wrong month (one off)
replace date="11/7/2011" if submissionid==45359

/* RECODING WHEN USED 'OTHER' */

// For Agriculture:
// Note: These changese are giving credit to the enum for being correct, but is slightly altering the respondent's perceptions if he/she didn't know Uganda Health Marketing Group was an NGO
// Eunice entered ACTED in the other category instead of selecting it from the list. I think these types of small errors should be fixed across both IPA/CKW.
replace supp_by_acted=1 if submissionid==50271

// The enum entered Other>"Uganda Health Marketing Group", Adam's NGO for this.
replace where_market=1 if submissionid==44642 | submissionid==44641
// The enum entered Other>"Star Pharm", Adam's For Profit for this.
replace where_market=2 if submissionid==40183 | submissionid==34288 | submissionid==40176
// IPA entered Other>Star Pharm, Adam's for profit
replace where_free=2 if submissionid==39481 | submissionid==38165 | submissionid==39480
// IPA entered Other>IPA, which is a nonprofit
replace where_free=1 if submissionid==36389 | submissionid==36033 | submissionid==38007 | submissionid==38190
// IPA entered Other>Health Marketing Group, Adam's nonprofit
replace where_free=1 if submissionid==35766 | submissionid==38201 | submissionid==46317 | submissionid==35764
// IPA entered Other> Ox Plow
replace grp_tools=1 if submissionid==36644 | submissionid==38191 | submissionid==39606 | submissionid==37077 | submissionid==40197 | submissionid==39602 | submissionid==40493 | submissionid==37078 | submissionid==39604
// Entered something machanical in Other
replace  grp_machinery=1 if submissionid==40179 | submissionid==45459
// Explained how money used in Other
replace grp_money=1 if submissionid==44130
// Hoe or Oxplow
replace pers_tools=1 if submissionid==38205 | submissionid==36951 | submissionid==39835
// Tents for harvest in Other
replace pers_storage=1 if submissionid==45457
// Lemon seedlings, etc in Other
replace pers_seeds=1 if submissionid==43370 | submissionid==51036

// For Bednet Health Center Names:
// "Opit" was entered as Other but was in the list.
replace hc_name_lalogi_opit=1 if submissionid==47412
// "Labworomor HC" was entered as Other but was in the list.
replace hc_name_palaro=1 if submissionid==43641
// Lakwatomer Health Centre was entered in other- same as LAKWANA LANENO BER HEALTH CENTRE III
replace hc_name_lak_laneno=1 if submissionid==40896
// Ajulu HC entered; same as Patiko
replace hc_name_patiko=1 if submissionid==43596 | submissionid==43597 | submissionid==43463 | submissionid==43462 | submissionid==43408

// Marketing
// Entered a specific date that was 3 weeks before interview
replace market_last = 2 if submissionid==43599
// Entered a specific date that was 3 weeks before interview
replace market_last = 2 if submissionid==44648
// Entered a specific date that was just a few days before interview
replace market_last = 1 if submissionid==50973

// Entered DoesNotKnow in wrong place
replace  sell_prod_doesnotknow = 1 if submissionid==34111

// Specific date was yesterday
replace market_last_free = 3 if submissionid==40195
// Specific date was last week
replace market_last_free = 1 if submissionid==38683
// Specific date was last week
replace market_last_free = 1 if submissionid==44015
// Just over two months ago
replace market_last_free = 4 if submissionid==46621
// 5 months ago
replace market_last_free = 5 if submissionid==36643
// Specific date was last week
replace market_last_free = 1 if submissionid==40493
// Specific date 5 weeks
replace market_last_free = 3 if submissionid==39605
// Specific date 5 weeks
replace market_last_free = 3 if submissionid==37080

// IPAer entered Govt in wrong place
replace today_health_org = 1 if submissionid==38471

saveold "$encrypted_data/data/all_submissions.dta", replace

****************Now, correct IPA***************
**************************************************************************************
****************************    CORRECT CKW SUBMISSIONS  ************************
**************************************************************************************

/***************
Author: Trina Gorman
Project: CKW (Rural Information - Uganda)
Purpose: Corrects mistakes or inaccuracies in CKW's submitted data -- many to ensure merge works correctly
***************/

/* REASSIGNING WHEN SWITCHED PHONES */

// New phone
replace enumerator = "Bosco Gwoktoo" if enumerator == "Rep1-gulu"
// New phone
replace enumerator = "Ojok Bosco Owiny" if ckwid == "CKW-10-000511"

/* FIXING RESPONDENT IDs PER RECLINK MERGE */
// mistake by Ben Kilama
replace respondent_id = 17 if submissionid==28594
// mistake by CKW and I had handed off the wrong one (pasting error) Elizabeth Adong
replace respondent_id = 102 if submissionid==28693
// mistake by CKW and I had handed off the wrong one (pasting error) Bendeter
replace respondent_id = 101 if submissionid==28691
// mistake by CKW and I had handed off the wrong one (pasting error) Komukech John
replace respondent_id = 103 if submissionid==28690
// mistake by CKW and I had handed off the wrong one (pasting error)
replace respondent_id = 1 if submissionid==30857
// mistake by CKW
replace respondent_id = 22 if submissionid==28692
// mistake by CKW
replace respondent_id = 3 if submissionid==28945
// mistake by CKW
replace respondent_id = 11 if submissionid==30944
// mistake by CKW
replace respondent_id = 13 if submissionid==30945
// mistake by CKW
replace respondent_id = 6 if submissionid==31043
// mistake by CKW
replace respondent_id = 12 if submissionid==30598
// mistake by CKW
replace respondent_id = 29 if submissionid==30369
// mistake by CKW
replace respondent_id = 2 if submissionid==28514
// mistake by CKW
replace respondent_id = 104 if submissionid==28681
// mistake by CKW
replace respondent_id = 18 if submissionid==36646
// mistake by CKW
replace respondent_id = 9 if submissionid==36647
// mistake by CKW
replace respondent_id = 16 if submissionid==38686
// mistake by CKW
replace respondent_id = 5 if submissionid==37675
// mistake by CKW
replace respondent_id = 104 if submissionid==28547
// mistake by CKW
replace respondent_id = 100 if submissionid==28518
// mistake by CKW
replace respondent_id = 104 if submissionid==28889
// mistake by CKW
replace respondent_id = 207 if submissionid==30435
// mistake by CKW
replace respondent_id = 215 if submissionid==31580
// mistake by CKW
replace respondent_id = 100 if submissionid==33802
// mistake by CKW
replace respondent_id = 106 if submissionid==33803
// mistake by CKW
replace respondent_id = 104 if submissionid==33804
// mistake by CKW
replace respondent_id = 102 if submissionid==36380
// mistake by CKW
replace respondent_id = 217 if submissionid==31940
// mistake by CKW
replace respondent_id = 102 if submissionid==28517
// mistake by CKW
replace respondent_id = 14 if submissionid==38213
// mistake by CKW
replace respondent_id = 8 if submissionid==38214
// mistake by CKW
replace respondent_id = 6 if submissionid==31581
// mistake by CKW
replace respondent_id = 16 if submissionid==35051
// mistake by CKW - Adyero Paska
replace respondent_id = 20 if submissionid==34577
replace respondent_id=27 if submissionid==47021
replace respondent_id=27 if submissionid==39849
replace respondent_id=25 if submissionid==39850
replace respondent_id=24 if submissionid==39851
replace respondent_id=19 if submissionid==40145
replace respondent_id=29 if submissionid==40422
// CKW put 14. oops.
replace respondent_id=41 if submissionid==44864
// CKW put 296
replace respondent_id=298 if submissionid==48081
// CKW entered 40. No clue why.
replace respondent_id=5 if submissionid==46618
// CKW put 30 (same as above)
replace respondent_id=38 if submissionid==45791
// I saw this person's name (Ochora Morris) randomly as a spouse name - who was marketed to. Need to align the IDs. Essentially, Adam marketed to this person -- the husband of one of the intended respondents.
replace respondent_id=20 if submissionid==46264
// The CKW entered 46.
replace respondent_id=36 if submissionid==53472
// The CKW entered 14.
replace respondent_id=41 if submissionid==44137
// The CKW entered 5 odd digits including 75.
replace respondent_id=30 if submissionid==39960

local wrong_id_by_ckw "28594 28693 28691 28690 30857 28692 28945 30944 30945 31043 30598 30369 28514 28681 36646 36647 38686 37675 28547 28518 28889  30435  31580  33802  33803 33804  36380 31940 28517 38213 38214 31581 35051 34577  47021 39849 39850 39851 40145 40422 44864  48081 46618 45791 53472  44137  39960"
foreach x of local wrong_id_by_ckw {
	replace wrong_id_by_enum = 1 if submissionid==`x'
}

//Next five are ids in Ajanyi to match with Adam's data
// AJOK EVALYN. Changed from 007 to 10 and now back to 7 to match Adam. ID: 43692
replace respondent_id=7 if submissionid==43692
// AKELLO MARY -  Changed from 017 to: 1848199026. ID: 50295
replace respondent_id=26 if submissionid==50295
// AMONO MONICA - Changed from 026 to: 1848199043. ID 66177. In Dwere
replace respondent_id=43 if submissionid==66177
// AMTO EVALYN - Changed from 010 to 15 and now back to 10 -- should finally work. 36237
replace respondent_id=10 if submissionid==36237
// ANYAYO ROSE - Changed from 019 to: 1848199029 - 50228
replace respondent_id=29 if submissionid==50228
// AUMA NANCY - Changed from 016 to: 1848199023. ID: 43693
replace respondent_id=23 if submissionid==43693
// ONGANY BOSCO - Changed from 003 to: 1848199004. ID: 65897
replace respondent_id=4 if submissionid==65897

// Akullu Nancy. Changing from 4 to 3 to match Adam.
replace respondent_id=3 if submissionid==50960
// Stephen's copy error - changing this to match Obote Margerate in Adam's data
replace respondent_id=103 if submissionid==28517
// Stephen's copy error - changing this to match Luyolo Mike in Adam's data
replace respondent_id=102 if submissionid==28889
// I had this matching up with Adam but isn't the same person - changing so only ACTED true data is compared. ekwee ken
replace respondent_id=200 if submissionid==30235
// I had this matching up with Adam but isn't the same person - changing so only ACTED true data is compared. odoki geofrey
replace respondent_id=400 if submissionid==44898
// Onen Geoffrey - Changing ID to match with Adam in Kal>Centre
replace respondent_id=3 if submissionid==30922

/* FIXING TYPOS IN NAMES/VILLAGES PER RECLINK RESULTS TO FACILITATE MERGE */

// mistake by CKW
replace village = "aita konya kiting" if submissionid==33844
// the CKW interviewed in Guna, trying to match
replace village = "onang" if submissionid==30945
// CKW entered many typos but this is right (Omel)
replace village = "olee (omel a)" if submissionid==45791
// mistake by CKW
replace surname = "aromoralu" if submissionid==33293
// the CKW entered J
replace parish = "pagik" if submissionid==29744
// small typo that Samuel said is the same person
replace name = "acaya victor" if submissionid==45740
// small typo that Samuel said is the same person
replace name = "oryem latoo" if submissionid==46820
// From Julie: "okiya john bosco was interviewed, mistake in submission"
replace name = "okiya john bosco" if submissionid==28491
// The CKW entered Adyero Adyero. Julie confirmed he meant to put Monica.
replace name = "adyero monica" if submissionid==44987
// The CKW entered "Alice" twice.
replace name = "anyeko alice" if submissionid==50343

// Rosemary Okello put the amount in the transition instead of the amount borrowed question.
replace amount_borrowed_loan2=200000 if submissionid==28514
// Dick put the amount in the transition instead of the amount borrowed question.
replace amount_borrowed_loan2=80000 if submissionid==36494

/* DROPPING RESPONDENTS FOR MERGE  */

// Empty surveys: I do not add these back.
drop if submissionid==28663 | submissionid==28903 | submissionid==28905 | submissionid==35098 | submissionid==37571 | submissionid==39956 | submissionid==40027 | submissionid==40300 | submissionid==45338 | submissionid==45441 | submissionid==45524 | submissionid==45525 | submissionid==45526 | submissionid==45527 | submissionid==45529 | submissionid==45532 | submissionid==64426 | submissionid==45470 | submissionid==45528 | submissionid==56898
// These were tests from the CKW, not part of project.
drop if submissionid==41630 | submissionid==28841 | submissionid==28865

// The following are surveys Grameen says we should not use: (incomplete, jibberish, duplicates) - I add these back later (12+13 below)
// These are surveys Grameen has decided not to accept.
drop if datateamreview=="Rejected"

// More than one submission for a single person- I add these back later
// There were two submissions for Akello Mary in Ajanyi. From Julie: drop 66043 and keep 50295
drop if submissionid==66043
// Dropping second interview for Abalo Beatrice in Odek Binya per Julie (other is 50273)
drop if submissionid==63127
// Akoko Regina. CKW interviewed twice (64 years and 66 years) Dropping the first one per Julie
drop if submissionid==41693
// The CKW interviewed this person 3 times. Dropping first two per Julie.
drop if submissionid==28844
// The CKW interviewed this person 3 times. Dropping first two per Julie.
drop if submissionid==29996
// Oneka David. Two were submitted. From Julie: it however has 2 submissions and we will consider the first because both submissions are entirely the same.
drop if submissionid==40274
// Two were submitted for Laruni Rose. From Julie: Lets keep the first…
drop if submissionid==45783
// These are surveys Grameen has determined are duplicates of others in the data (IDs: 29853, 38827, 39910, 41552, 45567, 47545)
drop if datateamreview=="Duplicate"

// The following are instances when we were not sure we were interviewing the right person. If it had been up to me in each of these cases, I would have told the enum not to interview the respondent:
// Tricky! There were two Charles Oringa in this village and its unclear if they are the same person because we only have an age for one --  one is 39 yrs (id 8, loan) the other is ? years (id 29, d2d only). Adam only marketed to id 29 but because he does not have the age of the person there is no way to know which Charles this is. To further complicate, the CKW entered the wrong ID for the Charles that is 37 (loan match). Its tricky, but I am deleting the one I assigned that didn't have an age (d2d), keeping the loan, and correcting the Id by matching the ages. I think this is a little generous on my part (because the CKW screwed up the Id) but its what I would do for the CKWs, and Julie would too if she had noticed.
replace dataconcern=1 if submissionid==46734
// Charles Oringa. See above. Tricky. The CKW entered the wrong Id for the Charles Oringa that is 37.
replace respondent_id=8 if submissionid==51138
// Charles Oringa. See above. Switching respondent Ids.
replace respondent_id=29 if submissionid==46734

// Okwera Benson was assigned and the CKW interviewed Okwera George. Julie said we should not accept.
replace dataconcern=1 if submissionid==32141
// Milly was interviewed but Mary was assigned. Julie said do not accept.
replace dataconcern=1 if submissionid==40270
// From Julie: The CKW says he interviewed Okello Tonny and not Ojok Tonny, so this could be taken as a different person interviewd. Labwoch Palami
replace dataconcern=1 if submissionid==45359
// Boda Margeret is too different to Aya Margeret - Julie said do not take.
replace dataconcern=1 if submissionid==64661

// The following are cases where CKWs and IPA both interviewed the person either because of duplicates in data or my assignment error
// Paicho	Kal-Alii	Te-Olam. CKW error. For these next four, I sent them to the CKW by mistake, and Grameen called the CKW within a day to retract them (before they were interviewed). But he must have misunderstood Julie because he interviewed them anyway. I argue this is the CKWs fault and he should not get credit for these (if it was my fault, he should).
replace dataconcern=1 if submissionid==53323
// See above
replace dataconcern=1 if submissionid==53334
// See above
replace dataconcern=1 if submissionid==53470
// See above
replace dataconcern=1 if submissionid==53471
// Onyabo Apollo. Concy and a CKW interviewed the same person - duplicate in data.  Concy interviewed the person *first* so I'm dropping the CKW's .
replace dataconcern=1 if submissionid==39909
// Auma Florence, Odek, Lamola, Akoyo. I assigned to both IPA and CKWs because of duplicates in data. IPA had interviewed her on the 17th. CKW interviewed on the 20th. Keeping the first.
replace dataconcern=1 if submissionid==70635
// Okello Walter. Adam used the wrong IDs initially, or had duplicates in his data. I dropped the IPA surveys, but need to fix the CKW's IDs to match with Adam's.
replace respondent_id=102 if submissionid==30101

/* FIXING INTERVIEW DATE SO PRODUCTIVITY IS CORRECT */

// Wrong year or month entered (by comparing to submission date)
// This is my best guess. He submitted two days before he conducted the interview (error), and so I'm going with the handset submission date
replace date="10/12/2011" if submissionid==39942
// Wrong year
replace date="9/28/2011" if submissionid==34122
// Clearly wrong month (one month early)
replace date="10/14/2011" if submissionid==38756
// Wrong year
replace date="10/20/2011" if submissionid==39949
replace date="9/15/2011" if submissionid==30944
replace date="11/23/2011" if submissionid==48316
replace date="12/8/2011" if submissionid==62191

/* RECODING WHEN USED 'OTHER'  */
// For Agriculture:

// CKW entered Other>Tarpaulin wheel barrow,a and Bicycle.
replace grp_tools=1 if submissionid==53324
// CKW entered Other>Oxen
replace grp_animals=1 if submissionid==33868
// CKW entered Hoes,Axe,Sickle and Okra,Tomatoes,Goundnuts,Beans Seeds.
replace grp_tools=1 if submissionid==32105
// CKW entered Hoes,Axe,Sickle and Okra,Tomatoes,Goundnuts,Beans Seeds.
replace grp_seeds=1 if submissionid==32105
// Other>Tarp
replace grp_tools=1 if submissionid==53323
// Other>Pig or Chicken
replace grp_animals=1 if submissionid==42645 | submissionid==33600
// CKW entered Seeds and Tools in Other
replace grp_tools=1 if submissionid==42007 | submissionid==34646
// CKW entered Seeds and Tools in Other
replace grp_seeds=1 if submissionid==42007 | submissionid==34646
// CKW entered Hoes in Other
replace grp_tools=1 if submissionid==40022
// CKW entered Seeds in Other
replace grp_seeds=1 if submissionid==36723 | submissionid==42648
// CKW entered Other>Tarp
replace grp_tools=1 if submissionid==53470
// CKW entered Hoes in Other
replace pers_tools=1 if submissionid==41021 | submissionid==36723 | submissionid==34646 | submissionid==28746 | submissionid==32151 | submissionid==30853
// Tarp
replace pers_tools=1 if submissionid==53470
// Gnut seed, Lemon seedlings, maize seeds, groundnut seeds
replace pers_seeds=1 if submissionid==46668 | submissionid==34646 | submissionid==32151

/* CLEANING LOAN AMOUNTS SO WE CAN COMPARE TO TRUE DATA*/
// CKW entered 20 instead of 20000
replace amount_borrowed_loan1=20000 if submissionid==46493
// CKW entered 24 instead of 24000
replace total_loan1=24000 if submissionid==46493
// CKW entered 50
replace amount_borrowed_loan1=50000 if submissionid==38827
// CKW entered 50
replace amount_borrowed_loan1=50000 if submissionid==28917
// CKW entered 500, which doesn't make sense
replace total_loan1=. if submissionid==28917
// CKW entered 15
replace amount_borrowed_loan1=15000 if submissionid==52004
// CKW entered 30
replace amount_borrowed_loan1=30000 if submissionid==46443
// CKW entered 33
replace total_loan1=33000 if submissionid==46443
// Entered 10
replace amount_borrowed_loan1=10000 if submissionid==46470
// Entered 12
replace total_loan1=12000 if submissionid==46470
// Entered 15
replace amount_borrowed_loan2=15000 if submissionid==46470
// Entered 18
replace total_loan2=18000 if submissionid==46470
// CKW entered 25
replace amount_borrowed_loan1=25000 if submissionid==46226
// CKW entered 25
replace amount_borrowed_loan1=50000 if submissionid==28919
// Entered 30
replace amount_borrowed_loan2=30000 if submissionid==30385

// browse number_loans submissionid enum amount_borrowed_loan1  total_loan1 amount_borrowed_loan2  total_loan2 amount_borrowed_loan3 amount_borrowed_loan4 amount_borrowed_loan5 if submissionid==28919
// Entered 3 but then had no information
replace number_loans=1 if submissionid==28917
// Entered 0
replace amount_borrowed_loan2=. if submissionid==28917
// Entered 0
replace total_loan2=. if submissionid==28917
// Entered 0
replace  amount_borrowed_loan3="." if submissionid==28917

// Entered 3 but then had no information
replace number_loans=1 if submissionid==28919
// Entered 0
replace amount_borrowed_loan2=. if submissionid==28919
// Entered 0
replace total_loan2=. if submissionid==28919

// CKW entered "Selling fish". Hmf.
replace amount_borrowed_loan3="." if submissionid==28908
destring amount_borrowed_loan3, replace

// CKW entered zero for all of these
replace amount_borrowed_loan3="." if submissionid==47368 | submissionid==28808 | submissionid==31002
// Per above, only had 2 loans for these.
replace number_loans=2 if submissionid==47368 | submissionid==28808 | submissionid==31002

// Entered zero
replace amount_borrowed_loan4=. if submissionid==63875
// The CKW entered 5 loans, skipped one, and entered zero in the other. Not a LOAN true data respondent.
replace number_loans=3 if submissionid==63875

// Entered 2.2 and I am not sure we should assume that is 2.2 million ... Not a LOAN true data respondent.
replace amount_borrowed_loan4=. if submissionid==44365

// CKW entered 'Not borrow'
replace amount_borrowed_loan3="." if submissionid==36646
// Per above, changing from 3 to 2
replace number_loans=2 if submissionid==36646
destring amount_borrowed_loan3, replace

// Bednets
// Lakwatomer Health Centre was entered in other- same as LAKWANA LANENO BER HEALTH CENTRE III
replace hc_name_lak_laneno=1 if submissionid==44772

// Marketing
// Entered a specific date that was just a few days before interview
replace market_last = 1 if submissionid==30100
// Entered a specific date that was just a few days before interview
replace market_last = 1 if submissionid==63875
// Entered a specific date that was just a few days before interview
replace market_last = 1 if submissionid==63872
// Entered a specific date that was just a few days before interview.
replace market_last = 1 if submissionid==30136

// Entered DoesNotKnow in wrong place
replace  sell_prod_doesnotknow = 1 if submissionid==68871
// Entered Panadol in wrong place
replace sell_prod_pan = 1 if submissionid==46443

// Note: These changese are giving credit to the enum for being correct, but is slightly altering the respondent's perceptions if he/she didn't know Uganda Health Marketing Group was an NGO
// The CKW entered that the marketer was from Other>IPA which is an NGO, so changing from 'Other' to 'NGO' (1)
replace where_market=1 if submissionid==40543
// The CKW entered Other>Panadol, not sure why didn't just chose the correct option
replace sell_prod_pan=1 if submissionid==46443
// CKW entered "Panadol.ORS and ZINKID" -- should have entered the first one on the list per instructions in survey.
replace market_name=1 if submissionid==46596 | submissionid==45850


// The CKW entered Other>ORS and Zinkid. Should have entered first in list per instructions.
replace free_products=3 if submissionid==36227 | submissionid==45546 | submissionid==43790 | submissionid==43503 | submissionid==34646 | submissionid==45584
// The CKW entered Other>Panadol and Deworming. Should have entered first in list per instructions.
replace free_products=1 if submissionid==38058 | submissionid==37988
// The CKW entered Other>Elyzole, which is deworming
replace free_products=2 if submissionid==34883

// CKW entered Other>IPA, which is an NGO
replace where_free=1 if submissionid==41474
// CKW entered Other>Star Pharm, Adam's for profit
replace where_free=2 if submissionid==41475
// Specific date was yesterday
replace market_last_free = 1 if submissionid==29766
// Specific date was yesterday
replace market_last_free = 1 if submissionid==29918
// Specific date was 5 weeks ago
replace market_last_free = 3 if submissionid==41474
// Specific date was yesterday
replace market_last_free = 1 if submissionid==29753
// Specific date last year
replace market_last_free = 6 if submissionid==32319
// Specific date last year
replace market_last_free = 6 if submissionid==48729
// Specific date was yesterday
replace market_last_free = 1 if submissionid==33868
// Specific date last year
replace market_last_free = 6 if submissionid==36219
// Specific date was yesterday
replace market_last_free = 1 if submissionid==34646
// Specific date was yesterday
replace market_last_free = 1 if submissionid==33844
// Specific date was yesterday
replace market_last_free = 1 if submissionid==29726
// Specific date last year
replace market_last_free = 6 if submissionid==30852

// CKW entered Govt in wrong place
replace today_health_org = 3 if submissionid==36685
// CKW entered NGO in wrong place
replace future_health_org = 1 if submissionid==39116
// CKW entered NGO in wrong place
replace future_health_org = 1 if submissionid==39964

/* FIXING GEOGRAPHIC VARIABLES WHEN CKWS CLEARLY MADE MISTAKES */

// . Richard Odongo said that he was in same parish but I'd assigned outside assigned. Changing to say from same SC instead of same parish. (tab enumerator parish_submitted if outside_assignedarea==1 & from_geo==2)
replace from_geo = 1 if submissionid==28525 | submissionid==32013 | submissionid==32053
// Two CKWs did simliiar -- they said NO when they should have said same SC (tab enumerator parish_submitted if outside_assignedarea==1 & from_geo==4)
replace from_geo = 1 if submissionid==45094 | submissionid==71557 | submissionid==71594 | submissionid==72407
// replace from_geo = 2 if outside_assignedarea==. & from_geo==1 & org=="CKW"
// Below are cases where said only same SC but should have said same parish (tab if outside_assignedarea==. & from_geo==1 & org=="CKW" )
replace from_geo = 2  if submissionid==46618 |  submissionid==46729 |  submissionid==66655 |  submissionid==28974 |  submissionid==51232 |  submissionid==47457 |  submissionid==31357 |  submissionid==28487 |  submissionid==33600 |  submissionid==29753 |  submissionid==34893 |  submissionid==28483 |  submissionid==29918 |  submissionid==36183 |  submissionid==29726 |  submissionid==33561 |  submissionid==31338 |  submissionid==33521 |  submissionid==29766 |  submissionid==28486 |  submissionid==28484 |  submissionid==31468 |  submissionid==34880 |  submissionid==37227 |  submissionid==33459 |  submissionid==31493 |  submissionid==66535 |  submissionid==70816 |  submissionid==28546 |  submissionid==36146 |  submissionid==29744 |  submissionid==32015 |  submissionid==32357 |  submissionid==30598 |  submissionid==30597 |  submissionid==32360 |  submissionid==32359 |  submissionid==32361 |  submissionid==32358 |  submissionid==28690 |  submissionid==34613 |  submissionid==59634
// Cases where the CKW really was from this village:
replace from_geo = 3 if submissionid==50960 | submissionid==28621 | submissionid==30137 | submissionid==30184 | submissionid==28495 | submissionid==28498 | submissionid==30538 | submissionid==30439 | submissionid==31043 | submissionid==59643 | submissionid==28918 | submissionid==30594 | submissionid==28919 | submissionid==28917 | submissionid==44140 | submissionid==42369 | submissionid==42368 | submissionid==28921 | submissionid==28920 | submissionid==47181 | submissionid==40272 | submissionid==32332 | submissionid==34703 | submissionid==31077 | submissionid==28934 | submissionid==28932 | submissionid==40760 | submissionid==40613 | submissionid==45688 | submissionid==40761 | submissionid==38811 | submissionid==41309 | submissionid==40696 | submissionid==45704 | submissionid==41337 | submissionid==41318 | submissionid==44008 | submissionid==38810 | submissionid==43289 | submissionid==41312 | submissionid==43652 | submissionid==43516 | submissionid==41423 | submissionid==36140 | submissionid==36184 | submissionid==28681 | submissionid==39969 | submissionid==30100 | submissionid==66177 | submissionid==47368 | submissionid==47431 | submissionid==47614 | submissionid==51427
// Below, these CKWs said "No" when they were either same parish/sc (if from_geo==4 & status=="Complete!" & org=="CKW")
replace from_geo = 2 if submissionid==33802 | submissionid==36380 | submissionid==33804 | submissionid==33803 | submissionid==31581 | submissionid==38214 | submissionid==36647 | submissionid==38213 | submissionid==38686 | submissionid==36646 | submissionid==30435 | submissionid==31580 | submissionid==31940 | submissionid==28514 | submissionid==68869 | submissionid==32078 | submissionid==32539 | submissionid==46264 | submissionid==46226 | submissionid==48669 | submissionid==44862 | submissionid==40025 | submissionid==48656 | submissionid==28491 | submissionid==30885 | submissionid==28493 | submissionid==30884 | submissionid==32102 | submissionid==32068 | submissionid==31878 | submissionid==48305 | submissionid==48196 | submissionid==48107 | submissionid==47372 | submissionid==47371| submissionid==29313 | submissionid==36592 | submissionid==30180 | submissionid==30452 | submissionid==30101 | submissionid==30003 | submissionid==38074

saveold "$encrypted_data/data/all_submissions.dta", replace


/************* STEP (4 ) MERGE AND RECONCILE SURVEYS WITH OTHER DATASETS *************************/

preserve
keep if ckw_mark == 1

saveold "$ckw_cleaning/data/ckw_submissions.dta", replace
restore

preserve
keep if ipa_mark == 1

saveold "$ipa_cleaning/data/ipa_submissions.dta", replace
restore

preserve
keep if ipaadd_mark == 1

saveold "$ipa_cleaning/data/IPA_DATA_TO_ADD.dta", replace
restore


cap truecrypt "T:/Encrypted_Data/Encrypted_Data_File_2.tc", mount drive(P)
conf f "P:/Encrypted_Data_File_2.txt"

// where IPA data and output is stored
gl ipa_cleaning = "P:/IPA_Data"
// where CKW data and output is stored
gl ckw_cleaning "P:/CKW_Data"
// where the true data is stored
gl true_data "P:/True_Data (do)"
// where Trina stores data w/ identifying info
gl encrypted_data "P:/Combined_Data"
// Where data w/o identifying information + all dos are stored.
gl master "T:/MASTER"
// where the demographic data about enumerators is stored - this directory has its own do file that creates $enum_info/data/enum_info.dta.
gl enum_info = "T:/Enum_Info (do)"
// where Adam's data is stored
gl d2d_data "T:/D2D_Data"
// where Adam's data is stored
gl audit_data "T:/Auditing_Data (do)"

/*
The data sets for unique IDs that are unique across these data sets:

1. "$encrypted_data/data/all_submissions.dta"  <-- this data set is the combination of SubmissionCSV-NoStartDate-NoEndDate-NoStatus.csv
+ IPA_DATA_TO_ADD.csv + SubmissionCSV-NoStartDate-NoEndDate-NoStatus.csv

2. "$true_data/data/ckw_true_data_all.dta"  <--  Data on Acted, Bednet, Loan-related questions that we know the answer

Note that "clean_D2D_data.dta" file has unique ID (full_hhid) that is common with   <--  Data on D2D (door to door) questions that IPA know the answer through actually going to the household and confirming whether the response was true or not

4. "$audit_data/data/audit_data_agg_errors.dta"  <-- Audit Data (e.g., auditors asked a surveyed respondent whether the CKW was polite, trustworthy, etc.  Also, we got severity of error data from this)

5. "../Dropbox/CKW/Data/trackingdata_ckw.dta" <-- # of attempts to find a respondent by CKW

Note: # of attempts to find a respondent by IPA in the "ipatrack.dta" file under PII_info.tc file has the same demographic info that ckw_true_data_all.dta has.

*/

************True Data************
use "$true_data/data/ckw_true_data_all.dta", clear

// these uniquely identify this data set
sort name village full_hhid status

gen ckw_true_data_all_id = _n

saveold "$true_data/data/ckw_true_data_all2.dta", replace


use "$encrypted_data/data/all_submissions.dta", clear

***********Submitted Data************
use "$encrypted_data/data/all_submissions.dta", clear
sort name resp_age parish village male, stable
gen all_submissions_id = _n

saveold "$encrypted_data/data/all_submissions2.dta", replace

*********CKW Track Data***********
use "../Dropbox/CKW/Data/trackingdata_ckw.dta", clear
rename serverentrydate surveydate_trackCKW
rename submissionid submissionid_trackCKW
saveold "../Dropbox/CKW/Data/trackingdata_ckw2.dta", replace


**************************************************************************************
*******************    MERGE DATASETS INTO SUBMITTED DATA  *********************
**************************************************************************************

/***************
Author: Trina Gorman
Project: CKW (Rural Information - Uganda)
Purpose: Merges in the following data sets:
1) True institutional data about respondents (using reclink)
2) Respondents that I previously dropped (labeled as dataconcern=1)
3) Enumurator demographic data
4) D2D marketing data
***************/

clear
set mem 500m
/*************MERGING/RECONCILING SURVEYS + TRUE DATA *************/

/* ADJUSTING THE TRUE DATA */
clear
use "$true_data/data/ckw_true_data_all2.dta", clear
preserve
// Need only data assignments that are complete in order for the merge to work 1:1; can analyze status of others using "$true_data/data/ckw_true_data_all2.dta"
drop if status!="Complete!" & status!="Drop_IntervByBothOrgs" & status!="Drop_WrongRespondent"

saveold "$true_data/data/all_true_data_marked_complete.dta", replace
restore

/*
These lines create all_true_data_marked_INcomplete.dta which is added back later in this file
*/
// Also dropping SKIP because this is reflected in "not_rand"; duplicate was just for my planning purposes.
drop if  status=="Complete!" | status=="Drop_IntervByBothOrgs" | status=="Drop_WrongRespondent" | status=="SKIP" | status=="Duplicate"
generate dataconcern = 2

rename name name_true
rename age age_true
rename parish parish_true
rename village village_true
rename hhid hhid_true
rename gender gender_true

*keep villageid status enum subcounty_true parish_true village_true name_true gender_true age_true source associated_ckw  dataconcern

saveold "$true_data/data/all_true_data_marked_INcomplete.dta", replace


/* ADJUSTING THE SUBMITTED DATA */

use "$encrypted_data/data/all_submissions2.dta", clear
// making the IDs the same variable name for merge
rename respondent_id hhid
sort village parish hhid name
rename IPA_CKW enum
// Please no
duplicates list submissionid if submissionid!=.

preserve
// duplicates tag submissionid, generate(dupeSubID)
// outsheet using "$master/output/duplicateSubIDs_16_may.csv" if dupeSubID==1, comma replace

/*
These next three lines are what I used to create the file at _MASTER/data/all_dropped_respondents.xls, which I add in later.
*/
keep if submissionid==44641 | submissionid==34613 | submissionid==38190 | submissionid==35285 | submissionid==51363 | submissionid==39910 | submissionid==63127 | submissionid==30474 | submissionid==45567 | submissionid==45368 | submissionid==43833 | submissionid==59634 | submissionid==41693 | submissionid==36808 | submissionid==35383 | submissionid==34409 | submissionid==38827 | submissionid==40274 | submissionid==45024 | submissionid==41768 | submissionid==38875 | submissionid==28666 | submissionid==29853 | submissionid==29854 | submissionid==41552 | submissionid==47545 | submissionid==68872 | submissionid==45469 | submissionid==45783 | submissionid==29996 | submissionid==28844 | submissionid==66043
tab enum
replace dataconcern=1
rename name name_submitted
rename parish parish_submitted
rename village village_submitted
rename hhid hhid_submitted
saveold "$encrypted_data/data/all_dropped_submissions.dta", replace

restore
saveold "$encrypted_data/data/all_submissions2.dta", replace

/* ENTER RECLINK */
// Reclink merges on the variables listed and generates myscore to report the accuracy of each match where 0 are "low matches" and 1 are "high matches". Reclink renames the variables that are merged on (village, name, etc.) in the "using" data set with U preceding the var name. */


use "$true_data/data/all_true_data_marked_complete.dta", clear
* `mastervars' will be the list of all variables in `master'.
unab mastervars   : _all
describe using "$encrypted_data/data/all_submissions2.dta", varlist
* `usingvars' will be the list of all variables in `using'.
local usingvars `r(varlist)'
* `overlap' will be the list of variables in both `mastervars' and `usingvars'.
* To learn more about this syntax, see -help extended_fcn- and especially
* -help macrolists-.
local overlap : list mastervars & usingvars
* Display `overlap'.
display "Overlap: `overlap'"
* Not surprisingly, `overlap' contains the variables for matching. Let's remove
* them from the list so we can see if there are any problematic shared
* variables.
* `matching' will be the list of variables for maching.
unab matching : parish village hhid name enum
* Remove variables in `matching' from `overlap'.
local overlap : list overlap - matching
* Display the new value of `overlap'.
// we got gender_true age_true for overlap
display "Overlap other than the matching variables: `overlap'"
use "$encrypted_data/data/all_submissions2.dta"


clear
// starting with the true data points
use "$true_data/data/all_true_data_marked_complete.dta", clear
// comparing to actual data
reclink parish village hhid name enum using "$encrypted_data/data/all_submissions2.dta", idm(idmaster) idu(submissionid) gen(matchscore) wmatch(2 2 6 10 19) required(enum) minscore(0)
order name Uname subcounty parish Uparish village Uvillage hhid Uhhid matchscore idmaster submissionid


/* CLEAN UP VARIABLES */

gen ________TRUE_DATA________= .
label var ________TRUE_DATA________ "_________________________________________________"
move ________TRUE_DATA________ name
gen ________SUBMITTED_DATA________ = .
label var ________SUBMITTED_DATA________ "_________________________________________________"
move ________SUBMITTED_DATA________ INTRODUCTION

drop Uenum
rename name name_true
rename Uname name_submitted
rename age age_true
rename parish parish_true
rename Uparish parish_submitted
rename village village_true
rename Uvillage village_submitted
rename hhid hhid_true
rename Uhhid hhid_submitted
rename gender gender_true
saveold "$encrypted_data/data/all_submissions.dta", replace

saveold "$encrypted_data/data/all_submissions.dta", replace


/* ADD BACK DROPPED RESPONDENTS */
// Look at them - these are all of the respondents that I dropped in 'correctipa' and 'correctckw'

// Append
clear
use "$encrypted_data/data/all_submissions.dta"

append using "$encrypted_data/data/all_dropped_submissions.dta"
saveold "$encrypted_data/data/all_submissions.dta", replace

/* ADD BACK INCOMPLETE RESPONDENTS */
// These are all of the people that were not interviewed for one reason or another - the reason is in the status column. Keeping them out until we need them for analysis

// See the incomplete data
clear
use "$true_data/data/all_true_data_marked_INcomplete.dta"
tab status
tab dataconcern
saveold "$true_data/data/all_true_data_marked_INcomplete.dta", replace

// Append
clear
use "$encrypted_data/data/all_submissions.dta"
append using "$true_data/data/all_true_data_marked_INcomplete.dta"
tab status
tab dataconcern
saveold "$encrypted_data/data/all_submissions.dta", replace


/* PRETTIFY */

label var idmaster "For Trina's Eyes Only"
label var matchscore "For Trina's Eyes Only"
label var customercarereview "Used by Grameen"
label var datateamreview "Used by Grameen"
destring not_rand, replace
move name_submitted surname
move subcounty same_named_villager
move parish_submitted same_named_villager
move village_submitted same_named_villager
move hhid_submitted same_named_villager
move submissionid enumerator
move enum _merge
move matchscore  bednet_date_recieved
move idmaster  bednet_date_recieved
move subcounty parish_submitted
rename subcounty subcounty_submitted
move idmaster dataconcern
move matchscore dataconcern
move not_rand dataconcern
move iswingsvillage dataconcern
move status dataconcern
move subcounty_true parish_true
// We can use the enumerator var for unique ID
drop ckwid
// more clear
rename enum org
label var dataconcern "1=WrongResp, 2=IncompleteSurvey"

/* CLARIFYING REASONS FOR WHY A SURVEY WAS DROPPED  */

// These status changes are for CKWs that we dropped and just added back
replace status="Drop_Incomplete" if submissionid==68872 | submissionid==28666 | submissionid==29854 | submissionid==45024 | submissionid==59634 | submissionid==30474 | submissionid==43833 | submissionid==45368 | submissionid==34613
replace status="Drop_Duplicate" if submissionid==38827 | submissionid==29853 | submissionid==39910 | submissionid==41552 | submissionid==45567 | submissionid==47545 | submissionid==66043 | submissionid==63127 | submissionid==41693 | submissionid==28844 | submissionid==29996 | submissionid==40274 | submissionid==45783
replace status="Drop_NotAssigned" if submissionid==45469 | submissionid==36808 | submissionid==51363

// These status changes are for IPAers that we dropped and just added back
replace status="Drop_WrongRespondent" if submissionid==38875 | submissionid==41768 | submissionid==35285 | submissionid==35383
replace status="Drop_Duplicate" if submissionid==38190 | submissionid==34409 | submissionid==44641

// So each entry has a source and a status
replace source="DATACONCERN" if dataconcern==1

/* CREATING VAR FOR SURVEYS CONDUCTED OUTSIDE ASSIGNED AREAS  */

// See _Enum_Info (do)/raw/SentOutsideParish.xls for the list of names and locations of those we sent outside parish (always within Subcounty)
gen outside_assignedarea=.
label var outside_assignedarea "Conducted outside assigned parish"
replace outside_assignedarea=1 if submissionid==48762 | submissionid==49395 | submissionid==49553 | submissionid==49554 | submissionid==53323 | submissionid==53324 | submissionid==53334 | submissionid==53470 | submissionid==53471 | submissionid==56274 | submissionid==56607 | submissionid==57631 | submissionid==45093 | submissionid==45094 | submissionid==47021 | submissionid==46619 | submissionid==46646 | submissionid==46823 | submissionid==46849 | submissionid==47089 | submissionid==49254 | submissionid==49255 | submissionid==49962 | submissionid==49963 | submissionid==44898 | submissionid==44899 | submissionid==44900 | submissionid==45672 | submissionid==46231 | submissionid==46232 | submissionid==46233 | submissionid==46820 | submissionid==48080 | submissionid==48081 | submissionid==48082 | submissionid==50315 | submissionid==50316 | submissionid==50317 | submissionid==50885 | submissionid==50886 | submissionid==52478 | submissionid==52479 | submissionid==52480 | submissionid==53232 | submissionid==56499 | submissionid==71557 | submissionid==71594 | submissionid==72407 | submissionid==56027 | submissionid==28525 | submissionid==30235 | submissionid==30236 | submissionid==30524 | submissionid==32011 | submissionid==32012 | submissionid==32013 | submissionid==32051 | submissionid==32053 | submissionid==36452 | submissionid==36459 | submissionid==36469 | submissionid==36525 | submissionid==36539 | submissionid==38319 | submissionid==38358 | submissionid==38440 | submissionid==38766 | submissionid==39919 | submissionid==39949 | submissionid==40083 | submissionid==40326 | submissionid==40774 | submissionid==41552 | submissionid==41604 | submissionid==42035 | submissionid==42951 | submissionid==42973 | submissionid==45781 | submissionid==45784 | submissionid==45786 | submissionid==45790 | submissionid==46088 | submissionid==46290 | submissionid==46291 | submissionid==46292 | submissionid==46843 | submissionid==48052 | submissionid==48053 | submissionid==48054 | submissionid==48829 | submissionid==48830 | submissionid==53926

/* CLEANING UP DATES SO THEY ARE FORMATTED CORRECTLY */

// Fixing loan dates - First, one of the SACCOS in Koro entered their dates as DMY so I'll do those first
generate  loan1_date_new=date(loan1_date,"DMY") if submissionid==64427 | submissionid==37047 | submissionid==36640 | submissionid==37049 | submissionid==36591 | submissionid==64428 | submissionid==36980 | submissionid==50960 | submissionid==36644 | submissionid==39289 | submissionid==39255 | submissionid==51811 | submissionid==36641 | submissionid==36643 | submissionid==50961 | submissionid==64429 | submissionid==36973 | submissionid==36976 | submissionid==37022 | submissionid==47186 | submissionid==56603 | submissionid==50343 | submissionid==56580 | submissionid==50962 | submissionid==36593 | submissionid==36642 | submissionid==36981 | submissionid==36596 | submissionid==36595 | submissionid==51031 | submissionid==45359 | submissionid==36974 | submissionid==37572 | submissionid==28595 | submissionid==37048 | submissionid==36666 | submissionid==39256 | submissionid==68143 | submissionid==28593 | submissionid==51034 | submissionid==36978 | submissionid==36664 | submissionid==36663 | submissionid==47366
format loan1_date_new %td
move loan1_date_new loan1_date
// There are 44 at this point - 44 Koro Ibbe Loans
label var loan1_date_new "True: Date First Loan Given"
// This takes care of the two 2nd loans, both in Koro Ibbe SACCO
generate  loan2_date_new=date(loan2_date,"DMY") if subcounty_true=="Koro"
format loan2_date_new %td
move loan2_date_new loan2_date
label var loan2_date_new "True: Date 2nd Loan Given"
// Second, change the rest, which are in MDY
replace  loan1_date_new=date(loan1_date,"MDY") if loan1_date_new==.
drop loan2_date
rename loan2_date_new loan2_date
drop loan1_date
rename loan1_date_new loan1_date

// Date submitted to the server -- transform Grameen's format into something readable
gen day_survey_submitted = substr(serverentrydate, 5,6)
move day_survey_submitted serverentrydate

gen year_submitted = substr(serverentrydate, 25,4)
move year_submitted serverentrydate

gen date_submitted = day_survey_submitted + " " + year_submitted
move date_submitted day_survey_submitted

generate date_submitted_new=date(date_submitted,"MDY")
format date_submitted_new %td
move date_submitted_new date_submitted

drop day_survey_submitted year_submitted date_submitted final_text
rename date_submitted_new date_submitted
label var date_submitted "Date Survey Submitted (formatted serverentrydate)"

// Date of Interview --  format into something readable
generate date_interviewed=date(date,"MDY")
format date_interviewed %td
move date_interviewed date
label var date_interviewed "Date Interview Conducted (cleaned)"
label var date "Unformatted 'date_interviewed' (used in calcs)"
move date_interviewed date_submitted
move date date_submitted
move date_interviewed_original date_interviewed

// Creating var to fix survey question issue (incorrect translation fixed midway)
gen include_in_agric=0
label var include_in_agric "1=Analyze for q85 and pers supp"
replace include_in_agric=1 if submissionid>36531 & org=="CKW"
replace include_in_agric=0 if submissionid==36592 | submissionid==36723
replace include_in_agric=1 if org=="IPA"
replace include_in_agric=. if dataconcern==1 | dataconcern==2

// Creating a var for those surveys that were not conducted in the assigned village, which is what the villageid is associated with.
generate not_in_assign_village=1 if submissionid==34121 | submissionid==37607 | submissionid==67529 | submissionid==50273 | submissionid==41746 | submissionid==47580 | submissionid==28594 | submissionid==39256 | submissionid==39289 | submissionid==32238 | submissionid==45359 | submissionid==41108 | submissionid==72407 | submissionid==56027 | submissionid==39936 | submissionid==39830 | submissionid==39595 | submissionid==42973 | submissionid==42951 | submissionid==45781 | submissionid==42035 | submissionid==45784 | submissionid==41604 | submissionid==66177 | submissionid==41282 | submissionid==45786 | submissionid==45790 | submissionid==51690 | submissionid==51688 | submissionid==51689 | submissionid==51232 | submissionid==29313 | submissionid==47931 | submissionid==47220 | submissionid==39969 | submissionid==36592 | submissionid==51307 | submissionid==32220 | submissionid==39248 | submissionid==39249 | submissionid==40929 | submissionid==39116 | submissionid==32360 | submissionid==32359 | submissionid==40272 | submissionid==43601 | submissionid==49472 | submissionid==35453 | submissionid==35452 | submissionid==29744 | submissionid==66535 | submissionid==70829 | submissionid==30185 | submissionid==34067 | submissionid==31708 | submissionid==39942 | submissionid==54664 | submissionid==54122 | submissionid==54125 | submissionid==54542 | submissionid==54124 | submissionid==54126 | submissionid==54123 | submissionid==40331 | submissionid==39624 | submissionid==34066 | submissionid==31922 | submissionid==40332 | submissionid==45775 | submissionid==34456 | submissionid==34876 | submissionid==33686 | submissionid==32426
label var not_in_assign_village "1=Villageid != where conducted"
move not_in_assign_village  outside_assignedarea

// Creating a var to mark the D2D matches that I found through
generate d2d_found_manually=1 if full_hhid==1636120103 | full_hhid==1636120105 | full_hhid==1326064108 | full_hhid==1635115123 | full_hhid==1636120017 | full_hhid==2056237133 | full_hhid==1429081113 | full_hhid==1218036102 | full_hhid==1057283114 | full_hhid==1635115117 | full_hhid==1845177108 | full_hhid==1532099114 | full_hhid==2055229108 | full_hhid==1057301108 | full_hhid==1057283111 | full_hhid==1637132100 | full_hhid==1847191103 | full_hhid==1117031016 | full_hhid==1324055103 | full_hhid==1636125104 | full_hhid==1327068103 | full_hhid==1011003105 | full_hhid==1115017102 | full_hhid==1218036102 | full_hhid==1218037143 | full_hhid==1222051103 | full_hhid==1326061107 | full_hhid==1326061156 | full_hhid==1534111142 | full_hhid==1636120103 | full_hhid==1636120105 | full_hhid==1741155103 | full_hhid==1741155107 | full_hhid==1847197102 | full_hhid==1847197108 | full_hhid==1847197109 | full_hhid==1847197112 | full_hhid==1846181100 | full_hhid==1846181109 | full_hhid==1846183114 | full_hhid==1951214126 | full_hhid==1845177022 | full_hhid==1636120002 | full_hhid==1848199018
label var d2d_found_manually "1=Matched w/ D2D by analyzing resp answers"
move d2d_found_manually outside_assignedarea
// *browse if full_hhid==1636120103 | full_hhid==1636120105 | full_hhid==1326064108 | full_hhid==1635115123 | full_hhid==1636120017 | full_hhid==2056237133 | full_hhid==1429081113 | full_hhid==1218036102 | full_hhid==1057283114 | full_hhid==1635115117 | full_hhid==1845177108 | full_hhid==1532099114 | full_hhid==2055229108 | full_hhid==1057301108 | full_hhid==1057283111 | full_hhid==1637132100 | full_hhid==1847191103 | full_hhid==1117031016 | full_hhid==1324055103 | full_hhid==1636125104 | full_hhid==1327068103 | full_hhid==1011003105 | full_hhid==1115017102 | full_hhid==1218036102 | full_hhid==1218037143 | full_hhid==1222051103 | full_hhid==1326061107 | full_hhid==1326061156 | full_hhid==1534111142 | full_hhid==1636120103 | full_hhid==1636120105 | full_hhid==1741155103 | full_hhid==1741155107 | full_hhid==1847197102 | full_hhid==1847197108 | full_hhid==1847197109 | full_hhid==1847197112 | full_hhid==1846181100 | full_hhid==1846181109 | full_hhid==1846183114 | full_hhid==1951214126 | full_hhid==1845177022 | full_hhid==1636120002 | full_hhid==1848199018

// Creating a var to mark who took loans after 2010 (only asked this in survey)
generate loan_after_2010 = 0
replace loan_after_2010 = 1 if loan1_date > d(1jan2010)
label var loan_after_2010 "Use for loan analysis (only asked > 2010)"

// Generate a variable to use to control for IPAers in analysis files
gen enum_is_ipa=1 if org=="IPA" & (dataconcern!=2 & dataconcern!=1)
replace enum_is_ipa=0 if org=="CKW" & (dataconcern!=2 & dataconcern!=1)
label var enum_is_ipa "1=Enum was IPA; != incl dataconcerns"
label define enum_is_ipaL 1 "1) IPA" 0 "0) CKW"
label values enum_is_ipa enum_is_ipaL

saveold "$encrypted_data/data/all_submissions.dta", replace

/* LOOK AT DESCREPENCIES */
tab _merge
// Gone. Great. This shows if there was survey data that matched in multiple places (went to more than one true data source)
duplicates list submissionid if submissionid!=.
// duplicates list full_hhid // There are duplicates because of the data concerns
// duplicates tag full_hhid, generate (dupe_hh_id)


/************ MERGING ENUMERATOR DEMOGRAPHIC DATA *************/
*
// First the enumerator data
clear
use "$enum_info/data/enum_info.dta", clear
sort enumerator
saveold "$enum_info/data/enum_info.dta", replace

// Then the CKW data
clear
use "$encrypted_data/data/all_submissions.dta", clear
sort enumerator
drop _merge
saveold "$encrypted_data/data/all_submissions.dta", replace

// Unite!
merge enumerator using "$enum_info/data/enum_info.dta"
// The 2 twos are Peter and Richard, who didn't conduct any surveys but were trained.
tab _merge
sort _merge

gen ________ENUMERATOR_DATA________= .
label var ________ENUMERATOR_DATA________ "_________________________________________________"
move ________ENUMERATOR_DATA________ gender

// just so all entries have a source
replace source="ENUMINFO" if source==""
// just so all entries have a source
replace status="Empty_EnumInfo" if status==""

saveold "$encrypted_data/data/all_submissions.dta", replace

// There are duplicates because of the data concerns + inactive CKWs
duplicates list full_hhid if full_hhid!=.
duplicates list submissionid if submissionid!=.

/************ MERGING D2D DATA *************/

// First the D2D data
clear
use "$d2d_data/raw/clean_D2D_data.dta", replace
rename  respondentid full_hhid
sort full_hhid
keep dateofbirth ckwvillage ckwdatapoint full_hhid villageid subcounty parish village respondentname nickname respondent_gender dateofbirth date_wave1 date_usage date_wave2 WAVE_ONE respondentfound spousefound spousename found productassigned ngo sale free_accepted sale_purchased sale_quantity condom_received WAVE_TWO respondentfound2 spousefound2 spousename2 productassigned2 sale_purchased2 sale_quantity2
// making his vars unique
rename subcounty subcounty_d2d
// making his vars unique
rename parish parish_d2d
// making his vars unique
rename village village_d2d
// making his vars unique
rename nickname nickname_d2d
duplicates list full_hhid
gen from_d2d=1
label var from_d2d "1=Resp was in D2D data"
saveold "$d2d_data/data/clean_D2D_data.dta", replace

// Then the CKW data
clear
use "$encrypted_data/data/all_submissions.dta"
sort full_hhid
// outsheet name_true subcounty parish_true village_true hhid_true hhid_submitted full_hhid using "$master/output/FULLIDs.csv", comma replace
drop _merge
saveold "$encrypted_data/data/all_submissions.dta", replace

//Unite!
merge full_hhid using "$d2d_data/data/clean_D2D_data.dta"
// 1 means CKW only, 2 means using (Adam's) only, 3 means match
tab _merge
// Dropping those that are only in Adam's dataset - only useful for Adam's analysis
drop if _merge==2
// Need to format phone numbers to keep precision/ability to view
format full_hhid %10.0f

gen ________D2D_DATA________= .
label var ________D2D_DATA________ "_________________________________________________"
move ________D2D_DATA________ ckwvillage
move date_wave1  dateofbirth
move date_wave2  dateofbirth

saveold "$encrypted_data/data/all_submissions.dta", replace

keep if mi(name_true)
saveold "$encrypted_data/data/nonamesubmissions.dta", replace

use "W:/all_ckw_info/all_ckw_infoSOL_11132012_Final_clean", clear
sort name_true subcounty_true parish_true village_true, stable
gen idtrack = _n
duplicates tag name_true parish_true subcounty_true village_true source, gen(dup_trackIPA)
saveold "W:/all_ckw_info/ipatrack.dta", replace

use "$encrypted_data/data/all_submissions.dta", clear
drop if mi(name_true)

sort name_true subcounty_true parish_true village_true, stable
gen n = _n


* `mastervars' will be the list of all variables in `master'.
unab mastervars   : _all
describe using "W:/all_ckw_info/ipatrack.dta", varlist
* `usingvars' will be the list of all variables in `using'.
local usingvars `r(varlist)'
* `overlap' will be the list of variables in both `mastervars' and `usingvars'.
* To learn more about this syntax, see -help extended_fcn- and especially
* -help macrolists-.
local overlap : list mastervars & usingvars
* Display `overlap'.
display "Overlap: `overlap'"
* Not surprisingly, `overlap' contains the variables for matching. Let's remove
* them from the list so we can see if there are any problematic shared
* variables.
* `matching' will be the list of variables for maching.
unab matching : name_true subcounty_true parish_true village_true source
* Remove variables in `matching' from `overlap'.
local overlap : list overlap - matching
* Display the new value of `overlap'.
// hhid_true full_hhid villageid gender_true age_true
display "Overlap other than the matching variables: `overlap'"

preserve
use "W:/all_ckw_info/ipatrack.dta", clear
rename hhid_true hhid_ipatrack
rename full_hhid full_hhid_ipatrack
rename villageid villageid_ipatrack
rename gender_true gender_ipatrack
rename age_true age_ipatrack

save, replace
restore

// perfect match
reclink name_true subcounty_true parish_true village_true source using "W:/all_ckw_info/ipatrack.dta", idmaster(n) idusing(idtrack) gen (matchscore_trackIPA) wm(10 2 2 4 2) _merge(merge_trackIPA)

// the file above
replace numberoftracking = . if org == "CKW"
rename numberoftracking attempt_ipa

append using "$encrypted_data/data/nonamesubmissions.dta"


saveold "$encrypted_data/data/all_submissions.dta", replace


***CKW tracking data
insheet using "../Dropbox/CKW/Data/Tracking data.csv",clear
ren name enumerator
ren  respnamewhat_is_the_name_of_the_ name_true
ren villagerespondents_village village_true
ren parishrespondents_parish parish_true
gen length = length(name_true)
gsort - length
replace name_true = "" if _n ==1
gen nname = name_true
drop name_true
ren nname name_true

foreach var of varlist name_true village_true parish_true enumerator  {
	replace `var' = lower(`var')
	replace `var' = trim(`var')
	replace `var' = subinstr(`var', ".", "", 1)
	replace `var' = subinstr(`var', "(", "", 1)
	replace `var' = subinstr(`var', ")", "", 1)
	replace `var' = subinstr(`var', "-", "", 1)
	replace `var' = subinstr(`var', "0", "", 1)
	charlist `var'
}


duplicates tag  name_true village_true parish_true, gen(dup_trackCKW)

gsort +name_true +village_true +dup -numberoftripshow_many_trips_have
by name_true village_true dup: drop if numberoftripshow_many_trips_have[_n + 1] <= numberoftripshow_many_trips_have[_n] & dup >=1 & !mi(dup)


// we cannot tell who they are if respondents' names are not available, then we don't know the "status" for these obs
drop if name_true == ""


sort name_true village_true parish_true enumerator, stable
gen n1 = _n

saveold "../Dropbox/CKW/Data/trackingdata_ckw.dta", replace

use "$encrypted_data/data/all_submissions.dta", clear


foreach var of varlist name_true village_true parish_true enumerator  {
	replace `var' = lower(`var')
	replace `var' = trim(`var')
	replace `var' = subinstr(`var', ".", "", 1)
	replace `var' = subinstr(`var', "(", "", 1)
	replace `var' = subinstr(`var', ")", "", 1)
	replace `var' = subinstr(`var', "-", "", 1)
	replace `var' = subinstr(`var', "0", "", 1)
	replace `var' = subinstr(`var', "/", "", 1)
	replace `var' = subinstr(`var', "1", "", 1)
	charlist `var'
}


drop n
// these are already in the master data set from the last reclink
drop Uname_true Uparish_true Uvillage_true


sort name_true village_true parish_true enumerator, stable
gen n2 = _n
preserve
sort n2
tempfile temp
save `temp', replace
restore

**Here, we use the trackingdata_ckw2.dta file that has group assignment number from strgroup

* `mastervars' will be the list of all variables in `master'.
unab mastervars   : _all
describe using "../Dropbox/CKW/Data/trackingdata_ckw2.dta", varlist
* `usingvars' will be the list of all variables in `using'.
local usingvars `r(varlist)'
* `overlap' will be the list of variables in both `mastervars' and `usingvars'.
* To learn more about this syntax, see -help extended_fcn- and especially
* -help macrolists-.
local overlap : list mastervars & usingvars
* Display `overlap'.
display "Overlap: `overlap'"
* Not surprisingly, `overlap' contains the variables for matching. Let's remove
* them from the list so we can see if there are any problematic shared
* variables.
* `matching' will be the list of variables for maching.
unab matching : name_true parish_true village_true enumerator
* Remove variables in `matching' from `overlap'.
local overlap : list overlap - matching
* Display the new value of `overlap'.
// hhid_true full_hhid villageid gender_true age_true
display "Overlap other than the matching variables: `overlap'"

gen enumerator_full=enumerator
replace enumerator_full = associated_ckw if enumerator== ""

replace enumerator_full="Geoffrey Abama" if enumerator_full=="Abama Geoffrey"
replace enumerator_full="Aber Judith" if enumerator_full=="Aber Judith Adonga"
replace enumerator_full="Charles Acai" if enumerator_full=="Acai Charles"
replace enumerator_full="Mark Acaye" if enumerator_full=="Acaye Mark"
replace enumerator_full="Stella Adiaye" if enumerator_full=="Acayo Stella"
replace enumerator_full="Esther Adong" if enumerator_full=="Adong Esther Ocan"
replace enumerator_full="Florence Akello" if enumerator_full=="Akello Florence"
replace enumerator_full="Rosemary Akello" if enumerator_full=="Akello Rosemary"
replace enumerator_full="Monica Akumu" if enumerator_full=="Akumu Monica"
replace enumerator_full="Mathias Anywar" if enumerator_full=="Anywar Mathias"
replace enumerator_full="Doreen Apio" if enumerator_full=="Apio Lucy Doreen"
replace enumerator_full="Hollin Aryemo" if enumerator_full=="Aryemo Hollin"
replace enumerator_full="Martin Atube" if enumerator_full=="Atube Martin"
replace enumerator_full="Moses Can" if enumerator_full=="Can Moses"
replace enumerator_full="Gladys Fielder" if enumerator_full=="Filder Gladys Laker"
replace enumerator_full="Bosco Gwoktoo" if enumerator_full=="Gwoktoo Bosco"
replace enumerator_full="Richard Jokene" if enumerator_full=="Jok-kene Richard"
replace enumerator_full="Ben Kilama" if enumerator_full=="Kilama Ben"
replace enumerator_full="Amos Kinyera" if enumerator_full=="Kinyera Geoffrey Amos"
replace enumerator_full="Komakech Richard" if enumerator_full=="Komakech Richard"
replace enumerator_full="Simon Obwoya" if enumerator_full=="Obwoya Simon"
replace enumerator_full="Alfred Ocan" if enumerator_full=="Ocan Alfred"
replace enumerator_full="Michael Ochieng" if enumerator_full=="Ocheng Michael"
replace enumerator_full="Francis Ochora" if enumerator_full=="Ochora Francis"
replace enumerator_full="Tonny Ocira" if enumerator_full=="Ocira Tonny"
replace enumerator_full="Thomas Odoki" if enumerator_full=="Odoki Thomas"
replace enumerator_full="Richard Odongo" if enumerator_full=="Odongo Richard"
replace enumerator_full="Bosco Ojok" if enumerator_full=="Ojok Bosco Mukasa"
replace enumerator_full="Ojok Bosco Owiny" if enumerator_full=="Ojok Bosco Owiny"
replace enumerator_full="Felix Ojok" if enumerator_full=="Ojok Felix"
replace enumerator_full="Francis Okello" if enumerator_full=="Okello Francis Lalur"
replace enumerator_full="Richard Okello" if enumerator_full=="Okello Richard"
replace enumerator_full="Robin Okello" if enumerator_full=="Okello Robin Okwanga"
replace enumerator_full="Francis Okidi" if enumerator_full=="Okidi Francis"
replace enumerator_full="Robert Okot" if enumerator_full=="Okot Robert"
replace enumerator_full="Samuel Okot" if enumerator_full=="Okot Samuel"
replace enumerator_full="Kennedy Olaa" if enumerator_full=="Olaa Kennedy"
replace enumerator_full="Dick Olanya" if enumerator_full=="Olanya Dick"
replace enumerator_full="Peter Oola" if enumerator_full=="Oola Peter"
replace enumerator_full="Francis Oringa" if enumerator_full=="Oringa Francis"
replace enumerator_full="Evaline Otika" if enumerator_full=="Otika Evalyn"
replace enumerator_full="Peter Otika" if enumerator_full=="Otika Odong Peter"
replace enumerator_full="Bosco Otto" if enumerator_full=="Otto Bosco"
replace enumerator_full="Walter Torach" if enumerator_full=="Torach Walter"


gen enumerator_full_low = lower(enumerator_full)

ren enumerator enumerator_ori
ren enumerator_full_low enumerator
replace enumerator = "." if org == "IPA" & status!= "Complete!"

// to check those duplicates after reclink.  Sometimes, we get multiple observations from using file to one observation in master file.
gen check = _n

reclink name_true parish_true village_true enumerator using "../Dropbox/CKW/Data/trackingdata_ckw2.dta", idmaster(n2) ///
	idusing(n1) gen(matchscore_trackCKW)  wm(20 1 5 5) minscore(0.7) _merge(merge_trackCKW)

sort matchscore_trackCKW, stable
gen tempid_trackCKW = _n if !mi(matchscore_trackCKW)
*bro name_true Uname_true matchscore_trackCKW  parish_true Uparish_true village_true Uvillage_true source enumerator Uenumerator status tempid_trackCKW numberoftripshow_many_trips_have
drop numberoftripshow_many_trips_have

*bro *name_true *parish_true *village_true *enumerator matchscore_trackCKW source status tempid


saveold "W:/all_submissions.dta", replace
clear
insheet using "../Dropbox/CKW/Data/reclink_trackingCKW_final.csv", case
drop if eyeball == 0


// this one is updated one after reclink_trackingCKW2 file
saveold "reclink_trackingCKW_final.dta", replace

use "W:/all_submissions.dta", clear
sort tempid
replace tempid = _n if mi(tempid)

merge 1:1 tempid using "reclink_trackingCKW_final.dta", gen(merge_reclinktrackCKW)


sort n2
replace n2 = _n if n2 == .
sort n2, stable

// it doesn't matter whether we drop the first or second obsrevation since they are complete duplicates except Uvariables.
duplicates drop n2, force
sort n2
merge 1:1 n2 using `temp', gen(merge_temp_correctobs)

drop enumerator_full
rename enumerator enumerator_full
rename enumerator_ori enumerator


*drop if merge_reclinktrackCKW == 2

rename numberoftripshow_many_trips_have attempt_ckw
rename eyeball_trackCKW1match0notmatch eyeball_trackCKW
// these are the eyeball check result
replace attempt_ckw = .a if eyeball_trackCKW == .
// these are errors that i couldn't detect by eyeball check.
replace attempt_ckw = .b if eyeball_trackCKW == 1 & org == "IPA"


/*check here if the strgroup score matches
name_group_true
name_group_all
name_group_track
*/

save, replace

sort name_true village_true full_hhid status, stable
gen uniqueid = _n

save, replace
*********Bring back the names of initially IPA enumerators for their incomplete surveys*************
preserve
clear
insheet using "M:\incompIPA_Reviewed.csv", n comma
drop name_true
ren firstassignedipaenumeratorname enumerator_ipaincomp
ren gender_true gender_true_ipa
ren age_true age_true_ipa
replace enumerator_ipaincomp = "Oneka Brian" if enumerator_ipaincomp == "Brian"
replace enumerator_ipaincomp = "Lanyero Concy" if enumerator_ipaincomp == "Concy"
replace enumerator_ipaincomp = "Acayo Irene Odoki" if enumerator_ipaincomp == "Irene"

replace enumerator_ipaincomp = lower(enumerator_ipaincomp)
drop if enumerator_ipaincomp == "missing" | enumerator_ipaincomp == "unknown" | mi(enumerator_ipaincomp)

replace enumerator_ipaincomp = enumerator_ipaincomp + " " + "ipa"

tempfile incompipa
save "`incompipa'", replace
restore

// 3 duplicates which is due to the dataconcern == wrong respondent households
merge m:1 full_hhid using "`incompipa'", gen(merge_ipaincomp)
// few obs to cover the missings in the corresponding var and not trustworthy
drop age_true_ipa gender_true_ipa
replace attempt_ipa = numberoftracking if mi(attempt_ipa)

// we don't need it anymore
drop numberoftracking
egen attempt = rowtotal(attempt_ipa attempt_ckw), m
la var attempt "Num of attempts to find a resp by IPA or CKW"
replace enumerator_full = enumerator_ipaincomp if !mi(enumerator_ipaincomp) & ///
	enumerator_full == "."
replace enumerator_full = "." if enumerator_full == "akera thomas ipa" | ///
	enumerator_full == "ojok michael clarence ipa" //Pia's comment: If I understand correctly these are 2 nonsensical data points with unknown enumerators. In that case I would just drop them.
replace enumerator_full = enumerator if source == "DATACONCERN"

drop spousename spousename2 Uname_true


encode org, gen(ckw)
// IPA should be 0
replace ckw = 0 if ckw == 2
la var ckw "1=Initially Assigned to CKW"
la def ckwc 0"IPA" 1"CKW"
la val ckw ckwc
save, replace

preserve
drop if mi(full_hhid)
tempfile d2d
save "`d2d'", replace
restore

preserve
keep ckw_true_data_all_id uniqueid
tempfile temp
save "`temp'", replace
restore

preserve
keep tempid uniqueid
tempfile trackunique
save "`trackunique'", replace
restore

preserve
keep idtrack uniqueid
tempfile ipatrack
save "`ipatrack'", replace
restore

keep submissionid uniqueid
tempfile submitted
save "`submitted'", replace


use "$true_data/data/ckw_true_data_all2.dta", clear
merge 1:m ckw_true_data_all_id using "`temp'", gen(merge_unique_true)
drop if merge_unique_true == 2
sort uniqueid
forval i =1(1)42{
	replace uniqueid = uniqueid[_n - 1] + `i' if unique[_n] == .
}

saveold "Y:/ckw_true_data_all_unique.dta", replace

use "$d2d_data/data/clean_D2D_data.dta", clear
merge 1:m full_hhid using "`d2d'", gen(merge_d2d_unique)
saveold "Y:/clean_D2D_data_unique", replace


use "../Dropbox/CKW/Data/reclink_trackingCKW2.dta", clear
merge 1:m tempid using "`trackunique'", gen(merge_unique_trackckw)
drop if merge_unique_trackckw == 2

saveold "Y:/reclink_trackingCKW2_unique.dta", replace

use "W:/all_ckw_info/ipatrack.dta", clear
merge 1:m idtrack using "`ipatrack'", gen(merge_unique_trackipa)
drop if merge_unique_trackipa == 2

saveold "Y:/ipatrack_unique.dta", replace

use "$ckw_cleaning/data/ckw_submissions.dta", clear
merge 1:m submissionid using "`submitted'", gen(merge_unique_ckwsubmitted)
drop if merge_unique_ckwsubmitted == 2


saveold "Y:/ckw_submissions_unique.dta", replace

use "$ipa_cleaning/data/ipa_submissions.dta", clear
merge 1:m submissionid using "`submitted'", gen(merge_unique_ipasubmitted)
drop if merge_unique_ipasubmitted == 2

saveold "Y:/ipa_submissions_unique.dta", replace

use "$ipa_cleaning/data/IPA_DATA_TO_ADD.dta", clear
merge 1:m submissionid using "`submitted'", gen(merge_unique_ipaADDsubmitted)
drop if merge_unique_ipaADDsubmitted == 2

saveold "Y:/IPA_DATA_TO_ADD_unique.dta", replace

use "$audit_data/data/audit_data_questions.dta", clear
merge 1:m submissionid using "`submitted'", gen(merge_unique_audit_que)
drop if merge_unique_audit_que == 2

saveold "Y:/audit_data_questions_unique.dta", replace

use "$audit_data/data/audit_data_agg_errors.dta", clear
merge 1:m submissionid using "`submitted'", gen(merge_unique_audit_err)
drop if merge_unique_audit_err == 2

saveold "Y:/audit_data_agg_errors_unique.dta", replace

/*
cd "Y:"
use ckw_true_data_all_unique, clear


local files : dir . files "*_unique.dta", respectcase


foreach f of local files{
local merge = subinstr("`f'", ".dta", "", 1)
merge 1:1 uniqueid using "`f'", gen("`merge'")
}

**Note: make sure we don't have 2953 or above for the value of uniqueid and missing value of this variable
these values are not for our analysis

*/


//Drop identifying information and save in an unsafe place (living on the edge)
use "W:/all_submissions.dta", clear
drop  name_true first_name surname name_submitted nickname name_hoh respondentname phone_number
saveold "$master/data/all_submissions_no_identity.dta", replace

/************ MERGE AUDITING DATA DATA *************/
/*
clear
use "$audit_data/data/audit_data_agg_errors.dta"
sort submissionid
save "$audit_data/data/audit_data_agg_errors.dta", replace

clear
*/
use "$master/data/all_submissions_no_identity.dta", clear

gen ________AUDITING_DATA________= .
label var ________AUDITING_DATA________ "_________________________________________________"
drop _merge
merge 1:1 uniqueid using "Y:/audit_data_questions_unique", gen(merge_audit_que)

merge 1:1 uniqueid using "Y:/audit_data_agg_errors_unique", gen(merge_audit_err)

drop audit_sc  audit_village audit_date  handsetsubmissiondate_audit serverentrydate_audit
order  audit_org audit_enum audit_resp_id, after (________AUDITING_DATA________)
order village_audit audit_parish, after (subcounty_audit)
rename  audit_parish parish_audit
saveold "$master/data/all_submissions_no_identity.dta", replace

// *browse  audit_enum submissionid  audit_enum audit_sc audit_parish audit_village audit_date auditor audit_resp_id if _merge==2
order LET_THE_ANALYSIS_BEGIN dataconcern status iswingsvillage not_rand  wrong_id_by_enum matchscore idmaster org not_in_assign_village d2d_found_manually outside_assignedarea include_in_agric loan_after_2010 enum_is_ipa, after(percent_total)
label var  LET_THE_ANALYSIS_BEGIN "_________________________________________________"
saveold "$master/data/all_submissions_no_identity.dta", replace


/************* STEP (5) ASSESS PRODUCTIVITY *************************************************************/


**************************************************************************************
****************************    ASSESSING ENUM PRODUCTIVITY  ********************
**************************************************************************************

/***************
Author: hkoizumi.IPA Gorman
Project: CKW (Rural Information - Uganda)
Purpose: Create variables to assess week by week productivity to compare: 1) IPA and CKWs, and 2) CKWs both in and out of treatment focus group (performance study)
Files: Starts with '$master/data/all_submissions_no_identity.dta'; outputs '$master/data/all_submissions_no_identity2.dta' and $master/data/ckw_productivity.dta"
Outline:
(1) COMPARE THE WEEKLY PRODUCTIVITY OF ALL ENUMERATORS
(2) COLLAPSE DATA AND THEN OUTSHEET FOR PRODUCTIVITY GRAPHS (does not save changes)
(3) CREATE VARIABLES RELATIVE TO THE FOCUS GROUP TREATMENT
(4) COLLAPSE ON ENUMERATOR TO ANALYZE CKW PRODUCTIVITY (does not save changes)
*************/


// Where data w/o identifying information + all dos are stored.
gl master "T:/MASTER"
// where the demographic data about enumerators is stored - this directory has its own do file that creates $enum_info/data/enum_info.dta.
gl enum_info = "T:/Enum_Info (do)"
// where Adam's data is stored
gl d2d_data "T:/D2D_Data"
// guess
gl audit_data "T:/Auditing_Data (do)"


// This is the file that only I can create using ecrypted files
use "$master/data/all_submissions_no_identity.dta", clear
* log using "$master/output/productivity_14_feb.log", replace

/************* (1) COMPARE THE WEEKLY PRODUCTIVITY OF ALL ENUMERATORS*************/

gen  ________PRODUCTIVITY________ = .
label var ________PRODUCTIVITY________ "_________________________________________________"
// Generate a unique identifier for each enum
bys enumerator: gen unique_enum = _n if dataconcern!=2
label var unique_enum "1=This is a unique enum"

/* 1) CREATE A VARIABLE FOR # OF SURVEYS COMPLETED EACH WEEK PER ENUMERATOR */

*1.1) Create dummies for when the survey was completed
generate wk0_dummy=(date=="9/2/2011")
generate wk1_dummy=(date=="9/3/2011" | date=="9/4/2011" | date=="9/5/2011" | date=="9/6/2011" | date=="9/7/2011" | date=="9/8/2011" | date=="9/9/2011" | date=="9/10/2011" | date=="9/11/2011")
generate wk2_dummy=(date=="9/12/2011" | date=="9/13/2011" | date=="9/14/2011" | date=="9/15/2011" | date=="9/16/2011" | date=="9/17/2011" | date=="9/18/2011")
generate wk3_dummy=(date=="9/19/2011" | date=="9/20/2011" | date=="9/21/2011" | date=="9/22/2011" | date=="9/23/2011" | date=="9/24/2011" | date=="9/25/2011")
generate wk4_dummy=(date=="9/26/2011" | date=="9/27/2011" | date=="9/28/2011" | date=="9/29/2011" | date=="9/30/2011" | date=="10/1/2011" | date=="10/2/2011")
generate wk5_dummy=(date=="10/3/2011" | date=="10/4/2011" | date=="10/5/2011" | date=="10/6/2011" | date=="10/7/2011" | date=="10/8/2011" | date=="10/9/2011")
generate wk6_dummy=(date=="10/10/2011" | date=="10/11/2011" | date=="10/12/2011" | date=="10/13/2011" | date=="10/14/2011" | date=="10/15/2011" | date=="10/16/2011")
generate wk7_dummy=(date=="10/17/2011" | date=="10/18/2011" | date=="10/19/2011" | date=="10/20/2011" | date=="10/21/2011" | date=="10/22/2011" | date=="10/23/2011")
generate wk8_dummy=(date=="10/24/2011" | date=="10/25/2011" | date=="10/26/2011" | date=="10/27/2011" | date=="10/28/2011" | date=="10/29/2011" | date=="10/30/2011")
generate wk9_dummy=(date=="10/31/2011" | date=="11/1/2011" | date=="11/2/2011" | date=="11/3/2011" | date=="11/4/2011" | date=="11/5/2011" | date=="11/6/2011")
generate wk10_dummy=(date=="11/7/2011" | date=="11/8/2011" | date=="11/9/2011" | date=="11/10/2011" | date=="11/11/2011" | date=="11/12/2011" | date=="11/13/2011")
generate wk11_dummy=(date=="11/14/2011" | date=="11/15/2011" | date=="11/16/2011" | date=="11/17/2011" | date=="11/18/2011" | date=="11/19/2011" | date=="11/20/2011")
generate wk12_dummy=(date=="11/21/2011" | date=="11/22/2011" | date=="11/23/2011" | date=="11/24/2011" | date=="11/25/2011" | date=="11/26/2011" | date=="11/27/2011")
generate wk13_dummy=(date=="11/28/2011" | date=="11/29/2011" | date=="11/30/2011" | date=="12/1/2011" | date=="12/2/2011" | date=="12/3/2011" | date=="12/4/2011")
generate wk14_dummy=(date=="12/5/2011" | date=="12/6/2011" | date=="12/7/2011" | date=="12/8/2011" | date=="12/9/2011" | date=="12/10/2011" | date=="12/11/2011")
generate wk15_dummy=(date=="12/12/2011" | date=="12/13/2011" | date=="12/14/2011" | date=="12/15/2011" | date=="12/16/2011" | date=="12/17/2011" | date=="12/18/2011")
generate wk16_dummy=(date=="12/19/2011" | date=="12/20/2011" | date=="12/21/2011" | date=="12/22/2011" | date=="12/23/2011" | date=="12/24/2011" | date=="12/25/2011")
generate wk17_dummy=(date=="12/26/2011" | date=="12/27/2011" | date=="12/28/2011" | date=="12/29/2011" | date=="12/30/2011" | date=="12/31/2011" | date=="1/1/2011")

local productivity_dummy "wk0_dummy wk1_dummy wk2_dummy wk3_dummy wk4_dummy wk5_dummy wk6_dummy wk7_dummy wk8_dummy wk9_dummy wk10_dummy wk11_dummy wk12_dummy wk13_dummy wk14_dummy wk15_dummy wk16_dummy wk17_dummy"

foreach x of local productivity_dummy {
	label var `x' "1=Survey conducted in this week"
}

local productivity_count "wk0 wk1 wk2 wk3 wk4 wk5 wk6 wk7 wk8 wk9 wk10 wk11 wk12 wk13 wk14 wk15 wk16 wk17"

*1.2) Add up # completed each week to create wkX vars per enumerator

foreach x of local productivity_count {
	bysort enumerator: egen `x' = sum(`x'_dummy)
}
foreach x of local productivity_count {
	label var `x' "Per enum, surveys completed `x'"
}
drop *_dummy

/* 2) CREATE VARIABLES FOR AVERAGE WEEKLY SURVEYS ACROSS ALL WEEKS PER ENUMERATOR */

*2.1) How many total surveys did each enumerator complete?
// I chose to omit 2 weeks of irregular CKW work: wk16 (Christmas week), and wk 17 (should have been done)
gen totalcomplete_trina = wk1+wk2+wk3+wk4+wk5+wk6+wk7+wk8+wk9+wk10+wk11+wk12+wk13+wk14+wk15
label var totalcomplete_trina "Per enum, surveys completed wk1-wk15_Trina"

*2.1) What was each enumerator's weekly average across all weeks?
generate wkly_avg_total=totalcomplete / wks_total
label var wkly_avg_total "Per enum, average wkly surveys over all weeks"

saveold "$master/data/all_submissions_no_identity2.dta", replace

/************* STEP (6) TRINA'S ANALYSIS AND CLEANING CHECKS *******************************************/
**************************************************************************************
****************************    ANALYZING ERROR RATES ***********************
**************************************************************************************

/***************
Author: Trina Gorman
Project: CKW (Rural Information - Uganda)
Purpose: Analyze error rates for the following true data sources: ACTED and NRC (agriculture), BEDNETS to pregnant women, LOANS from SACCOs, MARKETING health products
Files: Starts with and saves to: '$master/data/all_submissions_no_identity2.dta' -- you must run do file #6 before running this file.
Outline:
(1) COMPARE THE REASONS FOR INCOMPLETE SURVEYS ACROSS ENUMERATORS (does not save changes)
(2) REVIEW ERROR RATES FOR EACH DATA SOURCE: AGRICULTURE, BEDNETS, SEEDLINGS, LOANS, MARKETING
(3) REVIEW DIFFERENCES IN REPORTED/SEEN POSSESSIONS
(4) REVIEW SATISFACTION RATES ACROSS ENUMERATOR GROUPS
(5) FIND FILTHY DATA
(6) CREATE VARIABLES TO DEFINE ACCURACY
(7) COLLAPSE TO CREATE ACCURACY RATES (does not save changes directly)
(8) MERGE ACCURACY RATES BACK IN
(9) CHARACTERISTICS OF A GOOD ENUMERATOR (does not save changes)
***************/


/*************  (2) REVIEWING ERROR RATES FOR EACH DATA SOURCE *************/
use "$master/data/all_submissions_no_identity2.dta" , clear

gen  ________ERRORRATES________ = .
label var ________ERRORRATES________ "_________________________________________________"

* Create vars to indicate the true data we have on each respondent
local sources "ACTED BEDNET FORESTRY LOAN NRC D2D"

foreach x of local sources {
	gen is_`x'=1 if (source=="`x'" & dataconcern != 1)
	label var is_`x' "1=From `x'"
}
* D2D Respondents: We only want to analyze those who were: 1) found across all datasource, and 2) not a dataconcern
// 1) Adds a 1 for true data sources that Adam found that are currently listed as another source
replace is_D2D=1 if found==1 & source!="D2D" & dataconcern==.
// 2) Gets rid of the 1 for D2D respondents that were not marketed to
replace is_D2D=. if found!=1
// 2) So now all those marked were found
rename is_D2D is_D2DFOUND
label var is_D2DFOUND "1=Marketed to (or given free) across sources (sale/ngo)"
// Accounts for people that I got from Adam but were not marketed to/found -- no true data on these people.
generate is_D2DNOTFOUND=1 if (source=="D2D" & is_D2DFOUND!=1 & status=="Complete!")
label var is_D2DNOTFOUND "1=Not marketed to (have no data on resp)"
*Note: Note that is_D2DNOTFOUND is only for the D2D respondents. If Adam's marketers tried and failed to find a respondent from another datasource, this is not reflected in these variables. e.g. browse if full_hhid==1636125104, where Adam/my IDs match but you can't see that in these D2D variables.
/*************AGRICULTURE*************/

* Generate a few more variables
// 1 if at least 1 group was supported
generate groups_supported=1 if (groups_supprted_by_ngo==1 | groups_supprted_by_ngo==2 | groups_supprted_by_ngo==3 | groups_supprted_by_ngo==4)
replace groups_supported=0 if (groups_supprted_by_ngo==0 | groups_supprted_by_ngo==. & dataconcern!=2)
label var groups_supported "1=At least 1 grp rec support, else 0"

/* ACTED */
* browse enumerator source status group_inputs grp_tools personal_support pers_tools supp_by_acted if source=="ACTED" | source=="NRC"

* Create dummies if the ACTED respondents answered Yes to any of these questions:
local acted_questions "training group_inputs grp_tools  personal_support pers_tools supp_by_acted groups_supported"
foreach x of local acted_questions {
	// 1 if ACTED respondents said Yes to this question
	gen truth_acted_`x' = 0 if `x'!=1 & is_ACTED==1
	// Now all ACTED respondents have a 0/1 and other respondents are missing
	replace truth_acted_`x' =1 if `x'==1 & is_ACTED==1
	label var truth_acted_`x' "1=Said Yes to `x' & is from ACTED"
}
// Only people who said YES, they had received, should be counted here.
replace truth_acted_grp_tools = . if truth_acted_group_inputs==0
// Only people who said YES, they had received, should be counted here.
replace truth_acted_pers_tools = . if truth_acted_personal_support == 0

/* 1 - How many of these farming groups have been supported by an organization such as an NGO or by the government in some way since the beginning of 2010? (groups_supprted_by_ngo groups_supported) */
// Must fix those conducted before fix
replace truth_acted_groups_supported = . if include_in_agric==0

/* 5 - Have any organizations given inputs to you personally since the beginning of 2010? */
// Fix these after CKW followup - None of the 3 CKWs asked correctly (didn't talk to Otto Bosco)
replace truth_acted_personal_support = . if include_in_agric==0


/* 6 - What inputs have you personally received since the beginning of 2010? */
// Fixing these after following up with CKWs - None of the 3 CKWs asked correctly (but we didn't talk to Otto Bosco)
replace truth_acted_pers_tools = . if include_in_agric==0

/* 7.5 - Did more respondents tell CKWs that they had received BOTH group and personal support? */
// Start with group
gen truth_acted_group_and_pers_supp = 0 if truth_acted_group_inputs!=. | truth_acted_personal_support!=.
replace truth_acted_group_and_pers_supp = 1 if truth_acted_group_inputs==1 & truth_acted_personal_support==1
label var truth_acted_group_and_pers_supp "1=Said rec grp AND pers supp"

/* 7.5 - Was IPA still worse if we combine group tools and personal tools? */
gen truth_acted_group_or_pers_tools = 0 if truth_acted_grp_tools!=. | truth_acted_pers_tools!=.
replace truth_acted_group_or_pers_tools = 1 if truth_acted_grp_tools==1 | truth_acted_pers_tools==1
label var truth_acted_group_or_pers_tools "1=Said rec grp/pers supp, then grp or pers tools"

/* 8 - What are the names of any organizations that you have received agriculture services or inputs from since the beginning of 2010?  */

/* 8.5- How many enumerators were involved? */

/* 9- False positives of support from ACTED? */
// Of this group, 1 if said they were from ACTED but we don't have them as ACTED recipients
gen false_acted_supp_by_acted =1 if supp_by_acted==1 & is_ACTED!=1 & status=="Complete!"
// To decide who to include as ZEROS, I'm adding ZEROs to all respondents in the villages where either IPA/CKW reported a false positive.
replace false_acted_supp_by_acted= 0 if false_acted_supp_by_acted!=1 & is_ACTED!=1 & status=="Complete!" & (village_true=="acetcentral" | village_true=="aitakonya kiting" | village_true=="ajuku" | village_true=="arutcentral" | village_true=="awimon" | village_true=="boke" | village_true=="cetkana" | village_true=="idopo" | village_true=="kuluotit" | village_true=="laban" | village_true=="laminlawino" | village_true=="laminokure1" | village_true=="laneno" | village_true=="oguru(pukony)" | village_true=="omunjubi" | village_true=="onang" | village_true=="ongedo" | village_true=="opaya" | village_true=="opit" | village_true=="owak" | village_true=="pabaya" | village_true=="palami" | village_true=="paromo" | village_true=="patwol" | village_true=="pidaloro" | village_true=="pugwinyi" | village_true=="teolam" | village_true=="tugu")

label var false_acted_supp_by_acted "1=Said ACTED but not in true data; 0=All others in false villages"

/* 10 - Where were all these surveys conducted */


/* NRC */
/*
According to Bruce, all respondents received group support of some kind and recieved personal seeds in 2010. The contact farmers said they didn't recieve seeds in some villages, so I also analyze this without those villages
Note: Their memories could have made a difference here; it was awhile ago. And the data was poorer.
*/
// Add later: groups_supported personal_support pers_tools . Should add in 3 for supp_by_doesnotknow at some point
local nrc_questions "groups_supported group_inputs personal_support pers_seeds supp_by_nrc"

foreach x of local nrc_questions {
	// 1 if NRC respondents said that NRC was a supporting organization
	gen truth_nrc_`x' = 0 if `x'!=1 & is_NRC==1
	// Now all NRC respondents have a 0/1 and other respondents are missing
	replace truth_nrc_`x' =1 if `x'==1 & is_NRC==1
	label var truth_nrc_`x'  "1=Said Yes to `x' & is from NRC"
}

/* 1 - How many of these farming groups have been supported by an organization such as an NGO or by the government in some way since the beginning of 2010? (groups_supprted_by_ngo groups_supported) */
// Need to fix those surveys conducted before fix.
replace truth_nrc_groups_supported = . if include_in_agric==0

// Now, the way that I think we should report -- we learned two enumerators asked this question correctly before the fix. I argue we should include thier results.
// Omitting the CKWs that I'm not sure if they asked this correctly before the translation fix. But Francis Ochora and Bosco Gwoktoo asked this correctly before the fix
replace truth_nrc_personal_support = . if include_in_agric==0 & (enumerator!="Francis Ochora" & enumerator!="Bosco Gwoktoo")


/* 5.5 - Same question but without villages that the contact farmers said did not recieve personal seeds */
// The following villages did not get personal support from NRC:
replace truth_nrc_personal_support = . if village_true=="onyeyorwot" | village_true=="omunjubi" | village_true=="oryang" | village_true=="apem" | village_true=="olee(omel a)" | village_true=="orajaa" | village_true=="kuru"


/* 6 - What inputs have you personally received since the beginning of 2010?  Seeds */

// Francis Ochora and Bosco Gwoktoo
replace truth_nrc_pers_seeds = . if include_in_agric==0 & (enumerator!="Francis Ochora" & enumerator!="Bosco Gwoktoo")


/* 6.5 - Same question without the villages that the contact said didn't recieve seeds */
* The following villages did not get personal support from NRC:
replace truth_nrc_pers_seeds = . if village_true=="onyeyorwot" | village_true=="omunjubi" | village_true=="oryang" | village_true=="apem" | village_true=="olee(omel a)" | village_true=="orajaa" | village_true=="kuru"


/* 7.5 - Did more respondents tell CKWs that they had received BOTH group and personal support? */
gen truth_nrc_group_and_pers_supp = 0 if truth_nrc_group_inputs!=. | truth_nrc_personal_support!=.
replace truth_nrc_group_and_pers_supp = 1 if truth_nrc_group_inputs==1 & truth_nrc_personal_support==1
label var truth_nrc_group_and_pers_supp "1=Said rec grp AND pers supp"


// Of this group, 1 if said they were from ACTED but we don't have them as ACTED recipients
gen false_nrc_supp_by_nrc =1 if supp_by_nrc==1 & is_NRC!=1 & status=="Complete!"
// To decide who to include as ZEROS, I'm adding ZEROs to all respondents in the villages where either IPA/CKW reported a false positive.
replace false_nrc_supp_by_nrc= 0 if false_nrc_supp_by_nrc!=1 & is_NRC!=1 & status=="Complete!" & (village_true=="acetcentral" | village_true=="agwak" | village_true=="arutcentral" | village_true=="barlimo" | village_true=="cetkana(awoonyim)" | village_true=="kitimotima" | village_true=="olee(omel a)" | village_true=="ongedo" | village_true=="oroko" | village_true=="oryang" | village_true=="patwol")
label var false_nrc_supp_by_nrc "1=Said NRC but not in true data; 0=All others in false villages"

/* COMBINE NRC AND ACTED */

/* 1 - Did you name the org you received support from (ACTED or NRC)? */
// browse source truth_nrc_supp_by_nrc truth_acted_supp_by_acted truth_nrc_or_acted_supp if source=="ACTED" | source=="NRC" | source=="BEDNET"
generate truth_nrc_or_acted_supp = 0 if truth_nrc_supp_by_nrc!=. | truth_acted_supp_by_acted!=.
replace truth_nrc_or_acted_supp=1 if truth_nrc_supp_by_nrc==1 | truth_acted_supp_by_acted==1
label var truth_nrc_or_acted_supp "1=Named either NRC/ACTED"


/* 2 - Did you recieve group support (ACTED or NRC)?
generate truth_grp_supp_acted_or_nrc=0 if truth_nrc_group_inputs!= . | truth_acted_group_inputs!=.
replace truth_grp_supp_acted_or_nrc=1 if truth_nrc_group_inputs==1 | truth_acted_group_inputs==1
label var truth_grp_supp_acted_or_nrc "1=Said grp supp & is_NRC | is_ACTED"


*/
/* 3 - Did you recieve personal support (ACTED or NRC)?
generate truth_pers_supp_acted_or_nrc=0 if truth_acted_personal_support!=.  | truth_nrc_personal_support!=.
replace truth_pers_supp_acted_or_nrc=1 if truth_acted_personal_support==1 | truth_nrc_personal_support==1
label var truth_pers_supp_acted_or_nrc "1=Said pers supp & is_NRC | is_ACTED"


*/

/* 4 - What if we add up ALL agriculture questions per group? */
* Below are the questions used to define the overall accuracy rates. Lots of difficult decisions here about which to include. I have reasons for all (see the table in the Analsysi plan).
local truedatavars_agric truth_acted_training truth_acted_personal_support truth_acted_group_or_pers_tools truth_acted_supp_by_acted truth_nrc_group_inputs truth_nrc_supp_by_nrc
// sum the 1s in the trudatavars
egen total_err_per_survey_num_agric = rowtotal(`truedatavars_agric'), missing
label var total_err_per_survey_num_agric "Per survey, # correct AGRIC answers"
// add up the number of nonmissing values for truedatavars
egen total_err_per_survey_denom_agric = anycount(`truedatavars_agric'), values(0 1)
// In cases where there were no truth variables (D2DNOTFOUND), there is no denomenator
replace total_err_per_survey_denom_agric = . if total_err_per_survey_denom_agric==0
label var total_err_per_survey_denom_agric "Per survey, # asked AGRIC"

* Here comes the rate per survey:
gen acc_per_survey_agric = total_err_per_survey_num_agric / total_err_per_survey_denom_agric
***drop total_err_per_survey_denom_agric total_err_per_survey_num_agric
label var acc_per_survey_agric "Per survey for AGRIC, # correct / # asked "
replace acc_per_survey_agric = . if dataconcern==1

* Across all true data, how do the error rates between IPA/CKWs compare?


/*************BEDNETS*************/

local bednet_questions " bio_children pregnant_since_2009"
foreach x of local bednet_questions {
	// Create a binary for 1 if bednet respondents said yes to this question
	gen truth_bed_`x' = 0 if `x'!=1 & is_BEDNET==1
	// Now all bednet respondents have a 0/1 and other respondents are missing
	replace truth_bed_`x' =1 if `x'==1 & is_BEDNET==1
	label var truth_bed_`x'  "1=Said Yes to `x' & received net"
}

/* 1 - Do you have biological children? */


/* 2 - Have you been pregnant at any time since the beginning of 2009 until today? */
// We only asked this question if they said yes to bio children
replace truth_bed_pregnant_since_2009 = . if truth_bed_bio_children==0 | male==1


/* 3 - Did you visit a health clinic during and/or after your pregnancy for pre and post natal care?  */
// Look at all the people who said yes to being pregnant
generate truth_bed_hc_visit_once = 0 if truth_bed_pregnant_since_2009==1
label var truth_bed_hc_visit_once "1=Said visit HC during preg"
// Give a 1 if she said she went to a clinic
replace truth_bed_hc_visit_once = 1 if hc_visit_once==1 & truth_bed_pregnant_since_2009==1


/* 4 - Did you receive a mosquito bednet from the staff during one of your visits? */
generate truth_bed_rec_net_once = 0 if truth_bed_hc_visit_once==1
replace truth_bed_rec_net_once = 1 if rec_net_once==1 & truth_bed_hc_visit_once==1
label var truth_bed_rec_net_once "1=Said received net at HC"


/* 5 - What are the names of the health facilities from which you received the mosquito bednet(s)? */
// Starting with those that said they recieved.
generate truth_bed_hc_match=0 if  truth_bed_rec_net_once==1
label var truth_bed_hc_match "1=Reported HC==true data"
* Give them a 1 if they selected the same HC from the list as the HC we got the name from. Note: I was strict here. Even if they were 'close' and entered another HC in their subcounty, I did not give them credit. There were a few overlaps like Lakwana>Awoo. Or if it was Lalogi and the true was Lalogi Opit - sorry, no match.
replace truth_bed_hc_match =1 if hc_name_awach==1 & bednet_name_of_hc=="AWACH HEALTH CENTRE"
replace truth_bed_hc_match =1 if hc_name_bobi==1 & bednet_name_of_hc=="BOBI HEALTH CENTRE III"
replace truth_bed_hc_match =1 if hc_name_paicho==1 & bednet_name_of_hc=="KAL ALI HEALTH CENTRE"
replace truth_bed_hc_match =1 if hc_name_lak_laneno==1 & bednet_name_of_hc=="LAKWANA LANENO BER HEALTH CENTRE III"
replace truth_bed_hc_match =1 if hc_name_lalogi==1 & bednet_name_of_hc=="LALOGI HEALTH CENTRE IV"
replace truth_bed_hc_match =1 if hc_name_lalogi_opit==1 & bednet_name_of_hc=="LALOGI OPIT HEALTH CENTRE III"
replace truth_bed_hc_match =1 if hc_name_odek==1 & bednet_name_of_hc=="ODEK HEALTH CENTRE III"
replace truth_bed_hc_match =1 if hc_name_ongako==1 & bednet_name_of_hc=="ONGAKO HEALTH CENTRE III"
replace truth_bed_hc_match =1 if hc_name_palaro==1 & bednet_name_of_hc=="PALARO HEALTH CENTRE III"
replace truth_bed_hc_match =1 if hc_name_patiko==1 & bednet_name_of_hc=="PATIKO HEALTH CENTRE III"
// Wow. My mistake. I left "Paicho Cwero" off of the multiple choice list and these are enums who selected "Other" and specified this. Great work. (5 from each org)
replace truth_bed_hc_match =1 if submissionid==43693 | submissionid==36237 | submissionid==43692 | submissionid==31918 | submissionid==28591 | submissionid==42460 | submissionid==42461 | submissionid==42463 | submissionid==45291 | submissionid==45252


/* 6 - Did the gender of the enumerator matter more? */


bysort org: tab truth_bed_bio_children gender
// Nothing
bys gender: reg truth_bed_bio_children enum_is_ipa


bysort org: tab truth_bed_pregnant_since_2009 gender
// IPA is only better when the enumerators are male
bys gender: reg truth_bed_pregnant_since_2009 enum_is_ipa


gen male_enum = gender==1
label var male_enum "1=Enumerator is a gentleman"
// Interaction
gen enum_is_ipa_male = enum_is_ipa*male_enum
label var enum_is_ipa_male "Interact: enum_is_ipa*male_enum"


/* 6 - Did knowing the family matter? */
gen knows_fam = 1 if rel_family!= 1
label var knows_fam "1=Enum knows family"
replace knows_fam = 0 if knows_fam!=1 & status=="Complete!"


// Not significant
bys knows_fam: reg truth_bed_pregnant_since_2009 enum_is_ipa
bysort org: tab truth_bed_pregnant_since_2009 knows_fam

bysort org: tab truth_bed_pregnant_since_2009 gender

label var gender "1=Enum is male"

// Following Pia's orders:

generate enum_is_ckw=1 if enum_is_ipa==0
replace enum_is_ckw=0 if enum_is_ipa==1
label var enum_is_ckw "1=Enumerator is a CKW"
// Generate interaction term of CKWs that knows family
gen ckw_knowsfam =  enum_is_ckw*knows_fam
label var ckw_knowsfam "Interact: enum_is_ckw*knows_fam"


gen int_gender_knowsfam =  gender*knows_fam
label var int_gender_knowsfam "Interact: gender*knows_fam"


/* 7 - What if we add up ALL bednet questions per group? */
local truedatavars_bed truth_bed_bio_children truth_bed_pregnant_since_2009 truth_bed_hc_visit_once truth_bed_rec_net_once  truth_bed_hc_match
// sum the 1s in the trudatavars - Per survey, # correct BEDNET answers
egen total_err_per_survey_num_bed = rowtotal(`truedatavars_bed'), missing
// add up the number of nonmissing values for truedatavars - Per survey, # asked BEDNET
egen total_err_per_survey_denom_bed = anycount(`truedatavars_bed'), values(0 1)
// In cases where there were no truth variables (D2DNOTFOUND), there is no denomenator
replace total_err_per_survey_denom_bed = . if total_err_per_survey_denom_bed==0

* Here comes the rate per survey:
gen acc_per_survey_bed = total_err_per_survey_num_bed / total_err_per_survey_denom_bed
**drop total_err_per_survey_denom_bed total_err_per_survey_num_bed
label var acc_per_survey_bed "Per survey for BEDNET, # correct / # asked "
replace acc_per_survey_bed = . if dataconcern==1

* Across all true data, how do the error rates between IPA/CKWs compare?


/*************SEEDLINGS*************/

local seed_questions "received_seedlings"
foreach x of local seed_questions {
	// Create a binary for 1 if respondents said yes
	gen truth_seed_`x' = 0 if `x'!=1 & is_FORESTRY==1
	// Now all SEEDLING respondents have a 0/1 and other respondents are missing
	replace truth_seed_`x' =1 if `x'==1 & is_FORESTRY==1
	label var truth_seed_`x'  "1=Said Yes to `x' & is from FORESTRY"
}

/*************LOANS*************/
* browse source status have_applied_loan taken_loans amount_borrowed_loan1 amount_borrowed_loan2 amount_borrowed_loan3 amount_borrowed_loan4 amount_borrowed_loan5 if source=="LOAN" | source=="NRC"

local loan_questions "have_applied_loan taken_loans"
foreach x of local loan_questions {
	// Create a binary for 1 if respondents said yes
	gen truth_loan_`x' = 0 if `x'!=1 & is_LOAN==1
	// Now all LOAN respondents have a 0/1 and other respondents are missing
	replace truth_loan_`x' =1 if `x'==1 & is_LOAN==1
	label var truth_loan_`x'  "1=Said Yes to `x' & is from LOAN"
}
// Removing those people in our data that took the loan before 2010 (as survey says)
replace truth_loan_taken_loans = . if loan_after_2010!=1

/* 1 - Have you ever applied to request a loan from a VSLA or SACCO?  */


bysort org: tab from_geo truth_loan_have_applied

/* 2 - Since the beginning of 2010, have you taken any loans from a VSLA or SACCO?   */


/* 2.5 - What enumerators were involved?


bysort org: tab parish_true truth_loan_have_applied // IPA did very well in labwoch
bysort org: tab subcounty_true truth_loan_have_applied // IPA did very well in Koro
*/

******Loan Discrepancy

generate loan_diff=0 if truth_loan_taken_loans==1
la var loan_diff "Deviation from True Loan Amount"
// Create accuracy var based on distance from true value

local loans_taken "amount_borrowed_loan1 amount_borrowed_loan2 amount_borrowed_loan3 amount_borrowed_loan4 amount_borrowed_loan5"
egen all = rowtotal(amount_borrowed_loan*), m
forval i = 1/5{
	*replace amount_borrowed_loan`i' = 0 if mi(amount_borrowed_loan`i') & !mi(all)
	gen diff1`i' = amount_borrowed_loan`i' - loan1_amount
	gen diff2`i' = amount_borrowed_loan`i' - loan2_amount

	gen absdiff1`i' = abs(diff1`i')
	gen absdiff2`i' = abs(diff2`i')
	if `i' == 5{
		egen min1 = rowmin(absdiff1*)
		egen min2 = rowmin(absdiff2*)
		forval x = 1/5{
			gen cand1`x' = diff1`x' if min1 == absdiff1`x'
			gen cand2`x' = diff2`x' if min2 == absdiff2`x'
		}
	}
}
egen loan_disc1 = rowtotal(cand1*) if !mi(loan1_amount) | !mi(loan2_amount), m
replace loan_disc1 = abs(0 - loan1_amount) if mi(all)
la var loan_disc1 "Discrepancy between True and Self-reported Loan Amounts"
egen loan_disc2 = rowtotal(cand2*) if !mi(loan1_amount) | !mi(loan2_amount), m
// we just stick to loan_disc1 since we only got 4 obs in this variable and no much difference
replace loan_disc2 = abs(0 - loan2_amount) if mi(all)
gen loan_disc = loan_disc1
replace loan_disc = (loan_disc1 + loan_disc2) /2 if !mi(loan2_amount)
replace loan_disc = 0 if truth_loan_taken_loans == 0
egen loan = rowtotal(loan1_amount loan2_amount), m
replace loan = loan / 2 if !mi(loan1_amount) & !mi(loan2_amount)
replace loan_disc = . if mi(loan)

ren loan_disc loan_disc_nom
gen loan_disc = abs(loan_disc_nom)

/* 4 - Did it make a difference in the villages that were mobilized poorly by IPA?
*Q: Akeca and Laneno - 18 Oct - The mobilizer gave the appt sheets to the LC1 who distributed them and told people that we would come bringing money. I expect people to lie in these villages

*Answer: CKWs did only a few and IPA did pretty well in these two villages. (BEDNET AND D2D)

*Q: Barogol / Angaba / Palemi - Were mobilized using the LC1 to deliver names. Effect on data?


*Answer: Nope, we did quite well here (LOANs)
*/
/* 4 - What if we add up ALL loan questions per group? */
* Below are the questions used to define the overall accuracy rates. Lots of difficult decisions here!
local truedatavars_loan truth_loan_have_applied_loan truth_loan_taken_loans
// sum the 1s in the trudatavars
egen total_err_per_survey_num_loan = rowtotal(`truedatavars_loan'), missing
label var total_err_per_survey_num_loan "Per survey, # correct LOAN answers"
// add up the number of nonmissing values for truedatavars
egen total_err_per_survey_denom_loan = anycount(`truedatavars_loan'), values(0 1)
// In cases where there were no truth variables (D2DNOTFOUND), there is no denomenator
replace total_err_per_survey_denom_loan = . if total_err_per_survey_denom_loan==0
label var total_err_per_survey_denom_loan "Per survey, # asked LOAN"

* Here comes the rate per survey:
gen acc_per_survey_loan = total_err_per_survey_num_loan / total_err_per_survey_denom_loan
**drop total_err_per_survey_denom_loan total_err_per_survey_num_loan
label var acc_per_survey_loan "Per survey for LOAN, # correct / # asked "
replace acc_per_survey_loan = . if dataconcern==1

* Across all true data, how do the error rates between IPA/CKWs compare?


/*************MARKETING *************/

* Create var of people who were visited BEFORE they were interviewed
// 1 if this is true
generate marketed_before_interview = 1 if date_interviewed > date_wave1 & is_D2DFOUND==1
// Otherwise zero, so all 'is_D2DFOUND' are either 1 or 0
replace marketed_before_interview = 0 if marketed_before_interview!=1 & is_D2DFOUND==1
label var marketed_before_interview "1=Visited by marketer, then interviewed"

* The people who were marketed twice before interview are special
generate marketed_twice_before_interview = 1 if date_wave2<date_interviewed & is_D2DFOUND==1
// Just so all 'is_D2DFOUND' are either 1 or 0
replace marketed_twice_before_interview = 0 if marketed_twice_before_interview!=1 & is_D2DFOUND==1
// These are three people that weren't looked for in Wave 2.
replace marketed_twice_before_interview = 0 if submissionid==61869 | submissionid==62191 | submissionid==66168
label var marketed_twice_before_interview "1=Wave1, then Wave2, then interviewed"

* tab ngo enum_is_ipa if is_D2DFOUND==1 & marketed_before_interview == 1, missing // 1072 - The CKWs lost 100 respondents but its still distributed.

/* SELL */

/* Check for unmatched matches (waiting on Adam):

*/

local sell_questions "market_approach"
foreach x of local sell_questions {
	// Create a binary: zero if respondents did not say yes (1) to 'market_approach' question but were found by the for profit
	gen truth_sell_`x' = 0 if `x'!=1 & (is_D2DFOUND==1 & sale==1)
	// 1 if said yes to 'market approach'. Now all SALE respondents have a 0/1 and other respondents are missing
	replace truth_sell_`x' =1 if `x'==1 & (is_D2DFOUND==1 & sale==1)
	// They were truthful if they hadn't been marketed to yet.
	replace truth_sell_`x' =.  if marketed_before_interview!=1
	label var truth_sell_`x'  "1=Said Yes to `x' & was sell/found/interv"
}

/* 1 - Have you or your spouse ever been approached by someone who came to your door and tried to sell a health drug or product? */


/* 1.1 - Who were the bad enumerators, and where?
bysort org: tab enumerator truth_sell_market_approach // Irene did horribly. Aber Judith pulled down CKW.


*/

/* 2 - When was the last time someone tried to sell a health drug or product at your door? */

* Create a dummy for when the wave date is within the reported window
generate days_since_sale = date_interviewed - date_wave1 if truth_sell_market_approach==1
// These are the people that were marketed twice - need to use the wave2 date
replace days_since_sale = (date_interviewed - date_wave2) if (marketed_twice_before_interview==1 & truth_sell_market_approach==1)
label var days_since_sale "(date interviewed - date_wave1) if sold product"
generate truth_sell_last_date = 0 if truth_sell_market_approach==1
label var truth_sell_last_date "1=Wave date was in reported window (sale)"

// 2 Weeks: See above (free var)
replace truth_sell_last_date = 1 if days_since_sale<=14 							     & market_last==1 & truth_sell_market_approach==1
// 3-4 weeks: See above
replace truth_sell_last_date = 1 if (days_since_sale>14 & days_since_sale<=28) & market_last==2 & truth_sell_market_approach==1
// 5-7 weeks: See above
replace truth_sell_last_date = 1 if (days_since_sale>28 & days_since_sale<=49) & market_last==3 & truth_sell_market_approach==1
// 2-3 months; See above
replace truth_sell_last_date = 1 if (days_since_sale>50 & days_since_sale<=85) & market_last==4 & truth_sell_market_approach==1
// 4-5 months; See above
replace truth_sell_last_date = 1 if (days_since_sale>86 & days_since_sale<=142) & market_last==5 & truth_sell_market_approach==1
* I'm making a few judgement calls here for some of these where the dates are so close and because of how I set up the var, they should get credit.
replace truth_sell_last_date = 1 if submissionid==53409 | submissionid==36972 | submissionid==66168 | submissionid==44651 | submissionid==44652 | submissionid==42397 | submissionid==47031 | submissionid==42454 | submissionid==32139 | submissionid==45093 | submissionid==40896 | submissionid==40026 | submissionid==53407 | submissionid==47426 | submissionid==35048 | submissionid==34288 | submissionid==47429 | submissionid==42434 | submissionid==44845 | submissionid==45653 | submissionid==45659 | submissionid==47428 | submissionid==42455 | submissionid==47427 | submissionid==44653 | submissionid==54610 | submissionid==39444


/* 3 - What product did the person try to sell to you or your spouse?
Logic: For this section, the data is correct if: 1) They had said they'd been approached by marketer, 2) the products match, and 3) if they'd been visited already for Wave 2 then they which product will they say?
*/

// Panadol is 1 in Adam's data
generate truth_sell_product =1 if sell_prod_pan==1 & productassigned==1 & truth_sell_market_approach==1
label var truth_sell_product "1=Reported product==true data & for profit"
// Deworm is 2 in Adam's data
replace truth_sell_product =1 if sell_prod_deworm==1 & productassigned==2 & truth_sell_market_approach==1
// ORS and Z are 3 in Adam's data
replace truth_sell_product =1 if sell_prod_ors==1 & productassigned==3 & truth_sell_market_approach==1
// ORS and Z are 3 in Adam's data
replace truth_sell_product =1 if sell_prod_zinkid==1 & productassigned==3 & truth_sell_market_approach==1
// If they didn't match but told the truth about marketing, then 0
replace truth_sell_product=0 if truth_sell_product!=1 & truth_sell_market_approach==1

* Need to fix the ones that were visited twice
* browse if marketed_twice_before_interview==1 & truth_sell_market_approach==1
// Panadol is 1 in Adam's data
replace truth_sell_product =1 if sell_prod_pan==1 & productassigned2==1 & truth_sell_market_approach==1 & marketed_twice_before_interview==1
// Deworm is 2 in Adam's data
replace truth_sell_product =1 if sell_prod_deworm==1 & productassigned2==2 & truth_sell_market_approach==1 & marketed_twice_before_interview==1
// ORS and Z are 3 in Adam's data
replace truth_sell_product =1 if sell_prod_ors==1 & productassigned2==3 & truth_sell_market_approach==1 & marketed_twice_before_interview==1
// ORS and Z are 3 in Adam's data
replace truth_sell_product =1 if sell_prod_zinkid==1 & productassigned2==3 & truth_sell_market_approach==1 & marketed_twice_before_interview==1
// ORS and Z are 3 in Adam's data
replace truth_sell_product =1 if sell_prod_aquas==1 & productassigned2==4 & truth_sell_market_approach==1 & marketed_twice_before_interview==1


/* 4 - What organization was this person from?
Logic:  For this section, the data is correct if: 1) They had said they'd been approached by marketer, 2) their answer is the same as Adam's assignment of NGO/For profit */

// 1 in my data is NGO;
generate truth_sell_org = 1 if where_market==1 & ngo==1 & truth_sell_market_approach==1
label var truth_sell_org "1=Knew sale org was ngo/profit "
// 2 in my data is For profit;
replace truth_sell_org = 1 if where_market==2 & ngo==0 & truth_sell_market_approach==1
// If they did not match as ngo/profit, but told truth about marketed to. Then 0
replace truth_sell_org = 0 if truth_sell_org!=1 & truth_sell_market_approach==1
// Again, need to fix if was visited in 2nd wave last. These two people said it was an NGO (all for profit)
replace truth_sell_org = 0 if where_market==1 & marketed_twice_before_interview==1 & truth_sell_market_approach==1
* replace truth_sell_org = . if where_market==.d // Should we count it against the enumerator if the person does not know? For now, yes.

/* 5 - Did you or your spouse purchase the product?
Logic: For this section, the data is correct if: 1) They had said they'd been approached by marketer, 2) their answer is the same as Adam's for if purchased*/

// This is the sample of people who said they were marketed to.
generate truth_sell_purchase = 0 if truth_sell_market_approach==1
label var truth_sell_purchase "1=Said purchased and did or vice versa"

// If said marketed to, and said purchased and did purchase
replace truth_sell_purchase = 1 if (sale_purchased==1 & market_purchase==1) & truth_sell_market_approach==1
// If said marketed to, and said did NOT purchased and did not
replace truth_sell_purchase = 1 if (sale_purchased==0 & market_purchase==0) & truth_sell_market_approach==1
// submissionid==35046 was empty here.
replace truth_sell_purchase = . if submissionid==35046
* Account for wave2:
// reset all 16 to zero
replace truth_sell_purchase = 0 if truth_sell_market_approach==1 & marketed_twice_before_interview==1
// Same as above but for these 16
replace truth_sell_purchase = 1 if (sale_purchased2==1 & market_purchase==1) & truth_sell_market_approach==1 & marketed_twice_before_interview==1
replace truth_sell_purchase = 1 if (sale_purchased2==0 & market_purchase==0) & truth_sell_market_approach==1 & marketed_twice_before_interview==1


/* 6 - What did you or your spouse purchase? (market_name)*/
* Logic: For this section, the data is correct if: 1) They had said they said they had purchased, and 2) their answer is the same as Adam's for which product

// Our group are people are those who were if they were honest and said they had purchased (marketpurchase==1)
generate truth_sell_purchase_product = 0 if truth_sell_purchase==1 & market_purchase==1
label var truth_sell_purchase_product "1=Reported product==true data & sold"
// Panadol is 1 in Adam's data
replace truth_sell_purchase_product =1 if market_name==1 & productassigned==1 & truth_sell_purchase==1 & market_purchase==1
// 2 is deworming in Adam's data
replace truth_sell_purchase_product =1 if market_name==2 & productassigned==2 & truth_sell_purchase==1 & market_purchase==1
// 3 is Z and ORS
replace truth_sell_purchase_product =1 if market_name==3 & productassigned==3 & truth_sell_purchase==1 & market_purchase==1
// 3 is Z and ORS
replace truth_sell_purchase_product =1 if market_name==4 & productassigned==3 & truth_sell_purchase==1 & market_purchase==1

* Wave2 again:
// If they were correct about purchaseing, start with a zero
replace truth_sell_purchase_product = 0 if truth_sell_purchase==1 & market_purchase==1 & marketed_twice_before_interview==1
// Panadol is 1 in Adam's data
replace truth_sell_purchase_product =1 if market_name==1 & productassigned2==1 & truth_sell_purchase==1 & market_purchase==1 & marketed_twice_before_interview==1
// 2 is deworming in Adam's data
replace truth_sell_purchase_product =1 if market_name==2 & productassigned2==2 & truth_sell_purchase==1 & market_purchase==1 & marketed_twice_before_interview==1
// 3 is Z and ORS
replace truth_sell_purchase_product =1 if market_name==3 & productassigned2==3 & truth_sell_purchase==1 & market_purchase==1 & marketed_twice_before_interview==1
// 3 is Z and ORS
replace truth_sell_purchase_product =1 if market_name==4 & productassigned2==3 & truth_sell_purchase==1 & market_purchase==1 & marketed_twice_before_interview==1
// Aquasafe
replace truth_sell_purchase_product =1 if market_name==7 & productassigned2==4 & truth_sell_purchase==1 & market_purchase==1 & marketed_twice_before_interview==1
*  Finally - they look great.

/* 7 - False positives of marketers */
* Note: I don't think we should include this given the overlap in HHs that we don't know about
gen false_sell_market_approach= 0 if market_approach!=1 & is_D2DFOUND!=1
label var false_sell_market_approach "1=Said marketed to (sell). Wasn't (maybe)."
replace false_sell_market_approach =1 if market_approach==1 & is_D2DFOUND!=1


/* FREE */
local free_questions "approached_free deworm_free pan_free ors_free z_free"
foreach x of local free_questions {
	gen truth_free_`x' = 0 if `x'!=1 & (is_D2DFOUND==1 & sale==0)
	// Now all FREE respondents have a 0/1 and other respondents are missing
	replace truth_free_`x' =1 if `x'==1 & ( is_D2DFOUND==1 & sale==0)
	// They were truthful if they hadn't been marketed to yet.
	replace truth_free_`x' =.  if marketed_before_interview!=1
	replace truth_free_`x' =.  if free_accepted!=1
	label var truth_free_`x'  "1=Said Yes to `x' & was free/found/interv"
}
// Eliminate those who didn't get this product
replace truth_free_deworm_free = . if productassigned!=2
replace truth_free_pan_free = . if productassigned!=1
replace truth_free_ors_free = . if productassigned!=3
replace truth_free_z_free = . if productassigned!=3

/* 2 - When was the last time someone came to your door and gave you a free health drug or product?
Note: Don't need to account for Wave 2 since it was only SELLING */

* Create a variable 1 if wave date is within reported window
generate days_since_free = date_interviewed - date_wave1 if truth_free_approached_free==1
label var days_since_free "(date interviewed - date_wave1) if given free"
generate truth_free_last_date = 0 if truth_free_approached_free==1
label var truth_free_last_date "1=Wave date was in reported window (free)"
// 2 Weeks: If date was 14 days ago and that is what the resp said, and answered previous question
replace truth_free_last_date = 1 if days_since_free<=14 							     & market_last_free==1 & truth_free_approached_free==1
// 3-4 weeks: If date was more than 14 but less than 28
replace truth_free_last_date = 1 if (days_since_free>14 & days_since_free<=28) & market_last_free==2 & truth_free_approached_free==1
// 5-7 weeks. Less than 7*7
replace truth_free_last_date = 1 if (days_since_free>28 & days_since_free<=49) & market_last_free==3 & truth_free_approached_free==1
// 2-3 months; 8-12 weeks:
replace truth_free_last_date = 1 if (days_since_free>50 & days_since_free<=85) & market_last_free==4 & truth_free_approached_free==1
// 4-5 months; up to 20 weeks 86 + 56 days (8 weeks)
replace truth_free_last_date = 1 if (days_since_free>86 & days_since_free<=142) & market_last_free==5 & truth_free_approached_free==1
*  Judgement calls when my var was too strict:
replace truth_free_last_date = 1 if submissionid==33459 | submissionid==33521 | submissionid==33600  | submissionid==34110 | submissionid==36363 | submissionid==36369 | submissionid==36358 | submissionid==36359 | submissionid==36365 | submissionid==36362 | submissionid==34000 | submissionid==34109 | submissionid==42413 | submissionid==42414 | submissionid==40083 | submissionid==39118 | submissionid==38629 | submissionid==44637 | submissionid==44636 | submissionid==44638 | submissionid==43499 | submissionid==43503 | submissionid==53887 | submissionid==44041 | submissionid==54057 | submissionid==49482 | submissionid==49272 | submissionid==46231 | submissionid==52653 | submissionid==52651 | submissionid==46233 | submissionid==46232 | submissionid==53351 | submissionid==66182

/* 3 - What product did the person give you or your spouse for free?
Logic: For this section, the data is correct if: 1) They had said they'd been approached by free, 2) the products match, and 3) if they'd been visited already for Wave 2 then they which product will they say?*/

// 1 is Panadol for both
generate truth_free_product =1 if free_products==1 & productassigned==1 & truth_free_approached_free==1
label var truth_free_product "1=Reported free product==true data"
// 2 is Deworming for both
replace truth_free_product =1 if free_products==2 & productassigned==2 & truth_free_approached_free==1
// 3 is ORS for both
replace truth_free_product =1 if free_products==3 & productassigned==3 & truth_free_approached_free==1
// 4 is Zinkid for me, 3 is Zinkid for Adam
replace truth_free_product =1 if free_products==4 & productassigned==3 & truth_free_approached_free==1
replace truth_free_product=0 if truth_free_product!=1 & truth_free_approached_free==1

bysort org: tab productassigned truth_free_product, row

/* 3.1 - Who were the bad enumerators, and where?

*/

/* 4 - What organization was this person from?
Logic:  For this section, the data is correct if: 1) They had said they'd been approached by free, 2) their answer is the same as Adam's assignment of NGO/For profit */

// 1 in my data is NGO;
generate truth_free_org = 1 if where_free==1 & ngo==1 & truth_free_approached_free==1
// 2 in my data is For profit;
replace truth_free_org = 1 if where_free==2 & ngo==0 & truth_free_approached_free==1
// If they did not match as ngo/profit, but told truth about marketed to. Then 0
replace truth_free_org = 0 if truth_free_org!=1 & truth_free_approached_free==1
label var truth_free_org "1=Knew free org was ngo/profit "


bysort org: tab truth_free_org ngo

/* 5 - Did you or your spouse accept the product? (accept) */
// This is the sample of people who said they were marketed to.
generate truth_free_accept = 0 if truth_free_approached_free==1
label var truth_free_accept "1=Said accepted and did in D2D data"
replace truth_free_accept = 1 if (free_accepted==accept) & truth_free_approached_free==1
// These were incomplete (skipped)
replace truth_free_accept = . if submissionid==39732 | submissionid==47161 | submissionid==36459 | submissionid==44018 | submissionid==32053 | submissionid==30251


/* 6 - In the past 6 months, have you or your spouse received a condom for free? */
// Create var with zero for everyone who received a condom
generate truth_condom = 0 if condom_received==1
// Replace with 1 if the person reported receiving a condom
replace truth_condom = 1 if condom==1 & condom_received==1
label var truth_condom "1=Said rec condom and did in D2D data"
replace truth_condom = . if dataconcern!=.


// Lets dissect this by gender

bysort org: tab truth_condom gender, column
// Nothing
bys gender: reg truth_condom enum_is_ipa


/* 7 - What if we add up ALL marketing questions per group? */
local truedatavars_market truth_sell_market_approach truth_sell_last_date truth_sell_product truth_sell_org truth_sell_purchase truth_sell_purchase_product truth_free_approached_free truth_free_last_date truth_free_product truth_free_org truth_free_accept truth_condom
// Per survey, # correct MARKETING answers
egen total_err_per_survey_num_market = rowtotal(`truedatavars_market'), missing
// Per survey, # asked MARKETING
egen total_err_per_survey_d_market = anycount(`truedatavars_market'), values(0 1)
// In cases where there were no truth variables (D2DNOTFOUND), there is no denomenator
replace total_err_per_survey_d_market = . if total_err_per_survey_d_market==0

* Here comes the rate per survey:
gen acc_per_survey_market = total_err_per_survey_num_market / total_err_per_survey_d_market
**drop total_err_per_survey_d_market total_err_per_survey_num_market
label var acc_per_survey_market "Per survey for MARKETING, # correct / # asked "
replace acc_per_survey_market = . if dataconcern==1

* Across all true data, how do the error rates between IPA/CKWs compare?


/*************(3) REVIEWING DIFFERENCES IN REPORTED/SEEN POSSESSIONS*************/
* For sections 3-4, need to eliminate the answers to these questions from the dataconcerns
foreach var of varlist bednets beddings stoves goats bikes hh_consent heard_ckw ckw_sat researcher_times research_sat {
	capture replace `var' =. if dataconcern==1
}
local hh_ver "bednets beddings stoves goats bikes "
foreach x of local hh_ver {
	gen `x'_difference = (`x' - `x'_seen)
	label var `x'_difference  "`x' reported minus `x' seen"
	generate `x'_undereport = 1 if `x'_difference < 0
	replace `x'_undereport = 0 if `x'_difference!=. & `x'_undereport!=1
	label var `x'_undereport "1=Respondent reported < `x' seen"
	generate `x'_reportcorrect = 1 if `x'_difference == 0
	replace `x'_reportcorrect = 0 if `x'_difference!=. & `x'_reportcorrect!=1
	label var `x'_reportcorrect "1=Respondent reported==`x' seen"
	generate `x'_overreport = 1 if `x'_difference > 0
	replace `x'_overreport = 0 if `x'_difference!=. & `x'_overreport!=1
	replace `x'_overreport = . if hh_consent!=1
	label var `x'_overreport "1=Respondent reported > `x' seen"
}

/* Note:
Negative numbers mean the respondent UNDER reported (the enumerator saw more than the respondent had reported )
Positive numbers mean the respondent OVER reported (the enumerator saw fewer than the respondent had reported
*/


/* DIFFERENCE TOTALS - We need to graph this */

local hh_ver2 "bednets beddings stoves goats bikes "
foreach x of local hh_ver2 {
	generate `x'_total = 1 if `x'_undereport==1
	replace `x'_total = 2 if `x'_reportcorrect==1
	replace `x'_total = 3 if `x'_overreport==1
	label var `x'_total "Does reported==seen for `x'?"
	label define `x'_totalL 1 "1) Under reported" 2 "2) Reported same" 3 "3) Over reported"
	label values `x'_total `x'_totalL
}


/* 6 - Can I have permission to enter your home? */

local hh "hh_consent"
foreach x of local hh {
	gen refused_`x' = 1 if `x'==2
	replace refused_`x' =0 if `x'==1
	replace refused_`x' = . if dataconcern!=.
	label var refused_`x'  "1=Refused enum to enter HH"
}

/*************(4) REVIEWING SATISFACTION RATES ACROSS ENUMERATOR GROUPS*************/

/* 1 - Before today, had you ever heard of the Community Knowledge Worker program? This accepts a Y/N response but the Acholi asks for the respondents level of satisfaction with the program -- which is a question that also comes later. )*/
// This question was translated incorrectly
replace heard_ckw = . if include_in_agric==0


/* 2 - Before today, what was your level of satisfaction with services provided by Community Knowledge Workers – including both agriculture information services and research?  */
* Note: Respondents are only asked this if they say YES to #1
// Was only sopposed to ask this question if they had heard of the program. Most conservative to omit the beginning ones.
replace heard_ckw = . if include_in_agric==0


/* 3 - Before today, how many times have you been interviewed by a researcher like me who came from outside your community?  */
* browse if researcher_times==. & status=="Complete!"


//Note: Tab this and you'll see that 11 means "more than 10" so this is imperfect.

/* 4 - Before today, what was your level of satisfaction with other researchers who have come into this community to conduct interviews?  */
* Note:  This second question stresses to include CKWs as well as outside researchers. This is a translation mistake. Weird to analyze so I'm not including.


// Need a new var to only look at those cases
generate research_sat_clean = research_sat if status=="Complete!" & researcher_times!=0
label var research_sat_clean "research_sat w/o times==0"
move research_sat_clean research_sat


/*************(5) FIND FILTHY DATA ************
This section looks at the following in search of filthy data:
1 - AGES -- How frequently was each group off when comparing # of children with the # of ages entered?
2 - PHONE NUMBERS - How clean are phone numbers?
3 - HH POSSESSIONS - Check HH possessions to see the # that are 3 SD away from mean
4 - LOAN AMOUNTS - How clean are the loan amounts?
5 - SKIPPED QUESTIONS - How many questions did enumerators skip incorrectly?
6 - QUALITATIVE FEEDBACK - How many characters did each org enter for the qualitative feedback questions?
7 - LENGTH OF SURVEY - Do the times that were entered make sense?
8 - BUY FROM GOVT - How often did enums say they bought health products from the govt?
8 - FREE FROM FOR PROFITS - How often did enums say they *typically* recieve free products from for profits?
9- WRONG ID BY ENUM - How often did enumerators enter the wrong ID?
10 - WRONG RESPONDENT AGE OR GENDER - How often did entered data differ from true data?
*/

/* 1 - AGES -- How frequently was each group off when comparing # of children with the # of ages entered?
Remember these gotchas:
--If the respondent has only one child, the phone still asks to add group.
--Even if you enter 0, a question appears that says “What are all of the ages of children in this household”. This question isn’t required so hopefully they will just skip it, but it is incorrect/confusing.
--Zero for the age is supposed to mean a baby
*/

* Count children to make sure number of ages entered = number of children in household
gen childyn = 0
gen check_num_kids = 0
label var check_num_kids "1=# kids!=entered ages"
forvalues i=1(1)19 {
	gen child`i'yn = 0
	qui replace child`i'yn = 1 if what_is_the_childs_age_`i'!=.
	qui replace child`i'yn = 0 if child`i'yn ==.
	qui replace check_num_kids = check_num_kids + child`i'yn
}

* Drop variables used to count
foreach var of varlist child*yn {
	drop `var'
}
// Move check number to be with number entered by enumerator
move check_num_kids children_16

* Show enumerator errors if number of kids' ages doesn't equal number stated before
generate children_not_equal = 1 if children_16!=check_num_kids & status=="Complete!"
replace children_not_equal = 0 if children_16==check_num_kids & status=="Complete!"
label var children_not_equal "1=Entered ages != # children"
*  Tab


* How large was the difference?  */
generate children_diff = abs(check_num_kids - children_16)
// don't care about when they were correct
replace children_diff = . if children_diff==0
label var children_diff "Diff between # children & ages"


* 4.2 - Negative interest amounts are errors
generate interestamt1 =  total_loan1- amount_borrowed_loan1
label var interestamt1 "Amount of interested of 1st loan"
generate interestamt2 =  total_loan2- amount_borrowed_loan2
label var interestamt2 "Amount of interested of 2nd loan"

// 1 if this is negative
generate interestamt_neg1 = 1 if (total_loan1- amount_borrowed_loan1 < 0)
replace interestamt_neg1 = 0 if interestamt_neg1!=1 & status=="Complete!"
generate interestamt_neg2 = 1 if (total_loan2 - amount_borrowed_loan2 < 0)
replace interestamt_neg2 = 0 if interestamt_neg2!=1 & status=="Complete!"
generate interestamt_neg_total = interestamt_neg1 + interestamt_neg2
drop interestamt_neg1 interestamt_neg2
label var interestamt_neg_total "# times survey has negative interest amt"


* Zero interst loans are errors (assumption)
egen interestamt_zero = anycount(interestamt1 interestamt2), values (0)
// if had no match, make dot.
replace interestamt_zero = . if interestamt_zero==0
// if had no match, make dot.
replace interestamt_zero = 0 if (interestamt_zero!=1 & interestamt_zero!=2) & (dataconcern!=2)
label var interestamt_zero "Per survey, # zero interest loans"


* Interest amounts more than 50% seem crazy
generate interestamt_50_1 = 1 if (interestamt1 > (.5*amount_borrowed_loan1))
label var interestamt_50_1 "1=Interest > 50% amount"
replace interestamt_50_1 = 0 if interestamt_50_1!=1 & status=="Complete!"

generate interestamt_50_2 = 1 if (interestamt2 > (.5*amount_borrowed_loan2) )
label var interestamt_50_2 "1=Interest > 50% amount"
replace interestamt_50_2 = 0 if interestamt_50_2!=1 & status=="Complete!"


* 4.3 - Can't take a loan without applying for one (or very rare)
generate loan_without_apply = 1 if have_applied_loan==0 & taken_loan==1 & dataconcern!=1
replace loan_without_apply = 0 if loan_without_apply!=1 & dataconcern!=1
label var loan_without_apply "1=Did not apply loan, but received loan "


/* 5 - SKIPPED QUESTIONS - How many questions did enumerators skip incorrectly?
97) Ma onongo tin pud pe oromo, iromo tita yengo ni ikom lukwed lok nyo lukwan mogo ma gubedo kabino ikin gangi kany ka kwedo lok ma pat ki en jo man me CKW ni?
98) Iromo waca madwonge ngo ma oweko itamo kit man?
Ngat mo iot kany dong otiyo ki yat panadol I kine me dwee abicel ma okato ni?
*/

generate skipped_pan = 1 if pan_used_6==. & status=="Complete!"
generate skipped_healthorg = 1 if future_health_org==. & future_health_action!=. & status=="Complete!"
generate skipped_research = 1 if research_sat==. & status=="Complete!"
generate skipped_why_research = 1 if why_researcher=="." & status=="Complete!"
foreach var of varlist skipped_pan skipped_healthorg skipped_research skipped_why_research {
	replace `var' = 0 if `var'!=1 & status=="Complete!"
}
generate skipped_total = skipped_pan + skipped_healthorg + skipped_research + skipped_why_research
label var skipped_total "# incorrectly skipped questions"
drop skipped_pan  skipped_healthorg skipped_research skipped_why_research

/* 6 - QUALITATIVE FEEDBACK - How many characters did each org enter for the qualitative feedback questions? */
generate length_why_ckw = length(why_ckw) if dataconcern!=2 &  heard_ckw==1
label var length_why_ckw "Per survey, # chars in 'why_ckw'"
generate length_why_researcher = length(why_researcher) if dataconcern!=2
label var length_why_researcher "Per survey, # chars in 'why_researcher'"

/* 7 - LENGTH OF SURVEY - Do the times that were entered make sense? */

* Let's assume that anyting before 7 is PM
replace time_ends = time_ends + 1200 if time_ends <=700 | time_begins<=700
replace time_begins = time_begins + 1200 if time_begins<=700

* Now generate time variables so we can calculate the length of the survey
tostring time_ends time_begins, replace
gen timee=clock(time_ends,"hm")
format timee %tC
label var timee "Time survey ended"
gen timeb=clock(time_begins,"hm")
format timeb %tC
label var timeb "Time survey began"
gen survey_length_minutes=minutes(timee-timeb)
label var survey_length_minutes "# of minutes survey took"
sort survey_length_minutes

* Anything under 25 mintues is too short - and over 90 minutes is too long

generate survey_length_questionable = 1 if (survey_length_minutes <20 | survey_length_minutes>60) & survey_length_minutes !=.
label var survey_length_questionable "1=Survey length is odd"
replace survey_length_questionable = 0 if survey_length_questionable!=1 & (dataconcern!=1 & dataconcern!=2)
// oops
replace survey_length_questionable = . if status=="Empty_EnumInfo"


/* 8 - BUY FROM GOVT - How often did enums say they buy health products (typically) from govt? */
generate health_action_suspicious1 = 1 if today_health_action==1 & today_health_org==3
replace health_action_suspicious1 = 0 if health_action_suspicious!=1 & (dataconcern!=1 & dataconcern!=2)
label var health_action_suspicious1 "1=Illogical answer for health expectations"


/* 8 - FREE FROM FOR PROFITS - How often did enums say they typically receive product free from for profits? */
generate health_action_suspicious2 = 1 if today_health_action==2 & today_health_org==2
replace health_action_suspicious2 = 0 if health_action_suspicious2!=1 & (dataconcern!=1 & dataconcern!=2)
label var health_action_suspicious2 "1=Illogical answer for health expectations"

*Add them together
generate health_action_suspicious3 = 0 if health_action_suspicious1!=. | health_action_suspicious2!=.
label var health_action_suspicious3 "Total of health_action1 + health_action2"
replace health_action_suspicious3 = 1 if health_action_suspicious1==1 | health_action_suspicious2==1


/* 10 - WRONG RESPONDENT AGE OR GENDER - How often did entered data differ from true data? */

generate age_d2d = dateofbirth
replace age_d2d = (2011 - age_d2d)
replace age_true = "." if age_true=="0"
replace age_true = "." if age_true==""
tostring age_d2d, replace
replace age_true = age_d2d if (age_true!="." & source=="D2D")
replace age_true = "40" if age_true=="04/02/1971"
destring age_true, replace
generate age_difference = abs(age_true -  resp_age)
label var age_difference "abs(age_true - resp_age)"
drop age_d2d

/*************(6) CREATE VARIABLES TO DEFINE ACCURACY *************/

* Below are the questions used to define the overall accuracy rates. Lots of difficult decisions here! Rates would go up if we: added the group support question or took out some of the D2D questions
local truedatavars truth_acted_training truth_acted_personal_support truth_acted_group_or_pers_tools truth_acted_supp_by_acted truth_nrc_group_inputs truth_nrc_supp_by_nrc truth_bed_bio_children truth_bed_pregnant_since_2009 truth_bed_hc_visit_once truth_bed_rec_net_once  truth_bed_hc_match truth_loan_have_applied_loan truth_loan_taken_loans truth_sell_market_approach truth_sell_last_date truth_sell_product truth_sell_org truth_sell_purchase truth_sell_purchase_product truth_free_approached_free truth_free_last_date truth_free_product truth_free_org truth_free_accept truth_condom
// sum the 1s in the trudatavars
egen total_err_per_survey_num = rowtotal(`truedatavars')
label var total_err_per_survey_num "Per survey, # of correct answers"
// add up the number of nonmissing values for truedatavars
egen total_err_per_survey_denom = anycount(`truedatavars'), values(0 1)

* Before alter denomenator, keep this value which is the total questions w/ true data for each survey
generate has_truedata = total_err_per_survey_denom
replace has_truedata = 1 if has_truedata!=0 & has_truedata!=.
// This should count only the surveys we are using in error calcs
replace has_truedata = . if has_truedata!=. & dataconcern==1
label var has_truedata "Per survey, 1=has true data"

// In cases where there were no truth variables (D2DNOTFOUND), there is no denomenator
replace total_err_per_survey_denom = . if total_err_per_survey_denom==0
label var total_err_per_survey_denom "Per survey, # of asked questions"

* Here comes the rate per survey:
gen acc_per_survey = total_err_per_survey_num / total_err_per_survey_denom
label var acc_per_survey "Per survey, # correct / # asked "
replace acc_per_survey = . if dataconcern==1

* Across all true data, how do the error rates between IPA/CKWs compare?


**drop total_err_per_survey_denom total_err_per_survey_num // Don't need the vars we used for calculations

/* 2 - Just like above, but now define accuracy per survey and per datasource  */
*  I need a var that I can call in the loop below, associated with the local of questions
gen source1 = is_ACTED
gen source2 = is_BEDNET
gen source3 = is_LOAN
gen source4 = is_D2DFOUND
gen source5 = is_NRC

* Below are the questions used to define the per source accuracy rates. Lots of difficult decisions here! Rates would go up if we: added the group support question or took out some of the D2D questions
// ACTED questions
local questionset1 truth_acted_training truth_acted_personal_support truth_acted_group_or_pers_tools truth_acted_supp_by_acted
// Bednet questions
local questionset2 truth_bed_bio_children truth_bed_pregnant_since_2009 truth_bed_hc_visit_once truth_bed_rec_net_once  truth_bed_hc_match
// Loan questions
local questionset3 truth_loan_have_applied_loan truth_loan_taken_loans
// D2D Questions
local questionset4 truth_sell_market_approach truth_sell_last_date truth_sell_product truth_sell_org truth_sell_purchase truth_sell_purchase_product truth_free_approached_free truth_free_last_date truth_free_product truth_free_org truth_free_accept truth_condom
// NRC questions
local questionset5 truth_nrc_group_inputs truth_nrc_supp_by_nrc

local sourcerate "is_ACTED is_BEDNET is_LOAN is_D2DFOUND is_NRC"

forvalues i=1/5 {
	egen total_err_per_survey_num`i' = rowtotal(`questionset`i'') if source`i'==1, missing
	egen total_err_per_survey_denom`i' = anycount(`questionset`i'') if source`i'==1, values(0 1)
	replace total_err_per_survey_denom`i' = . if (total_err_per_survey_denom`i'==0 & source`i'==1)
	gen acc_per_survey_`i' = total_err_per_survey_num`i' / total_err_per_survey_denom`i'
	label var acc_per_survey_`i' "Per survey, accuracy rate (`i')"
	replace acc_per_survey_`i' = . if dataconcern==1
}

rename acc_per_survey_1 acc_per_survey_is_ACTED
rename acc_per_survey_2 acc_per_survey_is_BEDNET
rename acc_per_survey_3 acc_per_survey_is_LOAN
rename acc_per_survey_4 acc_per_survey_is_D2DFOUND
rename acc_per_survey_5 acc_per_survey_is_NRC

rename total_err_per_survey_denom1 count_ACTED
rename total_err_per_survey_denom2 count_BEDNET
rename total_err_per_survey_denom3 count_LOAN
rename total_err_per_survey_denom4 count_D2DFOUND
rename total_err_per_survey_denom5 count_NRC

label var count_ACTED "Per srvy, # ACTED questions analyzed"
label var count_BEDNET "Per srvy, # BEDNET questions analyzed"
label var count_LOAN "Per srvy, # LOAN questions analyzed"
label var count_D2D "Per srvy, # D2DFOUND questions analyzed"
label var count_NRC "Per srvy, # NRC questions analyzed"
*drop source1 source2 source3 source4 source5 total_err_per_survey_num*
sort org enumerator

move count_ACTED  acc_per_survey
move count_BEDNET  acc_per_survey
move count_LOAN  acc_per_survey
move count_D2DFOUND  acc_per_survey
move count_NRC  acc_per_survey

saveold "$master/data/all_submissions_no_identity2.dta", replace


/*************(7) CHECK RANDOMIZATION *************/
* Maggie says: We should have a randomization check table – ie proof that covariates measured at baseline do not predict assignment to CKW or IPA.
*Oops, these are dirty:
replace gender_true = "1" if gender_true == "F"
replace gender_true = "2" if gender_true == "M"
destring gender_true, replace
* The following variables only have 1s - no zeros. Lets change that:

foreach y of varlist  is_ACTED is_BEDNET is_FORESTRY is_LOAN is_NRC is_D2DFOUND {
	replace `y' = 0 if `y'!=1 & status=="Complete!"
}
* Question: Unsure how to test the geographic area

* Now we are ready to run:
foreach y of varlist  gender_true age_true is_ACTED is_BEDNET is_FORESTRY is_LOAN is_NRC is_D2DFOUND {
	qui ttest `y', by(enum_is_ipa)
	gen mu_1 = r(mu_1)
	gen mu_2 = r(mu_2)
	gen p = r(p)
	gen n_1 = r(N_1)
	gen n_2 = r(N_2)
	local mu_1 = mu_1
	local mu_2 = mu_2
	local n_1 = n_1
	local n_2 = n_2
	local p = p
	display "`y'" "," `mu_1' "," `mu_2' "," `p' "," `n_1' "," `n_2'
	drop mu_1 mu_2 p n_1 n_2
}

saveold "$master/data/all_submissions_no_identity2.dta", replace
/*************(7) COLLAPSE TO CREATE ACCURACY RATES************
Note: This is not saved to 'identity2.dta'
This section creates three files that are then merged in:
save "$master/data/enum_rates_overall.dta", replace
save "$master/data/enum_rates_per_source.dta", replace
save "$master/data/enum_rates_per_source_d2donly.dta", replace
*/

/* 1) What percentage of the true survey questions asked were correct - per enumerator overall?  */

use "$master/data/all_submissions_no_identity2.dta", clear
drop if status!="Complete!" | dataconcern==1 | dataconcern==2
* We want averages to be unique to each datasource - to now show overlap. So lets first collapse on all but D2D:
collapse (mean) acc_per_survey (sum) has_truedata count_*, by (enumerator)


rename acc_per_survey acc_per_enum
label var acc_per_enum "Per enum, accuracy rate - all sources"
rename has_truedata totalcomplete_with_truedata
label var totalcomplete_with_truedata "Per enum, # surveys w/ data"

generate count_total =   count_ACTED + count_BEDNET + count_LOAN + count_D2DFOUND + count_NRC
label var count_total "Per enum, # true questions"
local rename2 "count_ACTED count_BEDNET count_LOAN count_D2DFOUND count_NRC"
foreach x of local rename2 {
	rename `x' `x'_per_enum
	label var `x'_per_enum "Per enum,  `x'"
}

outsheet  using "$master/output/error_rates_overall.csv", comma replace
rename enumerator enumerator_full
clonevar enum_err = enumerator_full
saveold "$master/data/enum_rates_overall.dta", replace


/* 2) What percentage of the true survey questions asked were correct - per enumerator and datasource?  */

use "$master/data/all_submissions_no_identity2.dta", clear
drop if status!="Complete!" | dataconcern==1 | dataconcern==2
* We want averages to be unique to each datasource - to now show overlap. So lets first collapse on all but D2D:
collapse (mean) acc_per_survey_is_ACTED acc_per_survey_is_BEDNET acc_per_survey_is_LOAN acc_per_survey_is_D2DFOUND acc_per_survey_is_NRC, by (enumerator)
local rename "is_ACTED is_BEDNET is_LOAN is_D2DFOUND is_NRC"
foreach x of local rename {
	rename acc_per_survey_`x' acc_per_enum_`x'
	label var acc_per_enum_`x' "Per enum, `x' accuracy rate"
}
outsheet  using "$master/output/error_rates_per_source.csv", comma replace
rename enumerator enumerator_full
saveold "$master/data/enum_rates_per_source.dta", replace

/*************(8) MERGE ACCURACY RATES BACK IN *************/

clear
use "$master/data/all_submissions_no_identity2.dta"

gen enumerator_full_low = lower(enumerator_full)
sort enumerator_full


merge m:1 enumerator_full using "$master/data/enum_rates_overall.dta"
tab _merge

drop _merge
sort enumerator_full
*save "$master/data/all_submissions_no_identity2.dta", replace
merge m:1 enumerator_full using "$master/data/enum_rates_per_source.dta"
tab _merge
drop _merge
saveold "$master/data/all_submissions_no_identity2.dta", replace

/*
use Tier,clear
rename enumerator enumerator_full
sort enumerator_full
save, replace
*/

replace enumerator_full = proper(enumerator_full)
sort enumerator_full
// looks good
merge enumerator_full using "../Dropbox/CKW/Data/Tier.dta", _merge(mergetier)

encode tier, gen(tier_num)
drop tier
rename tier_num tier

**Rename those too long trackCKW variables
foreach v of varlist  datewhat_is_todays_date timewhat_is_the_time respidwhat_is_the_respondent_id_ subcountyrespondents_subcounty  reasonnotavailablewhat_is_the_re otherreasonnoavailwhat_is_the_ot whenpassawaywhen_did_this_respon villagemovedwhat_is_the_name_of_ appointmentmadewere_you_able_to_ other_reasonenter_your_other_res datereturnwhen_are_you_planning_ numbertalkedhow_many_people_have whotalkedwho_did_you_speak_to_ab namesofinformantswhat_are_the_na athhare_you_currently_at_the_res currentlocationwhat_is_your_curr otherlocationwhat_is_the_quote_o gpsplease_enter_the_gps_coordina{
	local label : var label `v'

	local newlabel = regexm("`label'", "\((.*)\)")
	local newlabel2 = regexs(1)
	di "`newlabel'" "`newlabel2'"
	rename `v' `newlabel2'_trackckw
}


label var uniqueid "Unique ID across data sets"
label var attempt_ipa "Number of Tracking Attempt by IPA enumerator"

/*
foreach var in gps gpseast gpsnorth {
di "`var'"
bys enumerator_full_low (org2 `var'): replace `var' = `var'[_n - 1] if `var'[_n - 1] != `var'[_n] & !mi(`var'[_n - 1]) & org2 == 1
//for IPA incomplete surveys, we don't know which one is assigned to who
count if mi(`var') & org2 == 1
local l`var' : variable label `var'
}
*/

gsort enumerator_full -gpseast
bys enumerator_full: replace gpseast = gpseast[_n - 1] if !mi(gpseast[_n - 1]) & mi(gpseast)
//there are some obs that have two periods within a value. take out the second one.
// regular expression in Stata tends to have bugs if you do it all once for all obs
forval i = 1/`= _N'{
	replace gpseast = subinstr(gpseast, regexs(0), regexs(1), .) if regexm(gpseast, "^([^.]*\.[^.]*)\.") in `i'
}

// this must be coming from reclink
drop if status == ""
// IPA enumerator GPS coordiantes is Gulu town
replace gpseast = "32.2848" if ckw == 0
ren gpseast long_enum
la var long_enum "Longitude of Enumerator GPS Point"
// IPA enumerator GPS coordiantes is Gulu town
replace gpsnorth = "2.7793" if ckw == 0
gsort enumerator_full_low -gpsnorth
bys enumerator_full_low: replace gpsnorth = gpsnorth[_n - 1] if !mi(gpsnorth[_n - 1]) & mi(gpsnorth)
// regular expression in Stata tends to have bugs if you do it all once for all obs
forval i = 1/`= _N'{
	replace gpsnorth = subinstr(gpsnorth, regexs(0), regexs(1), .) if regexm(gpsnorth, "^([^.]*\.[^.]*)\.") in `i'
}
ren gpsnorth lat_enum
la var lat_enum "Latitude of Enumerator GPS Point"

split gps, g(gps_resp)
ren gps_resp1 lat_resp
la var lat_resp "Latitude of Respondent GPS Point"
ren gps_resp2 long_resp
la var long_resp "Longitude of Respondent GPS Point"

foreach var in lat_enum long_enum lat_resp long_resp{
	destring `var', replace ignore(" ")
}

geodist lat_enum long_enum lat_resp long_resp, g(distance)
la var distance "Distance between Enumerator and Respondent"

ren age age_enum
ren gender gender_enum
ren resp_age age_resp
ren male gender_resp


* Below are the questions used to define the per source accuracy rates. Lots of difficult decisions here! Rates would go up if we: added the group support question or took out some of the D2D questions
// ACTED questions
local questionset1 truth_acted_training truth_acted_personal_support truth_acted_group_or_pers_tools truth_acted_supp_by_acted
// Bednet questions
local questionset2 truth_bed_bio_children truth_bed_pregnant_since_2009 truth_bed_hc_visit_once truth_bed_rec_net_once  truth_bed_hc_match
// Loan questions
local questionset3 truth_loan_have_applied_loan truth_loan_taken_loans
// D2D Questions
local questionset4 truth_sell_market_approach truth_sell_last_date truth_sell_product truth_sell_org truth_sell_purchase truth_sell_purchase_product truth_free_approached_free truth_free_last_date truth_free_product truth_free_org truth_free_accept truth_condom
// NRC questions
local questionset5 truth_nrc_group_inputs truth_nrc_supp_by_nrc


drop count_*
rename total_err_per_survey_num1 count_ACTED
rename total_err_per_survey_num2 count_BEDNET
rename total_err_per_survey_num3 count_LOAN
rename total_err_per_survey_num4 count_D2DFOUND
rename total_err_per_survey_num5 count_NRC

egen totalerror=rowtotal(count_ACTED - count_NRC),m

// there is one observation that was entirely blank except some auditing variables. dropped for now, since cannot find any justification to keep it
drop if mi(source) & mi(status)

levelsof source, loc(sources)
foreach v of local sources{
	gen `v' = (source == "`v'")
}


gen foundsurvey = 0
la var foundsurvey "1=This Resp Is Found and Surveyed"
replace foundsurvey = 1 if status =="Complete!" | status == "Drop_IntervByBothOrgs" | status == "Drop_WrongRespondent"

bys enumerator_full: egen totalcomplete = total(foundsurvey)
la var totalcomplete "Total # of Found-Resp Survey by Enum"

/*preserve
u "$enum_info/data/enum_info.dta", clear
stop
replace enumerator = "Acayo Irene Odoki (IPA)" if enumerator == "Acayo Irene Odoki (IP"
replace enumerator = subinstr(enumerator, "(", "", .)
replace enumerator = subinstr(enumerator, ")", "", .)
replace enumerator = lower(enumerator)
ren enumerator enumerator_full
sort enumerator_full
tempfile enum
save "`enum'"
restore
merge m:1 enumerator_full using "`enum'", gen(merge_enuminfoFill) update
*/

ren tribe tribe_str
encode tribe_str, gen(tribe)
la def tribec 1"Acholi" 2"Alur" 3"Lango" 4"Lwo", modify
la val tribe tribec
drop tribe_str

#d;
loc enumchar gender_enum age_enum tribe educationlevel married children livespouse offices runfuture
perf_treatment perf_did_not_come_to_groups 
;
#d cr

drop male_enum
foreach var of local enumchar {
	di "`var'"
	gsort +`var'
	bys enumerator_full: egen max`var' = max(`var')
	bys enumerator_full: egen min`var' = min(`var')
	cap assert max`var' == min`var'
	if _rc{
		di "`var'"
		stop
	}
	gsort enumerator_full +`var'
	bys enumerator_full: replace `var' = `var'[_n - 1] if `var'[_n - 1] != `var'[_n] & !mi(`var'[_n - 1])  & mi(`var'[_n])
	//for IPA incomplete surveys, we don't know which one is assigned to who
	count if mi(`var')
}

// these are empty enumerator info rows, which should not be in analysis.
drop if mi(ckw)
gen samegender = (gender_resp == gender_enum) if !mi(gender_resp) & !mi(gender_enum)
gen samevillage= (from_geo==3) if !mi(from_geo)
ren gender_resp male
saveold "../Dropbox/CKW/Analysis/data/FinalData.dta", replace

include "`root'/Analysis/dofiles/cleaning/completenessCleaning.do"
use "../Dropbox/CKW/Analysis/data/FinalData.dta", clear
merge 1:1 uniqueid using "../Dropbox/CKW/Analysis/data/Completeness.dta", gen(mergeCompleteness)
ren male gender_resp
saveold "../Dropbox/CKW/Analysis/data/EnumeratorNameAttrition.dta", replace
// we can't use these for our anlaysis at all.
drop if enumerator_full == "." //  these surveys have mostly missing values in the outcome variables 
								//because almost all the outcome variables are dependent on who an enumerator is

encode source, gen(sourcenum)

******Variables for anlaysis**********

**Indicator variable for observations who report values in observed assets
gen observed = !mi(bednets_seen) if !mi(bednets_seen)
la var observed "Dummy for Observed Asset Data Source"


***generate some outcome variables
**proportion of completed survey #
gen firsttwo = substr(status, 1, 2)
gen complete = (firsttwo != "IC")
gen assign = 1
bys enumerator_full: egen complete_enum = total(complete)
bys enumerator_full: egen assign_enum = total(assign)
bys enumerator_full: gen propComplete = complete_enum / assign_enum
la var propComplete "Proportion of Complete Surveys"

**generate a variable that indicates whether enumerators are from the same county.
gen subcounty_num = .
forval i = 1/13{
	loc vlab: label subcountyL `i'
	loc county = substr("`vlab'", strpos("`vlab'", ")") + 1, .)
	replace subcounty_num = `i' if subcountyofresidence == "`county'"
}
gen samecounty = (subcounty_num == subcounty_submitted)
la var samecounty "Enum from Same Subcounty with Respondents" 
/*
gen bednets_disc = abs(bednets - bednets_seen)
gen beddings_disc = abs(beddings - beddings_seen)
gen stoves_disc = abs(stoves - stoves_seen)
gen bikes_disc = abs(bikes - bikes_seen)
gen goats_disc = abs(goats - goats_seen)

gen bednets_disc_nom = bednets - bednets_seen
gen beddings_disc_nom = beddings - beddings_seen
gen stoves_disc_nom = stoves - stoves_seen
gen bikes_disc_nom = bikes - bikes_seen
gen goats_disc_nom = goats - goats_seen
*/

****Generate the binary variables for recorded answers and recorded answer == 1**********
loc loan "loan"
foreach v of local loan {
	if "`v'" == "loan"{ 
		qui gen `v'_b_c = (`v'_disc == 0) if !mi(loan_disc)
		la var `v'_disc "Abolute Value of Discrepancy_`v'"
		la var `v'_disc_nom "Discrepancy_`v'"
		gen `v'_b = !mi(`v'_b_c) if is_LOAN == 1
		gen `v'_mm = mi(`v'_b_c)		
	}
	else {	
		qui gen `v'_b_c = (`v'_disc == 0) if !mi(`v'_disc)
		gen `v'_b = !mi(`v'_b_c)
		gen `v'_mm = mi(`v'_b_c)
		la var `v'_disc "Abolute Value of Discrepancy_Observed_`v'"
		la var `v'_disc_nom "Discrepancy_Observed_`v'"
	}
}	

/*************(6) CREATE VARIABLES TO DEFINE ACCURACY *************/
ren truth_acted_group_or_pers_tools  truth_acted_group_or_pers_to
/* 1 - Define accuracy per survey  */
**missings as 0
local questionset1 truth_acted_training truth_acted_personal_support truth_acted_group_or_pers_to truth_acted_supp_by_acted
// Bednet questions
local questionset2 truth_bed_bio_children truth_bed_pregnant_since_2009 truth_bed_hc_visit_once truth_bed_rec_net_once  truth_bed_hc_match
// Loan questions
local questionset3 truth_loan_have_applied_loan truth_loan_taken_loans
// D2D Questions
local questionset4 truth_sell_market_approach truth_sell_last_date truth_sell_product truth_sell_org truth_sell_purchase truth_sell_purchase_product truth_free_approached_free truth_free_last_date truth_free_product truth_free_org truth_free_accept truth_condom
// NRC questions
local questionset5 truth_nrc_group_inputs truth_nrc_supp_by_nrc

********Generate 
forvalues i=1/5 {
	foreach v of local questionset`i' {
		gen `v'_mm = mi(`v') & source`i' == 1
		clonevar `v'_c = `v'
		replace `v' = 0 if mi(`v') & source`i' == 1
	}
}

egen noncomp_outcome = rowtotal(*_mm)
unab mm: *_mm
gen completeness_outcome = noncomp_outcome /`:list sizeof mm'

la var completeness "Completeness Rate within Survey"

**Error severity score from Audit survey
gen auditerror_score = audit_sev1*1 + audit_sev2*2 + audit_sev3*3 + audit_sev4*4
la var auditerror_score "(Audit) Error Severity Scores"

gen incomplete = mi(samegender) // including all those 3 dummies just created would result in multicollinearity 
	//since the missings are just incopmlete surveys
la var incomplete "Indicator variable for incomplete surveys"


********************************************************************************
**************************************SEED**************************************
********************************************************************************

replace seed_type1 = "Mangoes" if seed_type1 == "Mongoes"
replace seed_type1 = "Jackfruit" if seed_type1 == "Jack Fruit"
replace seed_type1 = "Orange" if seed_type1 == "Oranges"

destring seed_amt1, replace

replace seed_type2 = "Mangoes" if seed_type2 == "Mongoes"
replace seed_type2 = "Jackfruit" if seed_type2 == "Jack Fruit"
replace seed_type2 = "Orange" if seed_type2 == "Oranges"

destring seed_amt2, replace

replace seed_type3 = "Mangoes" if seed_type3 == "Mongoes"
replace seed_type3 = "Jackfruit" if seed_type3 == "Jack Fruit"
replace seed_type3 = "Orange" if seed_type3 == "Oranges"

destring seed_amt3, replace

replace seed_type4 = "Mangoes" if seed_type4 == "Mongoes"
replace seed_type4 = "Jackfruit" if seed_type4 == "Jack Fruit"
replace seed_type4 = "Orange" if seed_type4 == "Oranges"

destring seed_amt4, replace
loc sd
loc sl
forval i = 1/4{
	levelsof seed_type`i', loc(s`i')
	if `i' == 1{
		loc sl `s1'
	}
	if `i' >1{
		loc sd: list s`i' - s1 
		loc sl "`"`sl'"' `"`sd'"'"
	}
}
di "`sl'"
di "`:list sizeof sl'"

gen seed1 = .
gen seed2 = .
gen seed3 = .
gen seed4 = .
levelsof seed_type1, loc(g)
forval i = 1/13{
	loc seed: word `i' of `g'
	la def seco `i' "`seed'", add
	replace seed1 = `i' if seed_type1 == "`seed'"
	la val seed1 seco
	replace seed2 = `i' if seed_type2 == "`seed'"
	la val seed2 seco
	replace seed3 = `i' if seed_type3 == "`seed'"
	la val seed3 seco
	replace seed4 = `i' if seed_type4 == "`seed'"
	la val seed1 seco
	if `i' == 13{
		la def seco 14 "Mvule", add
		replace seed3 = 14 if seed_type3 == "Mvule"
	}
}

egen seedmiss = rowtotal(seed1 seed2 seed3 seed4), m 
levelsof seed_type1, loc(g)
forval i = 1/13{
	loc seed: word `i' of `g'	
	egen senm_`seed' = anymatch(seed1 seed2 seed3 seed4), v(`i')
	replace senm_`seed' = . if mi(seedmiss)
	la var senm_`seed' "`seed' seed was given"
	egen seamt_`seed' = rowtotal(seed_amt1 seed_amt2 seed_amt3 seed_amt4) if senm_`seed' == 1, m
	la var seamt_`seed' "Amount of `seed' seed given"
	if 	`i' ==13{
		egen senm_Mvule = anymatch(seed1 seed2 seed3 seed4), v(14)
		replace senm_Mvule = . if mi(seedmiss)
		la var senm_Mvule "Mvule seed was given"
		egen seamt_Mvule = rowtotal(seed_amt1 seed_amt2 seed_amt3 seed_amt4) if senm_Mvule == 1, m
		la var seamt_Mvule "Amount of Mvule seed given"
	}
}		

********************************************************************************
**************************************LOAN**************************************
********************************************************************************
egen loanamt = rowtotal(loan1_amount loan2_amount),m
la var loanamt "Total Loan Amount"

**Take Z-score of date variable
sum bednet_date_recieved, det
loc mean `r(mean)'
loc sd `r(sd)'
gen double zscBednetDate = (bednet_date_recieved - `mean')/`sd'
la var zscBednetDate "Z Score of Bednet Received Date"

sum loan1_date, det
loc mean `r(mean)'
loc sd `r(sd)'
gen double zscLoanDate = (loan1_date - `mean')/`sd' //only loan1_date can take care of everythin. loan2_date has only 3 obs that are overlapped with loan1_date obs
la var zscLoanDate "Z Score of Loan Given Date"



#d;
loc seeds
	senm_Avocado
	senm_Citrus
	senm_Eucalyptus
	senm_Grevelia
	senm_Jackfruit
	senm_Lucaena
	senm_Maesopsis
	senm_Mahogany
	senm_Mangoes
	senm_Musisi
	senm_Orange
	senm_Pines
	senm_Teak
	senm_Mvule
;
#d cr

egen seedskindnum = rowtotal(`seeds'), m
la var seedskindnum "Number of Seeds Kind Received"



saveold "../Dropbox/CKW/Analysis/data/FinalData_ForD2D.dta", replace
**Reshape data set
include "`do'/reshape_questionlevel.do"

**Heterogeneous analysis variables--> data category
gen data_local = (1 <= _j & _j <= 8)
gen data_neutral = (9 <= _j & _j <= 22)
gen data_sense = (23 <= _j & _j <= 26)

la var data_local "Local Knowledge Data Category"
la var data_neutral "Neutral Data Category"
la var data_sense "Sensitive Data Category"

**Heterogeneous analysis variables--> data source and condom question
gen ckw_ACTED = ckw*ACTED 
gen ckw_BEDNET = ckw*BEDNET 
gen ckw_FORESTRY = ckw*FORESTRY 
gen ckw_LOAN = ckw*LOAN 
gen ckw_NRC = ckw*NRC
replace condom_received = . if condom_received == 99 //Pia's suggestion: assign missing values to don't know resp
gen condom_received_miss = mi(condom_received)
la var condom_received_miss "Dummy for Missingness of Condom Reception"
replace condom_received = 0 if mi(condom_received)
gen ckw_condom = ckw*condom_received
gen ckw_observed = ckw*observed

gen ckw_local = ckw*data_local 
la var ckw_local "CKW*Local Knowledge Data Category"
gen ckw_sense = ckw*data_sense
la var ckw_sense "CKW*Sensitive Data Category"

gen knowresp = (how_well_know > 1 & !mi(how_well_know))
gen know_ACTED = knowresp*ACTED 
gen know_BEDNET = knowresp*BEDNET 
gen know_FORESTRY = knowresp*FORESTRY 
gen know_LOAN = knowresp*LOAN 
gen know_NRC = knowresp*NRC
gen know_condom = knowresp*condom_received

gen know_local = knowresp*data_local 
gen know_neutral = knowresp*data_neutral
gen know_sense = knowresp*data_sense

gen samevillage_ACTED = samevillage*ACTED 
gen samevillage_BEDNET = samevillage*BEDNET 
gen samevillage_FORESTRY = samevillage*FORESTRY 
gen samevillage_LOAN = samevillage*LOAN 
gen samevillage_NRC = samevillage*NRC
gen samevillage_condom = samevillage*condom_received

gen samevillage_local = samevillage*data_local 
gen samevillage_neutral = samevillage*data_neutral
gen samevillage_sense = samevillage*data_sense

**Gender lying hetero
gen female_resp = (gender_resp == 0) //the variable incopmlete will take care of missing values
gen female_enum = (gender_enum == 0)
gen female_respenum = female_resp*female_enum

replace gender_true = 0 if gender_true == 2
la def gencode 0 "Female" 1 "Male", modify
la val gender_true gencode

saveold "../Dropbox/CKW/Analysis/data/FinalData.dta", replace

