
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
// Clean the exchange rate dataset
//-----------------------------------//
use "$compu/vhheyblqrsmvfi5o.dta",clear
gen fiscalyear=year(datadate)
bysort curd fiscalyear:egen mean_exratd_toUSD=mean(exratd_toUSD)
drop datadate exratd_toUSD
duplicates drop
ren curd curcd
save "$inter/exchange_rate.dta",replace


//-----------------------------------//
// Clean firm financial information
//-----------------------------------//
* Append north american and global data
use "$compu/north_american_financial.dta",clear
drop curncd
ren ni nicon
append using "$compu/global_financial.dta"

* For one gvkey with two data formats, keep the formats STD
gen order = .
replace order = 1 if datafmt == "HIST_STD"
replace order = 2 if datafmt == "STD"
bys gvkey fyear (order): keep if _n == _N

destring gvkey,replace
ren fyear fiscalyear

* Merge with exchange_rate dataset 
merge m:1 curcd fiscalyear using "$inter/exchange_rate.dta",keep(3) nogen

* Generate financial variables in USD
foreach var in act at che cstk dlc dltt lct ppegt ppent re seq tstk nicon oibdp sale capx dltis oancf sstk caps {
    gen `var'_usd = `var' * mean_exratd_toUSD
}

sort gvkey fiscalyear
xtset gvkey fiscalyear

* Generate financial ratio variables
gen ROA=nicon_usd/((at_usd+L.at_usd)/2)
gen fixed_asset_ratio=ppent_usd/at_usd
gen leverages=(dlc_usd+ dltt_usd)/at_usd

* Generate log financial variables 
foreach var in act_usd at_usd che_usd cstk_usd dlc_usd dltt_usd lct_usd ppegt_usd ppent_usd re_usd seq_usd tstk_usd nicon_usd oibdp_usd sale_usd capx_usd dltis_usd oancf_usd sstk_usd caps_usd {
	gen log_`var' = log(`var')
}

gen sales_growth=log_sale_usd-L.log_sale_usd

* Generate lagged variables for regressions
local variables log_at_usd log_capx_usd sales_growth ROA fixed_asset_ratio leverages

foreach var in `variables' {
        gen L1`var' = L.`var'
}

save "$inter/all_financial_data.dta",replace


//-----------------------------------//
// * Get the US isin for electricity sector
//-----------------------------------//

use "$inter/all_financial_data.dta",clear

destring sic,replace
* Generate industry variables
gen sic1 = floor(sic/1000)
gen sic2 = floor(sic/100)
* Generate EU dummy
gen EU = 0
replace EU = 1 if inlist(loc, "AUT", "BEL", "BGR", "CYP", "DNK", "FIN", "FRA", "DEU", "GRC")
replace EU = 1 if inlist(loc, "HUN", "IRL", "ITA", "NLD", "POL", "PRT", "ROU")
replace EU = 1 if inlist(loc, "SVN", "ESP", "SWE","EST","LVA","LTU")
replace EU = 1 if inlist(loc,  "HRV","CZE", "LUX","MLT","SVK")

keep if EU==1|loc=="USA"
keep if sic==4911

* Define the calendar year
keep if fyr==12
keep if fiscalyear>=2015&fiscalyear<=2021
keep if missing(isin)
keep gvkey
duplicates drop
export delimited "$inter/missing_isin.csv",replace




//-----------------------------------//
// * Clean the gvkey isin links
//-----------------------------------//
use "$compu/gvkey_isin.dta",clear
keep if primaryflag==1

* Generate sequences
gen start_y = yofd(startdate)
gen end_y   = yofd(enddate)
replace end_y=2022 if missing(end_y)
drop if start_y>end_y

* Expand the dataset
expand end_y - start_y + 1
bysort gvkey start_y: gen year = start_y + _n - 1

keep if year>=2015&year<=2022

* Keep one year for one gvkey
bysort gvkey year:gen n=_n
keep if n==1
drop n

keep gvkey isin year
destring gvkey,replace
ren year fiscalyear
save "$inter/most_US_isin.dta",replace



//-----------------------------------//
// * Get the electricity isin for carbon emissions
//-----------------------------------//
use "$inter/all_financial_data.dta",clear

destring sic,replace
* Generate industry variables
gen sic1 = floor(sic/1000)
gen sic2 = floor(sic/100)
* Generate EU dummy
gen EU = 0
replace EU = 1 if inlist(loc, "AUT", "BEL", "BGR", "CYP", "DNK", "FIN", "FRA", "DEU", "GRC")
replace EU = 1 if inlist(loc, "HUN", "IRL", "ITA", "NLD", "POL", "PRT", "ROU")
replace EU = 1 if inlist(loc, "SVN", "ESP", "SWE","EST","LVA","LTU")
replace EU = 1 if inlist(loc,  "HRV","CZE", "LUX","MLT","SVK")

keep if EU==1|loc=="USA"
keep if sic==4911

* Define the calendar year
keep if fyr==12
keep if fiscalyear>=2015&fiscalyear<=2021


* Get isin if missing isin
ren isin ISIN
merge 1:1 gvkey fiscalyear using "$inter/most_US_isin.dta"
drop if _merge==2
replace isin=ISIN if !missing(ISIN)
drop _merge


* Drop if missing key lagged variables
local variables L1log_at_usd L1sales_growth L1ROA L1fixed_asset_ratio L1leverages
foreach var of local variables {
	drop if missing(`var')
}


drop if missing(isin)

* Strongly balanced
bysort gvkey: egen n_fy = nvals(fiscalyear)
keep if n_fy == 7
* Drop sustainable electricity firm/electricity transmission firms
drop if inlist(gvkey,234117,269744,285082,317954,270451)
drop if inlist(gvkey,18293,20655,160913,314479,296362)
drop if inlist(gvkey,238717,250778,269554,282550,286302,310791,313961,317179)

* Drop EU firms with many free emission allowances
drop if inlist(gvkey,213559,290445,293530)

save "$inter/electricity_initial.dta",replace
keep isin
duplicates drop
export excel using "$inter/electricity_isins.xlsx",firstrow(variables) replace




*--------------------------------------------------
* Clean the carbon emission data from LSEG workspace for electricity sector
*--------------------------------------------------

import excel using "$LSEG/electricity_isins.xlsx",firstrow clear sheet("Sheet2")

local year = 2015
foreach v of varlist D-J {
	rename `v' y`year'
	local year = `year' + 1
}

egen counter = seq(), by(ISIN)
gen datatype = "A" + string(counter)
drop counter

tostring y2020,replace
tostring y2021,replace


reshape long y, i(Name datatype ISIN) j(Year)
drop if Name=="#ERROR"
drop Name DATATYPE

reshape wide y, i(ISIN Year) j(datatype) string


replace yA1=trim(yA1)
replace yA1 = ""  if yA1=="NA"   
destring yA1, replace


ren (ISIN Year) (isin fiscalyear)
ren yA1 GHGscope1

save "$inter/electricity_scope1.dta",replace





* Merge to get the emission
use "$inter/electricity_initial.dta",clear
merge 1:1 isin fiscalyear using "$inter/electricity_scope1.dta"
drop if _merge==2
drop _merge
gen emission_source=""

replace emission_source="LSEG" if !missing(GHGscope1)

* Manually get the missing emissions from annual reports
gen emission_link=.
gen keywords=.
keep conm isin fiscalyear GHGscope1 emission_source emission_link keywords

export excel using "$inter/elec_manual_emissions.xlsx",firstrow(variables) replace


*--------------------------------------------------
* Import the CO2 data
*--------------------------------------------------
import excel using "$inter/elec_manual_emissions copy.xlsx",firstrow clear
save "$inter/elect_co2.dta",replace




*--------------------------------------------------
* Dataset for baseline regressions
*--------------------------------------------------

use "$inter/electricity_initial.dta",clear
merge 1:1 isin fiscalyear using "$inter/elect_co2.dta"
drop if missing(GHGscope1)

gen Log_GHG_Scope1=log(GHGscope1)
xtset gvkey fiscalyear
sort gvkey fiscalyear
gen Log_GHG_Scope1_growth=Log_GHG_Scope1-L.Log_GHG_Scope1

gen intensity=GHGscope1/sale_usd
gen Log_GHG_Scope1_Intensity=log(intensity)



* Isolate the price effect
drop if (Log_GHG_Scope1_growth>1|Log_GHG_Scope1_growth<-1)&!missing(Log_GHG_Scope1_growth)


drop n_fy
bysort gvkey: egen n_fy = nvals(fiscalyear)
keep if n_fy == 7


gen treat=(EU==1)
gen post=(fiscalyear>=2018)
gen did=treat*post
gen rel_year = fiscalyear - 2018 if treat == 1

gen placebo_did=0
replace placebo_did=1 if rel_year>=-1&!missing(rel_year)


gen event_m3 = rel_year == -3
gen event_m2 = rel_year == -2
gen event_0 = rel_year == 0
gen event_1 = rel_year == 1
gen event_2 = rel_year == 2
gen event_3 = rel_year == 3


xtset gvkey fiscalyear
gen Log_GHG_Scope1_Intensity_growth=Log_GHG_Scope1_Intensity-L.Log_GHG_Scope1_Intensity
drop _merge

label variable Log_GHG_Scope1_Intensity  "Log Intensity"
label variable Log_GHG_Scope1  "Log Emissions"
label variable Log_GHG_Scope1_Intensity_growth  "Log Intensity Growth"
label variable Log_GHG_Scope1_growth  "Log Emissions Growth"
label variable log_at_usd   "Log Assets"
label variable ROA          "ROA"
label variable leverages    "Leverage"
label variable sales_growth    "Sales Growth"
label variable fixed_asset_ratio    "Fixed Asset Ratio"

replace ROA=ROA*100
replace L1ROA=L1ROA*100

replace leverages=leverages*100
replace L1leverages=L1leverages*100

replace fixed_asset_ratio=fixed_asset_ratio*100
replace L1fixed_asset_ratio=L1fixed_asset_ratio*100

save "$clean/LSEG_reg_elec.dta",replace


//-----------------------------------//
// * Get the US isin for all industries
//-----------------------------------//

use "$inter/all_financial_data.dta",clear

destring sic,replace
* Generate industry variables
gen sic1 = floor(sic/1000)
gen sic2 = floor(sic/100)
* Generate EU dummy
gen EU = 0
replace EU = 1 if inlist(loc, "AUT", "BEL", "BGR", "CYP", "DNK", "FIN", "FRA", "DEU", "GRC")
replace EU = 1 if inlist(loc, "HUN", "IRL", "ITA", "NLD", "POL", "PRT", "ROU")
replace EU = 1 if inlist(loc, "SVN", "ESP", "SWE","EST","LVA","LTU")
replace EU = 1 if inlist(loc,  "HRV","CZE", "LUX","MLT","SVK")

keep if EU==1|loc=="USA"

* Define the calendar year
keep if fyr==12
keep if fiscalyear>=2015&fiscalyear<=2021
keep if missing(isin)
keep gvkey
duplicates drop
export delimited "$inter/all_missing_isin.csv",replace


//-----------------------------------//
// * Clean the gvkey isin links
//-----------------------------------//
use "$compu/US_gvkey_isin.dta",clear
keep if primaryflag==1

* Generate sequences
gen start_y = yofd(startdate)
gen end_y   = yofd(enddate)
replace end_y=2022 if missing(end_y)
drop if start_y>end_y

* Expand the dataset
expand end_y - start_y + 1
bysort gvkey start_y: gen year = start_y + _n - 1

keep if year>=2015&year<=2022

* Keep one year for one gvkey
bysort gvkey year:gen n=_n
keep if n==1
drop n

keep gvkey isin year
destring gvkey,replace
ren year fiscalyear
save "$inter/all_US_isin.dta",replace



//-----------------------------------//
// * Get all isin for carbon emissions
//-----------------------------------//
use "$inter/all_financial_data.dta",clear

destring sic,replace
* Generate industry variables
gen sic1 = floor(sic/1000)
gen sic2 = floor(sic/100)
* Generate EU dummy
gen EU = 0
replace EU = 1 if inlist(loc, "AUT", "BEL", "BGR", "CYP", "DNK", "FIN", "FRA", "DEU", "GRC")
replace EU = 1 if inlist(loc, "HUN", "IRL", "ITA", "NLD", "POL", "PRT", "ROU")
replace EU = 1 if inlist(loc, "SVN", "ESP", "SWE","EST","LVA","LTU")
replace EU = 1 if inlist(loc,  "HRV","CZE", "LUX","MLT","SVK")

keep if EU==1|loc=="USA"

* Define the calendar year
keep if fyr==12
keep if fiscalyear>=2015&fiscalyear<=2021


* Get isin if missing isin
ren isin ISIN
merge 1:1 gvkey fiscalyear using "$inter/all_US_isin.dta"
drop if _merge==2
replace isin=ISIN if !missing(ISIN)
drop _merge


* Drop if missing key variables for regression
local variables L1log_at_usd L1sales_growth L1ROA L1fixed_asset_ratio L1leverages
foreach var of local variables {
	drop if missing(`var')
}


drop if missing(isin)

* Strongly balanced
bysort gvkey: egen n_fy = nvals(fiscalyear)
keep if n_fy == 7

keep isin
duplicates drop
export excel using "$inter/all_isin_co2.xlsx",firstrow(variables) replace


//-----------------------------------//
// * Clean all carbon emissions
//-----------------------------------//
import excel using "$LSEG/all_isin_co2.xlsx",firstrow clear sheet("Sheet2")


local year = 2015
foreach v of varlist D-J {
	rename `v' y`year'
	local year = `year' + 1
}

egen counter = seq(), by(ISIN)
gen datatype = "A" + string(counter)
drop counter


reshape long y, i(Name datatype ISIN) j(Year)
drop if Name=="#ERROR"
drop Name DATATYPE

reshape wide y, i(ISIN Year) j(datatype) string

replace yA1=trim(yA1)
replace yA1 = ""  if yA1=="NA"   
destring yA1, replace

ren (ISIN Year) (isin fiscalyear)
ren yA1 GHGscope1

drop if missing(GHGscope1)
bysort isin: egen n_fy = nvals(fiscalyear)
keep if n_fy == 7

drop n_fy

save "$inter/all_scope1.dta",replace


//-----------------------------------//
// * Dataset for all regressions
//-----------------------------------//
use "$inter/all_financial_data.dta",clear

destring sic,replace
* Generate industry variables
gen sic1 = floor(sic/1000)
gen sic2 = floor(sic/100)
* Generate EU dummy
gen EU = 0
replace EU = 1 if inlist(loc, "AUT", "BEL", "BGR", "CYP", "DNK", "FIN", "FRA", "DEU", "GRC")
replace EU = 1 if inlist(loc, "HUN", "IRL", "ITA", "NLD", "POL", "PRT", "ROU")
replace EU = 1 if inlist(loc, "SVN", "ESP", "SWE","EST","LVA","LTU")
replace EU = 1 if inlist(loc,  "HRV","CZE", "LUX","MLT","SVK")

keep if EU==1|loc=="USA"

* Define the calendar year
keep if fyr==12
keep if fiscalyear>=2015&fiscalyear<=2021


* Get isin if missing isin
ren isin ISIN
merge 1:1 gvkey fiscalyear using "$inter/all_US_isin.dta"
drop if _merge==2
replace isin=ISIN if !missing(ISIN)
drop _merge


* Drop if missing key variables for regression
local variables L1log_at_usd L1sales_growth L1ROA L1fixed_asset_ratio L1leverages
foreach var of local variables {
	drop if missing(`var')
}


drop if missing(isin)

* Replace sustainable electricity firm/electricity transmission firms
* EU
replace sic=49112 if inlist(gvkey,234117,269744,285082,317954,270451,314479,296362)
* EU
replace sic=49112 if inlist(gvkey,238717,250778,269554,282550,286302,310791,313961,317179)

* US
replace sic=49112 if inlist(gvkey,18293,20655,160913)

merge m:1 isin fiscalyear using "$inter/all_scope1.dta"
keep if _merge==3
drop _merge


drop if sic==4911


gen Log_GHG_Scope1=log(GHGscope1)
xtset gvkey fiscalyear
sort gvkey fiscalyear
gen Log_GHG_Scope1_growth=Log_GHG_Scope1-L.Log_GHG_Scope1

gen intensity=GHGscope1/sale_usd
gen Log_GHG_Scope1_Intensity=log(intensity)


* Isolate the price effect
drop if (Log_GHG_Scope1_growth>1|Log_GHG_Scope1_growth<-1)&!missing(Log_GHG_Scope1_growth)

append using "$clean/LSEG_reg_elec"

drop n_fy
* Strongly balanced
bysort gvkey: egen n_fy = nvals(fiscalyear)
keep if n_fy == 7


drop treat post did rel_year placebo_did event_m3 event_m2 event_0 event_1 event_2 event_3
gen treat=(EU==1&sic==4911)
gen post=(fiscalyear>=2018)
gen did=treat*post
gen rel_year = fiscalyear - 2018 if treat == 1

gen placebo_did=0
replace placebo_did=1 if rel_year>=-1&!missing(rel_year)


gen event_m3 = rel_year == -3
gen event_m2 = rel_year == -2
gen event_0 = rel_year == 0
gen event_1 = rel_year == 1
gen event_2 = rel_year == 2
gen event_3 = rel_year == 3


drop if EU==1&treat==0&sic!=49112
drop if fiscalyear==2021

replace ROA=ROA*100
replace L1ROA=L1ROA*100

replace leverages=leverages*100
replace L1leverages=L1leverages*100

replace fixed_asset_ratio=fixed_asset_ratio*100
replace L1fixed_asset_ratio=L1fixed_asset_ratio*100

save "$clean/LSEG_reg_all.dta",replace



//-----------------------------------//
// * Calculate the emission ratio (Electricity sector vs all industries in the EU and US)
//-----------------------------------//
use "$inter/all_financial_data.dta",clear

destring sic,replace
* Generate industry variables
gen sic1 = floor(sic/1000)
gen sic2 = floor(sic/100)
* Generate EU dummy
gen EU = 0
replace EU = 1 if inlist(loc, "AUT", "BEL", "BGR", "CYP", "DNK", "FIN", "FRA", "DEU", "GRC")
replace EU = 1 if inlist(loc, "HUN", "IRL", "ITA", "NLD", "POL", "PRT", "ROU")
replace EU = 1 if inlist(loc, "SVN", "ESP", "SWE","EST","LVA","LTU")
replace EU = 1 if inlist(loc,  "HRV","CZE", "LUX","MLT","SVK")

keep if EU==1|loc=="USA"

* Define the calendar year
keep if fyr==12
keep if fiscalyear>=2015&fiscalyear<=2021


* Get isin if missing isin
ren isin ISIN
merge 1:1 gvkey fiscalyear using "$inter/all_US_isin.dta"
drop if _merge==2
replace isin=ISIN if !missing(ISIN)
drop _merge

drop if missing(isin)


merge m:1 isin fiscalyear using "$inter/all_scope1.dta"
keep if _merge==3
drop _merge


gen Log_GHG_Scope1=log(GHGscope1)
xtset gvkey fiscalyear
sort gvkey fiscalyear

merge 1:1 isin fiscalyear using "$clean/LSEG_reg_elec"
gen sample=(_merge!=1)


* Winsorise variables
local variables L1log_at_usd L1log_capx_usd L1sales_growth L1ROA L1fixed_asset_ratio L1leverages log_at_usd ROA leverages sales_growth fixed_asset_ratio Log_GHG_Scope1_Intensity Log_GHG_Scope1
foreach var of local variables {
	winsor2 `var', replace cuts(1 99)
}

unique gvkey


bysort sample: egen total_GHG=total(GHGscope1)
keep sample total_GHG
duplicates drop
gsort -total_GHG
egen totals=total(total_GHG)
gen ratio=total_GHG/totals







