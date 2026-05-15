//----------------------------------------------------------------------------//
// Preface
//----------------------------------------------------------------------------//

clear all
set more off
set maxvar 10000
cap log close
pause on


version 18.0
set seed 42

global outregoptions label bdec(4) sdec(4) nocons drop($controls) st(coef se blank)
graph set window fontface "lmroman10-regular"


if c(username) == "yourname" {
	global path "/Users/yourname/file"
	cd "/Users/yourname/file"
}

else {
	global path ""
	cd ""
}

glo cod					"$path/Code"
glo inter 				"$path/Intermediate Data"
glo compu 				"$path/Raw_data/Compustat"
glo clean				"$path/Clean Data"
glo out					"$path/output"
glo LSEG				"$path/Raw_data/LSEG"
glo raw					"$path/Raw_data"
glo temp 				"$path/temp"



//----------------------------------------------------------------------------//
// Run files
//----------------------------------------------------------------------------//

* Clean the data
do "$cod/data_cleaning"

* Draw the table
do "$cod/Tables"

* Files to draw the figure
do "$cod/figures"

* The figure used in paper is drawn by the R code Figure.R



