
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





use "$clean/LSEG_reg_elec.dta",clear

* Winsorise variables
local variables L1log_at_usd L1log_capx_usd L1sales_growth L1ROA L1fixed_asset_ratio L1leverages log_at_usd ROA leverages sales_growth fixed_asset_ratio Log_GHG_Scope1_Intensity Log_GHG_Scope1 log_sale_usd Log_GHG_Scope1_Intensity_growth
foreach var of local variables {
	winsor2 `var', replace cuts(1 99)
}

collapse (mean) Log_GHG_Scope1_Intensity Log_GHG_Scope1 log_sale_usd leverages, by(treat fiscalyear)
export delimited "$clean/mean_graphs.csv",replace

//-----------------------------------//
// Mean Graphs
//-----------------------------------//

twoway ///
(line Log_GHG_Scope1_Intensity fiscalyear if treat==1, lpattern(solid)) ///
(line Log_GHG_Scope1_Intensity fiscalyear if treat==0, lpattern(dash)), ///
legend(label(1 "Treat") label(2 "Control") pos(6) ring(-2)) ///
title(`"`value'"') ytitle("Scope 1 Intensity")

twoway ///
(line Log_GHG_Scope1 fiscalyear if treat==1, lpattern(solid)) ///
(line Log_GHG_Scope1 fiscalyear if treat==0, lpattern(dash)), ///
legend(label(1 "Treat") label(2 "Control") pos(6) ring(-2)) ///
title(`"`value'"') ytitle("Scope 1 Emissions")

twoway ///
(line log_sale_usd fiscalyear if treat==1, lpattern(solid)) ///
(line log_sale_usd fiscalyear if treat==0, lpattern(dash)), ///
legend(label(1 "Treat") label(2 "Control") pos(6) ring(-2)) ///
title(`"`value'"') ytitle("Log Sales")

twoway ///
(line leverages fiscalyear if treat==1, lpattern(solid)) ///
(line leverages fiscalyear if treat==0, lpattern(dash)), ///
legend(label(1 "Treat") label(2 "Control") pos(6) ring(-2)) ///
title(`"`value'"') ytitle("Scope 1 Emissions")

//-----------------------------------//
// Main Event Study Graphs
//-----------------------------------//
use "$clean/LSEG_reg_elec.dta",clear

drop if fiscalyear==2021
* Winsorise variables
local variables L1log_at_usd L1log_capx_usd L1sales_growth L1ROA L1fixed_asset_ratio L1leverages log_at_usd ROA leverages sales_growth fixed_asset_ratio Log_GHG_Scope1_Intensity Log_GHG_Scope1 log_sale_usd Log_GHG_Scope1_Intensity_growth Log_GHG_Scope1_growth
foreach var of local variables {
	winsor2 `var', replace cuts(1 99)
}


* Event study graphs
reghdfe Log_GHG_Scope1_Intensity event_m3 event_m2 event_0 event_1 event_2 L1log_at_usd L1ROA L1leverages L1fixed_asset_ratio, absorb(gvkey fiscalyear) vce(cluster gvkey)
test event_1+event_2=0
test event_m3+event_m2=0


do "$cod/event_study"
export delimited "$clean/main_event.csv",replace
//-----------------------------------//
// Other Study Graphs
//-----------------------------------//

//-----------------------------------//
// SIC2 digits
//-----------------------------------//

use "$clean/LSEG_reg_all.dta",clear

keep if sic2==49
* Winsorise variables
local variables L1log_at_usd L1log_capx_usd L1sales_growth L1ROA L1fixed_asset_ratio L1leverages log_at_usd ROA leverages sales_growth fixed_asset_ratio Log_GHG_Scope1_Intensity Log_GHG_Scope1 log_sale_usd Log_GHG_Scope1_Intensity_growth Log_GHG_Scope1_growth
foreach var of local variables {
	winsor2 `var', replace cuts(1 99)
}

preserve
* Event study graphs
reghdfe Log_GHG_Scope1_Intensity event_m3 event_m2 event_0 event_1 event_2 L1log_at_usd L1ROA L1leverages L1fixed_asset_ratio, absorb(gvkey fiscalyear) vce(cluster gvkey)
do "$cod/event_study"
export delimited "$clean/sic2_event.csv",replace
restore

preserve
keep if fiscalyear==2017
ebalance treat Log_GHG_Scope1 Log_GHG_Scope1_Intensity,targets(1)
keep gvkey _webal
save "$temp/balance_weight2017_e.dta",replace
restore

* Merge weights
merge m:1 gvkey using "$temp/balance_weight2017_e.dta"


preserve
* Event study graphs
reghdfe Log_GHG_Scope1_Intensity event_m3 event_m2 event_0 event_1 event_2 L1log_at_usd L1ROA L1leverages L1fixed_asset_ratio[aweight=_webal], absorb(gvkey fiscalyear) vce(cluster gvkey)

do "$cod/event_study"
export delimited "$clean/sic2_balancing.csv",replace
restore



//-----------------------------------//
// SIC1 digits
//-----------------------------------//
use "$clean/LSEG_reg_all.dta",clear

keep if sic1==4
* Winsorise variables
local variables L1log_at_usd L1log_capx_usd L1sales_growth L1ROA L1fixed_asset_ratio L1leverages log_at_usd ROA leverages sales_growth fixed_asset_ratio Log_GHG_Scope1_Intensity Log_GHG_Scope1 log_sale_usd Log_GHG_Scope1_Intensity_growth Log_GHG_Scope1_growth
foreach var of local variables {
	winsor2 `var', replace cuts(1 99)
}

preserve
* Event study graphs
reghdfe Log_GHG_Scope1_Intensity event_m3 event_m2 event_0 event_1 event_2 L1log_at_usd L1ROA L1leverages L1fixed_asset_ratio, absorb(gvkey fiscalyear) vce(cluster gvkey)
do "$cod/event_study"
export delimited "$clean/sic1_event.csv",replace
restore

preserve
keep if fiscalyear==2017
ebalance treat Log_GHG_Scope1 Log_GHG_Scope1_Intensity,targets(1)
keep gvkey _webal
save "$temp/balance_weight2017_e.dta",replace
restore

* Merge weights
merge m:1 gvkey using "$temp/balance_weight2017_e.dta"


preserve
* Event study graphs
reghdfe Log_GHG_Scope1_Intensity event_m3 event_m2 event_0 event_1 event_2 L1log_at_usd L1ROA L1leverages L1fixed_asset_ratio[aweight=_webal], absorb(gvkey fiscalyear) vce(cluster gvkey)

do "$cod/event_study"
export delimited "$clean/sic1_balancing.csv",replace
restore

//-----------------------------------//
// All others
//-----------------------------------//

use "$clean/LSEG_reg_all.dta",clear

* Winsorise variables
local variables L1log_at_usd L1log_capx_usd L1sales_growth L1ROA L1fixed_asset_ratio L1leverages log_at_usd ROA leverages sales_growth fixed_asset_ratio Log_GHG_Scope1_Intensity Log_GHG_Scope1 log_sale_usd Log_GHG_Scope1_Intensity_growth Log_GHG_Scope1_growth
foreach var of local variables {
	winsor2 `var', replace cuts(1 99)
}

preserve
* Event study graphs
reghdfe Log_GHG_Scope1_Intensity event_m3 event_m2 event_0 event_1 event_2 L1log_at_usd L1ROA L1leverages L1fixed_asset_ratio, absorb(gvkey fiscalyear) vce(cluster gvkey)
do "$cod/event_study"
export delimited "$clean/all_event.csv",replace
restore

preserve
keep if fiscalyear==2017
ebalance treat Log_GHG_Scope1 Log_GHG_Scope1_Intensity,targets(1)
keep gvkey _webal
save "$temp/balance_weight2017_e.dta",replace
restore

* Merge weights
merge m:1 gvkey using "$temp/balance_weight2017_e.dta"


preserve
* Event study graphs
reghdfe Log_GHG_Scope1_Intensity event_m3 event_m2 event_0 event_1 event_2 L1log_at_usd L1ROA L1leverages L1fixed_asset_ratio[aweight=_webal], absorb(gvkey fiscalyear) vce(cluster gvkey)

do "$cod/event_study"
export delimited "$clean/all_balancing.csv",replace
restore

