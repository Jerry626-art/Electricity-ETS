	estimates store esg
	parmest, norestore

	// Only keep event dummies
	keep if strpos(parm, "event_") > 0

	// Create event time
	gen time = .
	replace time = -3 if parm == "event_m3"
	replace time = -2 if parm == "event_m2"
	replace time =  0 if parm == "event_0"
	replace time =  1 if parm == "event_1"
	replace time =  2 if parm == "event_2"

	gen estimate_3dp = string(round(estimate, .001), "%6.3f")
	destring estimate_3dp,replace

	// t=-1 is the base year
	insobs 1, before(3)
	replace parm = "event_m1" in 3
	replace estimate = 0.000 in 3
	replace estimate_3dp = 0 in 3
	replace time = -1 in 3
	replace min95 = 0 in 3
	replace max95 = 0 in 3
	   
	twoway (rcap min95 max95 time) ///
		(scatter estimate time, mlabel(estimate_3dp) msymbol(circle)), ///
		yline(0, lpattern(dash) lcolor(gs8)) ///
		xtitle("Years relative to Carbon Price Increase") ///
		ytitle("Effect on Intensity") ///
		yscale(range(0.1 -0.3)) ///
		title("`var'") ///
		legend(off)

		
