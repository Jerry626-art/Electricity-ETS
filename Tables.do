
//----------------------------------------------------------------------------//
// Preface
//----------------------------------------------------------------------------//


if c(username) == "yourname" {
	global path "/Users/yourname/file"
	cd "/Users/yourname/file"
}


else {
	global path ""
	cd ""
}


//-----------------------------------//
// Summary Statistics and Balance Table
//-----------------------------------//
use "$clean/LSEG_reg_elec.dta",clear

drop if fiscalyear==2021
* Winsorise variables
local variables L1log_at_usd L1log_capx_usd L1sales_growth L1ROA L1fixed_asset_ratio L1leverages log_at_usd ROA leverages sales_growth fixed_asset_ratio Log_GHG_Scope1_Intensity Log_GHG_Scope1 log_sale_usd Log_GHG_Scope1_Intensity_growth Log_GHG_Scope1_growth
foreach var of local variables {
	winsor2 `var', replace cuts(1 99)
}

* Summary Statistics
eststo clear 
estpost summarize Log_GHG_Scope1_Intensity Log_GHG_Scope1 Log_GHG_Scope1_Intensity_growth Log_GHG_Scope1_growth log_at_usd ROA leverages sales_growth fixed_asset_ratio,detail 
	
esttab using "$out/sumstat.tex", ///
    replace ///
    cells("mean(fmt(3)) sd(fmt(3)) p10(fmt(3)) p90(fmt(3)) count(fmt(0))") ///
    label ///
    booktabs ///
    nonumber ///
    noobs ///
    title("Summary Statistics")


* Balance Table
preserve
keep if fiscalyear<=2017
iebaltab Log_GHG_Scope1_Intensity Log_GHG_Scope1 log_at_usd ROA leverages sales_growth fixed_asset_ratio, ///
    grpvar(treat) ///
	stats(pair(t) f(p)) ///
	rowvarlabels ///
	nonote ///  
	grouplabels("0 Control @ 1 Treat") ///
	texcaption("Balance Table") ///
	texdocument ///
    savetex("$out/balance_table.tex") ///
    replace
restore


//-----------------------------------//
// Baseline regressions
//-----------------------------------//
use "$clean/LSEG_reg_elec.dta",clear

drop if fiscalyear==2021


* Winsorise variables
local variables L1log_at_usd L1log_capx_usd L1sales_growth L1ROA L1fixed_asset_ratio L1leverages log_at_usd ROA leverages sales_growth fixed_asset_ratio Log_GHG_Scope1_Intensity Log_GHG_Scope1 log_sale_usd Log_GHG_Scope1_Intensity_growth Log_GHG_Scope1_growth
foreach var of local variables {
	winsor2 `var', replace cuts(1 99)
}


eststo clear
reghdfe Log_GHG_Scope1_Intensity did L1log_at_usd L1ROA L1leverages L1fixed_asset_ratio, absorb(gvkey fiscalyear) vce(cluster gvkey)
eststo m1
estadd local Sample "Baseline"	

xtreg Log_GHG_Scope1_Intensity did L1log_at_usd L1ROA L1leverages L1fixed_asset_ratio i.fiscalyear, fe cluster(gvkey)
boottest did, cluster(gvkey) reps(9999)
matrix p1 = r(p)
estadd scalar boot_p = p1[1,1] : m1


reghdfe Log_GHG_Scope1_Intensity placebo_did L1log_at_usd L1ROA L1leverages L1fixed_asset_ratio, absorb(gvkey fiscalyear) vce(cluster gvkey)
eststo m2
estadd local Sample "Placebo Test"	

xtreg Log_GHG_Scope1_Intensity placebo_did L1log_at_usd L1ROA L1leverages L1fixed_asset_ratio i.fiscalyear, fe cluster(gvkey)
boottest placebo_did, cluster(gvkey) reps(9999)
matrix p2 = r(p)
estadd scalar boot_p = p2[1,1] : m2



preserve
keep if fiscalyear==2017
ebalance treat Log_GHG_Scope1_Intensity,targets(2)
keep gvkey _webal
save "$temp/balance_weight2017_d.dta",replace
restore

* Merge weights
merge m:1 gvkey using "$temp/balance_weight2017_d.dta"

* Entropy balancing
reghdfe Log_GHG_Scope1_Intensity did L1log_at_usd L1ROA L1leverages L1fixed_asset_ratio[aweight=_webal], absorb(gvkey fiscalyear) vce(cluster gvkey)
eststo m4
estadd local Sample "Entropy Balancing"

xtreg Log_GHG_Scope1_Intensity did L1log_at_usd L1ROA L1leverages L1fixed_asset_ratio i.fiscalyear [aweight=_webal], fe cluster(gvkey)
boottest did, cluster(gvkey) reps(9999)
matrix p4 = r(p)
estadd scalar boot_p = p4[1,1] : m4



use "$clean/LSEG_reg_elec.dta",clear

* Robustness check: full sample
* Winsorise variables
local variables L1log_at_usd L1log_capx_usd L1sales_growth L1ROA L1fixed_asset_ratio L1leverages log_at_usd ROA leverages sales_growth fixed_asset_ratio Log_GHG_Scope1_Intensity Log_GHG_Scope1 log_sale_usd Log_GHG_Scope1_Intensity_growth Log_GHG_Scope1_growth
foreach var of local variables {
	winsor2 `var', replace cuts(1 99)
}

reghdfe Log_GHG_Scope1_Intensity did L1log_at_usd L1ROA L1leverages L1fixed_asset_ratio, absorb(gvkey fiscalyear) vce(cluster gvkey)
eststo m3
estadd local Sample "With 2021"

xtreg Log_GHG_Scope1_Intensity did L1log_at_usd L1ROA L1leverages L1fixed_asset_ratio i.fiscalyear, fe cluster(gvkey)
boottest did, cluster(gvkey) reps(9999)
matrix p3 = r(p)
estadd scalar boot_p = p3[1,1] : m3



* Robustness check: Only LSEG data
* Winsorise variables
use "$clean/LSEG_reg_elec.dta",clear
keep if emission_source=="LSEG"
drop n_fy
bysort gvkey: egen n_fy = nvals(fiscalyear)
keep if n_fy == 7
drop if fiscalyear==2021


local variables L1log_at_usd L1log_capx_usd L1sales_growth L1ROA L1fixed_asset_ratio L1leverages log_at_usd ROA leverages sales_growth fixed_asset_ratio Log_GHG_Scope1_Intensity Log_GHG_Scope1 log_sale_usd Log_GHG_Scope1_Intensity_growth Log_GHG_Scope1_growth
foreach var of local variables {
	winsor2 `var', replace cuts(1 99)
}

reghdfe Log_GHG_Scope1_Intensity did L1log_at_usd L1ROA L1leverages L1fixed_asset_ratio, absorb(gvkey fiscalyear) vce(cluster gvkey)
eststo m5
estadd local Sample "Only LSEG"

xtreg Log_GHG_Scope1_Intensity did L1log_at_usd L1ROA L1leverages L1fixed_asset_ratio i.fiscalyear, fe cluster(gvkey)
boottest did, cluster(gvkey) reps(9999)
matrix p5 = r(p)
estadd scalar boot_p = p5[1,1] : m5


esttab m1 m2 m3 m4 m5 using "$out/main_table.tex", ///
    replace ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
	mlabels("(1)" "(2)" "(3)" "(4)" "(5)") ///
    collabels(none) /// 
    stats(Sample r2_a N boot_p, ///
          labels("Sample" "Adj. R²" "Observations" "Wild Bootstrap p-value") ///
          layout("\multicolumn{1}{c}{@}" "\multicolumn{1}{c}{@}" "\multicolumn{1}{c}{@}" "\multicolumn{1}{c}{@}") ///
          fmt(. 3 0 3)) ///
	coefl(did "ETS$_{\text{i,t}}$" placebo_did "ETS$_{\text{i,t-1}}$" L1log_at_usd "Log Asset$_{\text{i,t-1}}$" L1ROA "ROA$_{\text{i,t-1}}$" L1leverages "Leverage$_{\text{i,t-1}}$" L1fixed_asset_ratio "Fixed Asset Ratio$_{\text{i,t-1}}$") ///
	order(did placebo_did L1log_at_usd L1ROA L1leverages L1fixed_asset_ratio) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    booktabs ///
    nomtitles ///
    nonumber ///
	nocon ///
    title("Main Results: Dependent variable = $\log(\text{Intensity}{i,t})$ and Robustness Checks") ///
	prefoot("\midrule \addlinespace[0.5ex] \multicolumn{6}{c}{Firm FE: YES \quad Year FE: YES} \\")
	
		 


//-----------------------------------//
// Alternative control
//-----------------------------------//
* The same SIC 2 digit level
use "$clean/LSEG_reg_all.dta",clear

keep if sic2==49
* Winsorise variables
local variables L1log_at_usd L1log_capx_usd L1sales_growth L1ROA L1fixed_asset_ratio L1leverages log_at_usd ROA leverages sales_growth fixed_asset_ratio Log_GHG_Scope1_Intensity Log_GHG_Scope1 log_sale_usd Log_GHG_Scope1_Intensity_growth Log_GHG_Scope1_growth
foreach var of local variables {
	winsor2 `var', replace cuts(1 99)
}


reghdfe Log_GHG_Scope1_Intensity did L1log_at_usd L1ROA L1leverages L1fixed_asset_ratio, absorb(gvkey fiscalyear) vce(cluster gvkey)
eststo m6
estadd local Sample "SIC2: 49"

preserve
keep if fiscalyear==2017
ebalance treat Log_GHG_Scope1 Log_GHG_Scope1_Intensity,targets(1)
keep gvkey _webal
save "$temp/balance_weight2017_e.dta",replace
restore

* Merge weights
merge m:1 gvkey using "$temp/balance_weight2017_e.dta"
* Entropy balancing
reghdfe Log_GHG_Scope1_Intensity did L1log_at_usd L1ROA L1leverages L1fixed_asset_ratio[aweight=_webal], absorb(gvkey fiscalyear) vce(cluster gvkey)
eststo m7
estadd local Entropy_Balancing "YES"	
estadd local Sample "SIC2: 49"


* The same SIC 1 digit level
use "$clean/LSEG_reg_all.dta",clear

keep if sic1==4
* Winsorise variables
local variables L1log_at_usd L1log_capx_usd L1sales_growth L1ROA L1fixed_asset_ratio L1leverages log_at_usd ROA leverages sales_growth fixed_asset_ratio Log_GHG_Scope1_Intensity Log_GHG_Scope1 log_sale_usd Log_GHG_Scope1_Intensity_growth Log_GHG_Scope1_growth
foreach var of local variables {
	winsor2 `var', replace cuts(1 99)
}


reghdfe Log_GHG_Scope1_Intensity did L1log_at_usd L1ROA L1leverages L1fixed_asset_ratio, absorb(gvkey fiscalyear) vce(cluster gvkey)
eststo m8
estadd local Sample "SIC1: 4"

preserve
keep if fiscalyear==2017
ebalance treat Log_GHG_Scope1 Log_GHG_Scope1_Intensity,targets(1)
keep gvkey _webal
save "$temp/balance_weight2017_e.dta",replace
restore

* Merge weights
merge m:1 gvkey using "$temp/balance_weight2017_e.dta"
* Entropy balancing
reghdfe Log_GHG_Scope1_Intensity did L1log_at_usd L1ROA L1leverages L1fixed_asset_ratio[aweight=_webal], absorb(gvkey fiscalyear) vce(cluster gvkey)
eststo m9
estadd local Entropy_Balancing "YES"
estadd local Sample "SIC1: 4"	

* All controls
use "$clean/LSEG_reg_all.dta",clear

* Winsorise variables
local variables L1log_at_usd L1log_capx_usd L1sales_growth L1ROA L1fixed_asset_ratio L1leverages log_at_usd ROA leverages sales_growth fixed_asset_ratio Log_GHG_Scope1_Intensity Log_GHG_Scope1 log_sale_usd Log_GHG_Scope1_Intensity_growth Log_GHG_Scope1_growth
foreach var of local variables {
	winsor2 `var', replace cuts(1 99)
}

reghdfe Log_GHG_Scope1_Intensity did L1log_at_usd L1ROA L1leverages L1fixed_asset_ratio, absorb(gvkey fiscalyear) vce(cluster gvkey)
eststo m10
estadd local Sample "Full"	

preserve
keep if fiscalyear==2017
ebalance treat Log_GHG_Scope1 Log_GHG_Scope1_Intensity,targets(1)
keep gvkey _webal
save "$temp/balance_weight2017_e.dta",replace
restore

* Merge weights
merge m:1 gvkey using "$temp/balance_weight2017_e.dta"
* Entropy balancing
reghdfe Log_GHG_Scope1_Intensity did L1log_at_usd L1ROA L1leverages L1fixed_asset_ratio[aweight=_webal], absorb(gvkey fiscalyear) vce(cluster gvkey)
eststo m11

estadd local Entropy_Balancing "YES"	
estadd local Sample "Full"	


esttab m6 m7 m8 m9 m10 m11 using "$out/other_control.tex", ///
    replace ///
    cells(b(star fmt(4)) se(par fmt(4))) ///
	mlabels("(1)" "(2)" "(3)" "(4)" "(5)" "(6)") ///
    collabels(none) /// 
    stats(Sample Entropy_Balancing r2_a N, ///
          labels("Sample" "Entropy Balancing" "Adj. R²" "Observations") ///
          layout("\multicolumn{1}{c}{@}" "\multicolumn{1}{c}{@}" "\multicolumn{1}{c}{@}" "\multicolumn{1}{c}{@}") ///
          fmt(. . 3 0)) ///
	coefl(did "ETS$_{\text{i,t}}$" L1log_at_usd "Log Asset$_{\text{i,t-1}}$" L1ROA "ROA$_{\text{i,t-1}}$" L1leverages "Leverage$_{\text{i,t-1}}$" L1fixed_asset_ratio "Fixed Asset Ratio$_{\text{i,t-1}}$") ///
	order(did L1log_at_usd L1ROA L1leverages L1fixed_asset_ratio) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    booktabs ///
    nomtitles ///
    nonumber ///
	nocon ///
    title("Alternative control groups. Dependent variable = $\log(\text{Intensity}{i,t})$") ///
	prefoot("\midrule \addlinespace[0.5ex] \multicolumn{6}{c}{Firm FE: YES \quad Year FE: YES} \\") 

		 
		 
* Export sample firm list
use "$clean/LSEG_reg_elec.dta",clear
tab emission_source
keep isin conm loc
duplicates drop
sort loc conm 
export excel using "$inter/sample_firm.xlsx",firstrow(variables) replace

* Firm-year data manually collected
use "$clean/LSEG_reg_elec.dta",clear
keep if emission_source!="LSEG"
keep conm fiscalyear emission_source keywords GHGscope1





