
global dir="E:\我的文件\科研\TechDiscontinuities\stata"
global window_radical = 5
global window_treatment = 5 
cd E:\FinalMY557\stata

global X experience ln_cited_times_perpat ln_reg_inventor_all 

*0) Preparation
{
cd E:\FinalMY557
clear
import delimited using radical_df.csv
keep x1 x2 x3
rename x1 rawname
rename x2 title
rename x3 rawpatentid


*(Split the inventors)
gen temp=";"
gen rawpatentid_count =(strlen(rawpatentid) - strlen(subinstr(rawpatentid, temp, "", .)))/strlen(temp)
drop temp

gen x=rawpatentid
gen x1=""
	
forvalues i= 1/3{
	local j=`i'+1
		gen patent_id`i'=""
		replace patent_id`i'=substr(x,strpos(x,";")+1,.) if rawpatentid_count!=0
		replace x1=patent_id`i'  if rawpatentid_count!=0
		replace patent_id`i'=substr(x,1,strpos(x,";")-1) if rawpatentid_count!=0
		local l=`i'-1

		replace patent_id`i'=x if rawpatentid_count==`l'
		replace x=x1 if rawpatentid_count!=0
}
drop x x1
drop rawpatentid rawpatentid_count
format %37s title

*create breakthrough identifier
gen patent_id = patent_id1
merge m:1 patent_id using $dir\rawdata\uspto\USPTO_rawdata\rawgranted_date.dta
*merge m:1 patent_id using $dir\rawdata\uspto\USPTO_rawdata\application.dta
*rename date granted_date
keep if _merge==3
drop _merge
keep rawname title patent_id1 patent_id2 patent_id3 patent_id granted_date
rename patent_id identifier
rename granted_date breakthrough_grantdate
save E:\FinalMY557\stata\rawradicalpatent.dta,replace



cd E:\FinalMY557\stata

forvalues i=1/3{
	use rawradicalpatent.dta,clear
	rename patent_id`i' patent_id
	keep rawname title patent_id identifier breakthrough_grantdate
	drop if patent_id ==""
	save rawradicalpatent`i'.dta,replace
}
clear
forvalues i=1/3{
	append using rawradicalpatent`i'.dta
	erase rawradicalpatent`i'.dta
}
keep title patent_id identifier breakthrough_grantdate
duplicates drop patent_id,force
save rawbreakthrough.dta,replace

*prepare non-US inventor list
use rawinventor_withdate.dta,clear
drop rule_47 deceased uuid name_first name_last
rename rawlocation_id id 
merge m:1 id using $dir\rawdata\uspto\USPTO_rawdata\rawlocation.dta
drop if country=="US" | country=="USA"
duplicates drop inventor_id,force
keep inventor_id
save non-US_inventor_list.dta,replace
}



*1) Obtain the g2 breakthrough patents by the same inventor
{
/*
use $dir\rawdata\uspto\USPTO_rawdata\uspatentcitation.dta,clear
keep patent_id citation_id

rename patent_id x
rename citation_id patent_id
rename x citing_id
save temp_uscitation.dta,replace

*/

*G1
forvalues g=1/5{
	use temp_uscitation.dta,clear
	merge m:1 patent_id using rawbreakthrough.dta
	keep if _merge==3
	drop _merge
	save rawbreakthrough_g2.dta,replace

	joinby patent_id using $dir\rawdata\uspto\USPTO_rawdata\rawinventor.dta
	keep title identifier breakthrough_grantdate patent_id citing_id inventor_id rawlocation_id name_first name_last sequence

	rename inventor_id inventor_id_g1
	rename rawlocation_id rawlocation_id_g1
	rename name_first name_first_g1
	rename name_last name_last_g1
	rename sequence sequence_g1
	rename patent_id patent_id_g1

	rename citing_id patent_id
	joinby patent_id using $dir\rawdata\uspto\USPTO_rawdata\rawinventor.dta

	rename inventor_id inventor_id_g2
	rename rawlocation_id rawlocation_id_g2
	rename name_first name_first_g2
	rename name_last name_last_g2
	rename sequence sequence_g2
	rename patent_id patent_id_g2
	keep title identifier breakthrough_grantdate patent_id_g1 patent_id_g2 inventor_id_g1 rawlocation_id_g1 name_first_g1 name_last_g1 sequence_g1 inventor_id_g2 rawlocation_id_g2 name_first_g2 name_last_g2 sequence_g2
	save temp_radical_g2.dta,replace
	use temp_radical_g2.dta,clear

	*(Key part: obtain patents cited by the same radical inovator)
	keep if inventor_id_g1== inventor_id_g2 // Choose radical_patent g2

	keep patent_id_g2 title identifier breakthrough_grantdate
	rename patent_id patent_id
	duplicates drop patent_id,force

	append using rawbreakthrough.dta
	duplicates drop p,force

	save breakthrough_patent_id,replace
	save rawbreakthrough.dta,replace
}
}



*2) Obtain treated and control patents
*(Obtain patents that cite breakthrough patents)
{
use breakthrough_patent_id,clear

joinby patent_id using temp_uscitation.dta
rename patent_id patent_id_g1
rename citing_id patent_id
merge m:1 patent_id using breakthrough_patent_id // drop citations from radical-ers itself
keep if _merge==1
drop _merge
*add appdate
merge m:1 patent_id using $dir\rawdata\uspto\USPTO_rawdata\application.dta
keep if _merge==3
drop _merge
rename patent_id patent_id_g2
rename date appdate_g2
drop id series_code number country
rename patent_id_g1 patent_id
merge m:1 patent_id using $dir\rawdata\uspto\USPTO_rawdata\application.dta
keep if _merge==3
drop _merge
rename patent_id patent_id_g1
rename date appdate_g1
drop id series_code number country
gen year_g1=substr(appdate_g1,1,4)
gen year_g2=substr(appdate_g2,1,4)
gen year_breakthrough=substr(breakthrough_grantdate,1,4)
destring year_*,replace
save final_breakthrough_patent.dta,replace

*(Add information to breakthrough patents)
use final_breakthrough_patent.dta,clear
*add inventor for g2
rename patent_id_g2 patent_id
joinby patent_id using $dir\rawdata\uspto\USPTO_rawdata\rawinventor.dta
rename patent_id patent_id_g2
foreach var in inventor_id rawlocation_id name_first name_last sequence{
	rename `var' `var'_g2
}
drop uuid rule_47 deceased
format %24s inventor_id_g2 name_first_g2 name_last_g2
order patent_id_g1 patent_id_g2 appdate_g1 appdate_g2 year_breakthrough,before( year_g1)
save final_breakthrough_inventors.dta,replace


*(Obtain multi-treated inventors)
use final_breakthrough_inventors.dta,clear
*drop if year_breakthrough>2012 | year_breakthrough < 1976
*drop if year_g2>2012 | year_g2 < 1976
keep if year_g2 <= year_breakthrough + 10  // specify the treated inventor

bys identifier inventor_id_g2: gen n=_n
keep if n==1
drop n
bys inventor_id_g2: gen N=_N
drop if N==1
drop N
keep inventor_id_g2
duplicates drop inventor_id_g2,force
save inventor_multi_treated.dta,replace

}

**2-1 Obtain treated inventors
{
*(Get all treated inventors)
use final_breakthrough_inventors.dta,clear  // Note that patent_id_g2 are all patents that exposes to radical breakthrough
drop if year_breakthrough>2012 | year_breakthrough < 1976
drop if year_g2 < 1976
keep if year_g2 <= year_breakthrough + 5  // specify the window for exposure
*keep if sequence==0 // the first author as treated
*merge m:1 inventor_id_g2 using inventor_multi_treated.dta // remove multi-treated inventors
*keep if _merge==1
*drop _merge
bys inventor_id_g2 (appdate_g2): gen n=_n // the first cited radical patent as identifier
keep if n==1
drop n

bys identifier inventor_id_g2 (breakthrough_grantdate): gen n=_n
keep if n==1
keep title identifier breakthrough_grantdate inventor_id_g2 year_g2
rename inventor_id inventor_id
rename year_g2 citing_year
save treated_inventor_id.dta,replace

*(Get all treated patents)
use treated_inventor_id.dta,clear  // start to obtain all the patents by treated inventors
joinby inventor_id using $dir\rawdata\uspto\USPTO_rawdata\rawinventor.dta
format %14s name_first name_last
drop rule_47 deceased uuid

merge m:1 patent_id using $dir\rawdata\uspto\USPTO_rawdata\application.dta
keep if _merge==3
drop _merge
rename date appdate
drop id series_code number country

gen year=substr(appdate, 1, 4)
gen year_breakthrough=substr(breakthrough_grantdate, 1, 4)
destring year*,replace

drop if year< 1976 | year>2012

bys identifier inventor_id: egen first_year = min(year)
bys identifier inventor_id: egen last_year = max(year)

keep if first_year < year_breakthrough
keep if last_year > year_breakthrough
drop first_year last_year

merge m:1 inventor_id using non-US_inventor_list.dta // remove non-us inventors
keep if _merge==1
drop _merge
save treated_patents.dta,replace // all the 1976-2012 patents for treated inventors

}

**2-2 Obtain untreated inventors
{
*2-2-1 obtain all radicalers
use breakthrough_patent_id,clear
joinby patent_id using $dir\rawdata\uspto\USPTO_rawdata\rawinventor.dta
duplicates drop inventor_id,force
keep inventor_id
save excludable_radicalers.dta,replace 

use final_breakthrough_inventors.dta,clear
keep inventor_id_g2
rename i inventor_id
duplicates drop i,force
append using excludable_radicalers.dta
duplicates drop i,force
save excludable_radicalers.dta,replace 



*2-2-2 obtain all citers originated from the radical patent (not inventor)
*(Iterate citation trees within treatment period)
use treated_patents.dta,clear
keep identifier year_breakthrough
rename year year
gen exposed = 1
duplicates drop id,force
sort id
gen order =_n
save exposure.dta,replace

/*
*prepare uscitation with date
use temp_uscitation.dta,clear
merge m:1 patent_id using $dir\rawdata\uspto\USPTO_rawdata\application.dta
keep if _merge==3
gen year_cited= substr(date,1,4)
drop _merge id series_code number country date
rename p p
rename c patent_id
merge m:1 patent_id using $dir\rawdata\uspto\USPTO_rawdata\application.dta
keep if _merge==3
gen year_citing= substr(date,1,4)
drop _merge id series_code number country date
rename patent_id citing_id
rename p patent_id
destring year*,replace
save temp_uscitation_withdate.dta,replace


*prepare usinventor with date
use $dir\rawdata\uspto\USPTO_rawdata\rawinventor.dta,clear
merge m:1 patent_id using $dir\rawdata\uspto\USPTO_rawdata\application.dta
keep if _merge==3
gen year= substr(date,1,4)
destring year,replace
drop _merge id series_code number country date
save rawinventor_withdate.dta,replace
*/

*run the core programme
use temp_uscitation_withdate.dta,clear
drop if year_citing <1976 | year_cited <1976 | year_citing >2021 | year_cited >2021
drop year*
save temp_uscitation_forloop.dta,replace

use rawinventor_withdate.dta,clear
drop if year <1976 | year >2021
drop year
save rawinventor_forloop.dta,replace

use breakthrough_patent_id,clear  // Note: no spillover from any of the radical patents
joinby patent_id using temp_uscitation_forloop.dta // get direct citers
keep citing_id
rename citing_id patent_id
duplicates drop patent_id,force
save temp.dta,replace

local end = 3   -1  // set the iteration times
forvalues i=1/`end'{ 
	use temp.dta,clear // direct citers' patents
	joinby patent_id using temp_uscitation_forloop.dta // get indirect citers
	keep citing_id
	rename citing_id patent_id // indirect citer's patent_id
	append using temp.dta
	duplicates drop patent_id,force
	save temp.dta,replace
}
save exposed_patents.dta,replace	
joinby patent_id using rawinventor_forloop.dta
keep inventor_id
duplicates drop inventor_id,force
save excludable_citers.dta,replace

erase temp.dta 
erase rawinventor_forloop.dta 
erase temp_uscitation_forloop.dta

*(Obtain control inventors)
clear
use rawinventor_withdate.dta,clear
drop rule_47 deceased uuid
*remove potentially treated cases
merge m:1 inventor_id using excludable_citers.dta
keep if _merge==1
drop _merge
merge m:1 inventor_id using excludable_radicalers.dta
keep if _merge==1
drop _merge
/* no need
merge m:1 inventor_id using treated_inventor_id.dta
keep if _merge==1
*/
drop if year<1976 | year>2012

merge m:1 patent_id using $dir\rawdata\uspto\USPTO_rawdata\application.dta
keep if _merge==3
keep patent_id inventor_id rawlocation_id name_first name_last sequence year date
rename date appdate
merge m:1 inventor_id using non-US_inventor_list.dta // remove non-us inventors
keep if _merge==1
drop _merge
save control_patents.dta,replace // all the 1976-2012 patents for control inventors

use control_patents.dta,clear  // add location
rename rawlocation_id id 
merge m:1 id using $dir\rawdata\uspto\USPTO_rawdata\rawlocation.dta
keep if _merge==3
drop _merge
drop if location_id==""
save control_patents_withlocation.dta,replace
}





*3) PSM matching: create the final control group
**3-1 Create initial format
{
*Obtain ALL patents
use control_patents.dta,clear
gen treated=0
append using treated_patents.dta
replace treated =1 if treated==.
save all_patents.dta,replace

* count of patent per year
use rawinventor_withdate.dta,clear
gen N_count=1
collapse (sum) N,by(year inventor_id)
save N_count_peryear.dta,replace

*produce format
use all_patents.dta,clear
bys inventor_id year treated (appdate): gen n=_n
bys inventor_id year treated (appdate): gen N=_N
keep if n==N // keep last filed
keep inventor_id year treated identifier year_breakthrough rawlocation_id citing_year

rename rawlocation_id id 
merge m:1 id using $dir\rawdata\uspto\USPTO_rawdata\rawlocation.dta
keep if _merge==3
drop _merge
drop if location_id==""
keep inventor_id year treated citing_year identifier year_breakthrough location_id city state country latlong
save rawformat.dta,replace

use rawformat.dta,clear
merge m:1 inventor_id year using total-citedtimes-by-inventor.dta
	drop if _merge==2
	drop _merge
merge m:1 inventor_id year using experience.dta
	drop if _merge==2
	drop _merge
merge m:1 inventor_id year using speed-to-assimilate.dta
	drop if _merge==2
	drop _merge
merge m:1 inventor_id year using collaborator_count.dta
	drop if _merge==2
	drop _merge
merge m:1 inventor_id year using N_count_peryear.dta
	drop if _merge==2
	drop _merge
	
forvalues i = 1/6{
	merge m:1 inventor_id year using inventor_nber_count_sector`i'.dta
	drop if _merge==2
	drop _merge
}

forvalues i = 1/6{
	merge m:1 location_id year using region_inventor_count_sector`i'.dta
	drop if _merge==2
	drop _merge
}

foreach var in cumulative_cited_times cumulative_patent_counts cited_times_perpat collaborator_count nber_chemical nber_computer_comm nber_drug_medical nber_electri_electron nber_mechanical nber_others reg_inventor_chemical reg_inventor_computer_comm reg_inventor_drug_medical reg_inventor_electri_electron reg_inventor_mechanical reg_inventor_others{
	replace `var'=0 if `var'==.
}
egen reg_inventor_all = rowtotal(reg_inventor_chemical reg_inventor_computer_comm reg_inventor_drug_medical reg_inventor_electri_electron reg_inventor_mechanical reg_inventor_others)

format %24s inventor_id
format %16s identifier
format %12s city
*keep if country=="US"
drop if experience > 80 // drop outliers

foreach var in cumulative_cited_times cumulative_patent_counts cited_times_perpat reg_inventor_chemical reg_inventor_computer_comm reg_inventor_drug_medical reg_inventor_electri_electron reg_inventor_mechanical reg_inventor_others N_count{
	gen ln_`var'= ln(`var'+1)
}

gen ln_reg_inventor_all = ln(reg_inventor_all + 1)
foreach var in $X{
	drop if `var'==.
}

save format.dta,replace

use format.dta,clear
save US_format.dta,replace
}

**3-2 PSM matching (Yearly matched)
{
forvalues year=1976/2012{
	use US_format.dta,clear
	keep if year==`year'
	logit treated $X ///
	,iterate(10)
	predict p
	
	psmatch2 treated, pscore(p) // replacement - bias minimization

	save psm_`year'.dta,replace
	keep if treated==1

	keep inventor_id _n1 p
	rename _n1 _id
	rename inventor_id inventor_id_treated
	rename p _pscore_treated
	merge m:1 _id using psm_`year'.dta
	keep if _merge==3
	drop _merge
	keep inventor_id_treated inventor_id year _pscore* p*
	rename inventor_id inventor_id_control
	rename p _pscore_control
	drop _pscore
	save psm_matched_`year'.dta,replace
}

clear
forvalues year=1976/2012{
	append using psm_matched_`year'.dta
	erase psm_matched_`year'.dta
}
save psm_matched.dta,replace

clear
forvalues year=1976/2012{
	append using psm_`year'.dta
	erase psm_`year'.dta
}
save psm_result.dta,replace

use psm_matched.dta,clear
keep inventor_id_control year inventor_id_treated
rename inventor_id_control inventor_id
bys inventor_id year: gen n=_n
keep if n==1
drop n
save temp_merge.dta,replace

use psm_result.dta,clear
keep if treated==1
keep inventor_id year year_breakthrough identifier citing_year
rename year_breakthrough year_breakthroughx
rename identifier identifierx
rename citing_year citing_yearx
save temp_merge2.dta,replace // identifier and breakthrough year

use US_format.dta,clear
merge m:1 inventor_id year using temp_merge.dta // obtain matched control
drop if _merge==1 & treated==0
drop _merge
rename inventor_id inv
rename inventor_id_treated inventor_id
merge m:1 inventor_id year using temp_merge2.dta // to add breakthrough year to matched control
drop if _merge==2
replace year_breakthrough= year_breakthroughx if _merge==3
replace identifier=identifierx if _merge==3
replace citing_year=citing_yearx if _merge==3
drop identifierx year_breakthroughx citing_yearx _merge
rename inventor_id inventor_id_treated
rename inv inventor_id

save finalformat.dta,replace
erase temp_merge.dta
erase temp_merge2.dta

*Find FULL control for each treated
use finalformat.dta,clear
keep if treated==0
drop inventor_id_treated identifier citing_year year_breakthrough
save finalformat_onlycontrol.dta,replace
use finalformat.dta,clear
keep if treated==1
keep inventor_id identifier year_breakthrough citing_year
duplicates drop inventor_id,force
rename inventor_id inventor_id_treated
save finalformat_identifier,replace
use psm_matched.dta,clear
keep inventor_id_control year inventor_id_treated
rename inventor_id_control inventor_id
merge m:1 inventor_id year using finalformat_onlycontrol.dta
drop _merge
merge m:1 inventor_id_treated using finalformat_identifier
drop _merge
save finalformat_onlycontrol.dta,replace // control are duplicated

*Get real format (1:1)
use finalformat.dta,clear
keep if treated==1
append using finalformat_onlycontrol.dta
/*
ttest ln_reg_inventor_chemical if  year==2000 ///
	,by(treated)
*/
}


**3-3 PSM matching (Yearly and sectorally matched)
{
foreach nber in nber_chemical nber_computer_comm nber_drug_medical nber_electri_electron nber_mechanical{
	forvalues year=1976/2012{
		use US_format.dta,clear
		keep if year==`year'
		keep if `nber'==1
		
		
		logit treated $X ///
		,iterate(10)
		predict p
		
		psmatch2 treated, pscore(p) // replacement - bias minimization
		gen common=_support
		drop if common == 0
		drop common
		save psm_`nber'_`year'.dta,replace
		keep if treated==1

		keep inventor_id _n1 p _pdif
		rename _n1 _id
		rename _pdif pscore_diff
		rename inventor_id inventor_id_treated
		rename p _pscore_treated
		merge m:1 _id using psm_`nber'_`year'.dta
		keep if _merge==3
		drop _merge
		keep inventor_id_treated inventor_id year _pscore* p* 
		rename inventor_id inventor_id_control
		rename p _pscore_control
		drop _pscore
		save psm_matched_`nber'_`year'.dta,replace
	}
}
	clear
foreach nber in nber_chemical nber_computer_comm nber_drug_medical nber_electri_electron nber_mechanical{
	forvalues year=1976/2012{
		append using psm_matched_`nber'_`year'.dta
		erase psm_matched_`nber'_`year'.dta
	}
}
bys inventor_id_treated year (pscore_diff): gen n=_n
keep if n==1
drop n
save psm_matched.dta,replace

clear
foreach nber in nber_chemical nber_computer_comm nber_drug_medical nber_electri_electron nber_mechanical{
	forvalues year=1976/2012{
		append using psm_`nber'_`year'.dta
		erase psm_`nber'_`year'.dta
	}
}
save psm_result.dta,replace

use psm_matched.dta,clear
keep inventor_id_control year inventor_id_treated
rename inventor_id_control inventor_id
bys inventor_id year: gen n=_n
keep if n==1
drop n
save temp_merge.dta,replace

use psm_result.dta,clear
keep if treated==1
keep inventor_id year year_breakthrough identifier citing_year
rename year_breakthrough year_breakthroughx
rename identifier identifierx
rename citing_year citing_yearx
bys inventor_id year:gen n=_n
keep if n==1
drop n
save temp_merge2.dta,replace // identifier and breakthrough year

use US_format.dta,clear
merge m:1 inventor_id year using temp_merge.dta // obtain matched control
drop if _merge==1 & treated==0
drop _merge
rename inventor_id inv
rename inventor_id_treated inventor_id
merge m:1 inventor_id year using temp_merge2.dta // to add breakthrough year to matched control
drop if _merge==2
replace year_breakthrough= year_breakthroughx if _merge==3
replace identifier=identifierx if _merge==3
replace citing_year=citing_yearx if _merge==3
drop identifierx year_breakthroughx citing_yearx _merge
rename inventor_id inventor_id_treated
rename inv inventor_id

save finalformat.dta,replace
erase temp_merge.dta
erase temp_merge2.dta

*Find FULL control for each treated
use finalformat.dta,clear
keep if treated==0
drop inventor_id_treated identifier citing_year year_breakthrough
save finalformat_onlycontrol.dta,replace
use finalformat.dta,clear
keep if treated==1
keep inventor_id identifier year_breakthrough citing_year
duplicates drop inventor_id,force
rename inventor_id inventor_id_treated
save finalformat_identifier,replace
use psm_matched.dta,clear
keep inventor_id_control year inventor_id_treated
rename inventor_id_control inventor_id
merge m:1 inventor_id year using finalformat_onlycontrol.dta
drop _merge
merge m:1 inventor_id_treated using finalformat_identifier
drop if _merge==2
drop _merge
save finalformat_onlycontrol.dta,replace // control are duplicated

use psm_matched.dta,clear // keep matched treated unit
bys inventor_id_treated year: gen n=_n
keep if n==1
drop n
keep inventor_id_treated year
rename i inventor_id
save psm_matched_treated_id.dta,replace

*Get real format
use finalformat.dta,clear
keep if treated==1
merge m:1 inventor_id year using psm_matched_treated_id.dta
keep if _merge==3
drop _merge
append using finalformat_onlycontrol.dta

}







*5) Constructing dependent variable
**5-0 Preparation
{
*add location
use all_patents.dta,clear
rename rawlocation_id id
joinby id using $dir\rawdata\uspto\USPTO_rawdata\rawlocation.dta
format %18s city
rename id rawlocation_id 
sort inventor_id ( appdate )
drop if location_id==""
save temp.dta,replace

*add collaborators
use temp.dta,clear  // the list of all inventors
rename inventor_id i
rename rawlocation_id rawlocation_id_inv
rename location_id location_id_inv
rename latlong latlong_inv
rename sequence  sequence_inv
drop name_first name_last city state
rename country country_inv
joinby patent_id using $dir\rawdata\uspto\USPTO_rawdata\rawinventor.dta
drop name_first name_last rule_47 deceased uuid
rename inventor_id collaborator_id
rename i inventor_id
rename sequence collaborator_sequence
rename rawlocation_id collaborator_rawlocation_id
bys patent_id: gen N_inventors=_N
save temp2.dta,replace
}

**5-1 Calculate mobility toward first-mover
{
*Get breakthrough location
use all_patents.dta,clear
duplicates drop identifier,force
keep identifier
gen patent_id = identifier
joinby patent_id using rawinventor_withdate.dta
keep identifier patent_id inventor_id rawlocation_id year
rename rawlocation_id id
joinby id using $dir\rawdata\uspto\USPTO_rawdata\rawlocation.dta
format %18s city
rename id rawlocation_id 
keep if country=="US"
drop if latlong=="" | location_id==""

bys identifier location_id: gen n=_n
keep if n==1
drop n

keep identifier location_id latlong
rename location_id location_id_breakthrough
rename latlong latlong_breakthrough
save breakthrough_location.dta,replace

/*
*Number of collaborations to radical region
use temp2.dta,clear  // the list of all collaborators
joinby identifier using breakthrough_location.dta // Note: one obs may have multi-locations
keep if location_id== location_id_breakthrough

bys inventor_id collaborator_id year: gen n=_n
keep if n==1
collapse (sum) n,by(inventor_id year)
rename n collab_to_origin
save collab_to_origin.dta,replace
*/


*Closeness to radical region
use finalformat.dta,clear
keep if treated==1
append using finalformat_onlycontrol.dta // controls are duplicated (1:1)
joinby identifier using breakthrough_location.dta // Note: one obs may have multi-locations
gen lat = substr(latlong,1,strpos(latlong,"|")-1)
gen lon = substr(latlong,strpos(latlong,"|")+1,.)
gen lat_break = substr(latlong_breakthrough,1,strpos(latlong_breakthrough,"|")-1)
gen lon_break = substr(latlong_breakthrough,strpos(latlong_breakthrough,"|")+1,.)
destring lat lon lat_break lon_break,replace
gen dist= ((lat - lat_b)^2 + (lon - lon_break)^2)^0.5
drop if dist==.
bys inventor_id identifier year: egen distm=min(dist)
drop dist
rename dist dist
bys inventor_id identifier year: gen n=_n
keep if n==1
keep identifier inventor_id year dist
save distance_to_identifier.dta,replace
}

**5-2 Calculate ties
{
*(Calculate weighted average persistence of ties)
use temp2.dta,clear  // the list of all collaborators
bys inventor_id collaborator_id (appdate): gen n=_n
keep if n==1
keep inventor_id collaborator_id year // get the earliest co-patent
drop if inventor_id==collaborator_id
bys inventor_id collaborator_id year: gen n=_n // drop duplicated earliest co-patent
keep if n==1
drop n
rename year earliest_collab_year
save earliest_collab_year.dta,replace

use temp2.dta,clear  // the list of all collaborators
merge m:1 inventor_id collaborator_id using earliest_collab_year.dta
drop if _merge==2 // all the unmatched are inventor_id==collaborator_id
drop _merge
gen tie_persistence_years = year - earliest_collab_year
drop if inventor_id==collaborator_id // if a patent does not have any collaborators, it is counted as 0
collapse (mean) tie_persistence_years,by(inventor_id year) 
save tie_persistence_years.dta,replace

*New ties
use temp2.dta,clear  // the list of all collaborators
merge m:1 inventor_id collaborator_id using earliest_collab_year.dta
keep if _merge==3 // all the unmatched are inventor_id==collaborator_id
drop _merge
gen tie_persistence_years = year - earliest_collab_year
keep if tie_persistence_years <= 1
gen new_collab_times = 1 
collapse (sum) new_collab_times,by(inventor_id year)
save temp6.dta,replace
use N_count_peryear.dta,clear
merge m:1 inventor_id year using temp6.dta
drop _merge
replace new_collab_times=0 if new_collab_times==.
gen new_collab_times_perpat=new_collab_times/N
drop N
save new_collab_times.dta,replace
erase temp6.dta


*Old ties
use temp2.dta,clear  // the list of all collaborators
merge m:1 inventor_id collaborator_id using earliest_collab_year.dta
keep if _merge==3 // all the unmatched are inventor_id==collaborator_id
drop _merge
gen tie_persistence_years = year - earliest_collab_year
keep if tie_persistence_years >= 5
gen old_collab_times = 1 
collapse (sum) old_collab_times,by(inventor_id year)
save temp6.dta,replace
use N_count_peryear.dta,clear
merge m:1 inventor_id year using temp6.dta
drop _merge
replace old_collab_times=0 if old_collab_times==.
gen old_collab_times_perpat=old_collab_times/N
drop N
save old_collab_times.dta,replace
erase temp6.dta

*(Calculate spatial clustering of ties)
use temp2.dta,clear  // the list of all collaborators
rename collaborator_rawlocation_id id
joinby id using $dir\rawdata\uspto\USPTO_rawdata\rawlocation.dta
drop city state
rename id collaborator_rawlocation_id
rename location_id collaborator_location_id
rename country collaborator_country
rename latlong latlong_collab
drop if collaborator_location_id==""
save collaborator_withlocation.dta,replace

use collaborator_withlocation.dta,clear
drop if inventor_id== collaborator_id
gen lat1 = substr(latlong_inv,1,strpos(latlong_inv,"|")-1)
gen lon1 = substr(latlong_inv,strpos(latlong_inv,"|")+1,.)
gen lat2 = substr(latlong_collab,1,strpos(latlong_collab,"|")-1)
gen lon2 = substr(latlong_collab,strpos(latlong_collab,"|")+1,.)
destring lat1 lon1 lat2 lon2,replace
geodist lat1 lon1 lat2 lon2,g(dist)
drop if dist==.
merge m:1 inventor_id collaborator_id using earliest_collab_year.dta
drop if _merge==2 // all the unmatched are inventor_id==collaborator_id
drop _merge
save collab_dist.dta,replace

use collab_dist.dta,clear  // produce final data
*gen tie_persistence_years = year - earliest_collab_year
*keep if tie_persistence_years >= 5
gen total_ties=1 
replace total_ties = total_ties/(dist + 1)
collapse (sum) total_ties,by(inventor_id year)
save temp6.dta,replace

use N_count_peryear.dta,clear
merge m:1 inventor_id year using temp6.dta
drop _merge
replace total_ties=0 if total_ties==.
gen total_ties_perpat= total / N
save local_ties.dta,replace

}

*(Disruption)
{
*Get real format
use temp_uscitation_withdate.dta,clear
*keep if year_citing < year_cited + 10  // cannot add this
save temp_uscitation_5years.dta,replace

use finalformat.dta,clear
duplicates drop inventor_id,force
keep inventor_id
joinby inventor_id using temp.dta  // the list of all inventors
keep patent_id inventor_id sequence year treated title identifier year_breakthrough location_id city state country latlong
joinby patent_id using temp_uscitation_5years.dta

foreach var in patent_id inventor_id sequence year  location_id city state country latlong{
	rename `var' raw_`var'
}
gen patent_id=citing_id
joinby patent_id using rawinventor_withdate.dta
drop uuid name_first name_last rule_47 deceased year patent_id
rename rawlocation_id id
joinby id using $dir\rawdata\uspto\USPTO_rawdata\rawlocation.dta
format %18s city
drop id
drop if location_id==""
save temp_disruption.dta,replace

use temp_disruption.dta,clear
keep if raw_inventor_id == inventor_id
duplicates drop citing_id,force // remove self-citation
keep citing_id
save self_citing_id.dta,replace

use temp_disruption.dta,clear
merge m:1 citing_id using self_citing_id.dta
keep if _merge==1
drop _merge
gen lat1 = substr(raw_latlong,1,strpos(raw_latlong,"|")-1)
gen lon1 = substr(raw_latlong,strpos(raw_latlong,"|")+1,.)
gen lat2 = substr(latlong,1,strpos(latlong,"|")-1)
gen lon2 = substr(latlong,strpos(latlong,"|")+1,.)
destring lat1 lon1 lat2 lon2,replace
geodist lat1 lon1 lat2 lon2,g(dist)
drop if dist==.
save disruption.dta,replace

*Calculate output1 - (weighted) spillover to local inventors
use disruption.dta,clear
bys raw_inventor_id year_citing inventor_id: gen n=_n
keep if n==1
keep raw_inventor_id year_citing dist
rename raw_i inventor_id
rename year_citing year
gen local_spill=1/(1+dist)
collapse (sum) local_spill,by(inv year)
save local_spill.dta,replace

*Calculate output2 - (counted) spillover to local inventors
use disruption.dta,clear
keep if dist<50
*bys raw_inventor_id year_citing inventor_id: gen n=_n
*keep if n==1
keep raw_inventor_id year_citing dist
rename raw_i inventor_id
rename year_citing year
gen local_spill=1
collapse (sum) local_spill,by(inv year)
save local_spill.dta,replace

}


*(Generality)
{
use finalformat.dta,clear
keep if treated==1
append using finalformat_onlycontrol.dta // controls are duplicated (1:1)

duplicates drop identifier,force
keep identi
gen patent_id = identifier
save temp_focal,replace
use temp_focal,clear

use temp_uscitation_withdate.dta,clear
merge m:1 patent_id using temp_focal
keep if _merge==3
drop _merge
save temp_focal_g2.dta,replace // g2 patents citing the identifier

use temp_focal_g2.dta,clear
keep citing_id identifier
rename citing_id patent_id
bys patent_id identifier: gen n=_n
keep if n==1
drop n
joinby patent_id using temp_uscitation_withdate.dta
save temp_focal_g3,replace // g3 patents citing g2

*compute second order generality
use temp_focal_g3,clear
append using temp_focal_g2.dta
bys identifier citing_id: gen n=_n
keep if n==1
drop n patent_id year*
gen patent_id = citing_id
merge m:1 patent_id using $dir\rawdata\uspto\USPTO_rawdata\nber.dta
keep if _merge==3
drop _merge uuid category_id
save temp_focal_gall.dta,replace

use temp_focal_gall.dta,clear
gen Ni=1
collapse (sum) Ni,by(identifier)
save temp_focal_Ni.dta,replace

use temp_focal_gall.dta,clear
gen Nij=1
collapse (sum) Ni,by(identifier subcategory_id)
merge m:1 identifier using temp_focal_Ni.dta
drop _merge
gen x= (Nij/ Ni)^2
collapse (sum) x,by(identifier)
replace x = 1-x
merge m:1 identifier using temp_focal_Ni.dta
drop _merge
gen generality = x* Ni/(Ni-1)
drop x Ni
save generality.dta,replace
}





*6) Construct control variables
{
*(Obtain total cited times)
use $dir\rawdata\uspto_citation\rawdata\temp\rawdata_for_citedness.dta,clear
keep if appdate_cited<= 2012 & appdate_cited>= 1976
bys patent_id_cited patent_id_citing: gen n=_n // drop duplicated patent-to-patent citations
keep if n==1
drop n

gen cited_times=1 // Cited times by USPTO patents (self-citations not excluded)
collapse (sum) cited_times, by(patent_id_cited) 
rename patent_id_cited patent_id
save total-citedtimes-by-patent.dta,replace

use total-citedtimes-by-patent.dta,clear
joinby patent_id using rawinventor_withdate.dta
bys inventor_id (year): gen cumulative_cited_times = sum(cited_times)
bys inventor_id year (cumulative_cited_times): gen N=_N
bys inventor_id year (cumulative_cited_times): gen n=_n
bys inventor_id (cumulative_cited_times): gen N_patent=_n
keep if n==N
drop n N
gen cited_times_perpat=cumulative_cited_times/N_patent
keep inventor_id year cumulative_cited_times cited_times_perpat N_patent
rename N cumulative_patent_counts
save total-citedtimes-by-inventor.dta,replace

*(Fields)
use rawinventor_withdate.dta,clear
joinby patent_id using $dir\rawdata\uspto\USPTO_rawdata\nber.dta
gen nber_count=1
collapse (sum) nber_count,by(inventor_id year category_id)

bys inventor_id category_id (year): gen nber=sum(nber_count)
bys inventor_id category_id year (nber):gen N=_N
bys inventor_id category_id year (nber):gen n=_n
keep if N==n
drop n N nber_count
rename nber nber_count
save inventor_nber_count.dta,replace  //cumulative sum of nber fields by inventor

local i=0
foreach nber in chemical computer_comm drug_medical electri_electron mechanical others{
	local i = `i' +1
	use inventor_nber_count.dta,clear
	keep if category_id ==`i'
	rename nber_count nber_`nber'
	replace nber_`nber'=1
	drop category_id
	save inventor_nber_count_sector`i'.dta,replace
}

*(Experience)
use rawinventor_withdate.dta,clear
bys inventor_id (year): egen min_year=min(year)
gen experience = year - min_year
bys inventor_id year: gen n=_n
keep if n==1
keep inventor_id year experience
save experience.dta,replace

*(Learning capacity: speed to source new knowledge)
use temp_uscitation_withdate.dta,clear
gen time_taken = year_citing - year_cited
drop if year_citing <1976 | year_citing>2012
rename patent_id patent_id_cited
rename citing_id patent_id
collapse (mean) time_taken,by(patent_id)
save speed-to-assimilate-bypatent.dta,replace

use rawinventor_withdate.dta,clear
drop if year <1976 | year>2012
joinby patent_id using speed-to-assimilate-bypatent.dta
collapse (mean) time_taken,by(inventor_id year)
save speed-to-assimilate.dta,replace


*(City inventors)
use rawinventor_withdate.dta,clear
drop uuid
joinby patent_id using $dir\rawdata\uspto\USPTO_rawdata\nber.dta
keep patent_id inventor_id rawlocation_id year category_id
rename rawlocation_id id
joinby id using $dir\rawdata\uspto\USPTO_rawdata\rawlocation.dta
drop if location_id==""
format %18s inventor_id city
rename id rawlocation_id
bys inventor_id location_id category_id year: gen n=_n
keep if n==1
drop n
gen reg_inventor_count=1
collapse (sum) reg_inventor_count,by(location_id year category_id)
save region_inventor_count.dta,replace

local i=0
foreach nber in chemical computer_comm drug_medical electri_electron mechanical others{
	local i = `i' +1
	use region_inventor_count.dta,clear
	keep if category_id ==`i'
	rename reg_inventor_count reg_inventor_`nber'
	drop category_id
	save region_inventor_count_sector`i'.dta,replace
}

*(Sum of collaborators by year)
use rawinventor_withdate.dta,clear
keep patent_id inventor_id
rename inventor_id i
joinby patent_id using rawinventor_withdate.dta
rename inventor_id collaborator_id
rename i inventor_id
drop if inventor_id == collaborator_id

bys inventor_id collaborator_id year:gen n=_n // drop duplicated collaborators
keep if n==1
drop n

gen collaborator_count=1
collapse (sum) collaborator_count,by(year inventor_id)
drop if year<1976 | year >2012
save collaborator_count.dta,replace

}




*6) DID
**DID
{
*(lead and lag)
*Get real format
use finalformat.dta,clear
keep if treated==1
merge m:1 inventor_id year using psm_matched_treated_id.dta
keep if _merge==3
drop _merge
append using finalformat_onlycontrol.dta

drop if year<1986

*remove missing obs
merge m:1 inventor_id year using tie_persistence_years.dta
keep if _merge==3
drop _merge

bys inventor_id: egen min_year=min(year) if treated==1
bys inventor_id: egen max_year=max(year) if treated==1
drop if (min_year>=year_breakthrough | max_year<=year_breakthrough) &  treated==1
drop min max
save US_dynamic,replace

	*keep only matched pairs
	{   
	use US_dynamic,clear
	keep if treated==0
	bys inventor_id year: gen n=_n
	keep if n==1
	keep inventor_id year
	rename inventor_id inventor_id_control // control with data
	save withdata_control,replace

	use US_dynamic,clear
	keep if treated==1
	bys inventor_id year: gen n=_n
	keep if n==1
	keep inventor_id year identifier year_breakthrough citing_year
	rename inventor_id inventor_id_treated // treated with data

	merge m:1 inventor_id_treated year using psm_matched.dta
	keep if _merge==3
	drop _merge
	merge m:1 inventor_id_control year using withdata_control
	keep if _merge==3
	drop _merge
	save withdata_matched,replace

	use withdata_matched,clear
	/*
	bys inventor_id_control year:gen n=_n
	keep if n==1
	*/
	keep inventor_id_control year identifier citing_year year_breakthrough
	rename inventor_id inventor_id
	save withdata_control,replace
	use withdata_matched,clear
	keep inventor_id_treated year identifier citing_year year_breakthrough
	rename inventor_id inventor_id
	append using withdata_control
	save withdata,replace // inventor_id year with data (duplicated control, 1:1)
	use withdata,clear

	use US_dynamic,clear
	drop identifier citing_year year_breakthrough
	bys inventor_id year:gen n=_n
	keep if n==1
	drop n
	joinby inventor_id year using withdata
	}

gen Dit=1 if treated==1 & year>= year_breakthrough
replace Dit=0 if Dit==.

gen years_post=year-year_breakthrough
replace years_post =10 if years_post >10
replace years_post =-6 if years_post <-6


//首先生成年份虚拟变量与实验组虚拟变量的交互项
forvalues i = 6 (-1) 1{
  gen pre_`i' = (years_post == -`i' & treated == 1) 
}

gen current = (years_post == 0 & treated == 1)

forvalues j = 1(1)10{
  gen  post_`j' = (years_post == `j' & treated == 1)
}

drop pre_1 //将政策前第一期作为基准组，很重要！！！

egen group = group(identifier)
areg tie_persistence_years pre_* current  post_* ///
$X i.year, absorb( inventor_id ) r

*(Plot parallel trend)
coefplot, baselevels ///
keep(pre_* current post_*) ///
vertical ///转置图形
yline(0,lcolor(edkblue*0.8)) ///加入y=0这条虚线 
xline(6, lwidth(vthin) lpattern(dash) lcolor(teal)) ///
ylabel(,labsize(*0.75)) xlabel(,labsize(*0.75)) ///
ytitle("Estimated coefficient + 95% confidence interval", size(small)) ///加入Y轴标题,大小small
xtitle("Years after technological breakthrough", size(small)) ///加入X轴标题，大小small 
addplot(line @b @at) ///增加点之间的连线
ciopts(lpattern(dash) recast(rcap) msize(medium)) ///CI为虚线上下封口
msymbol(circle_hollow) ///plot空心格式
scheme(s1mono)  xlabel(1 "-6" 2"-5" 3"-4" 4"-3" 5"-2" 6"0" 7"1" 8"2" 9"3" 10"4" 11"5" 12"6" 13"7" 14"8" 15"9" 16"10")


*(Baseline)
areg tie_persistence_years Dit i.year, absorb( inventor_id ) r
est sto reg1
areg tie_persistence_years Dit $X i.year, absorb( inventor_id ) r
est sto reg2
areg tie_persistence_years pre_* current  post_* ///
$X i.year, absorb( inventor_id ) r
est sto reg3
}


**Placebo test
local var tie_persistence_years
{
drop if year >= year_breakthrough
replace year_breakthrough = year_breakthrough -5
drop years_post - post_10 Dit

bys inventor_id: egen min_year=min(year) if treated==1
bys inventor_id: egen max_year=max(year) if treated==1
drop if (min_year>=year_breakthrough | max_year<=year_breakthrough) &  treated==1
drop min max
save US_dynamic,replace

	*keep only matched pairs
	{   
	use US_dynamic,clear
	keep if treated==0
	bys inventor_id year: gen n=_n
	keep if n==1
	keep inventor_id year
	rename inventor_id inventor_id_control // control with data
	save withdata_control,replace

	use US_dynamic,clear
	keep if treated==1
	bys inventor_id year: gen n=_n
	keep if n==1
	keep inventor_id year identifier year_breakthrough citing_year
	rename inventor_id inventor_id_treated // treated with data

	merge m:1 inventor_id_treated year using psm_matched.dta
	keep if _merge==3
	drop _merge
	merge m:1 inventor_id_control year using withdata_control
	keep if _merge==3
	drop _merge
	save withdata_matched,replace

	use withdata_matched,clear
	/*
	bys inventor_id_control year:gen n=_n
	keep if n==1
	*/
	keep inventor_id_control year identifier citing_year year_breakthrough
	rename inventor_id inventor_id
	save withdata_control,replace
	use withdata_matched,clear
	keep inventor_id_treated year identifier citing_year year_breakthrough
	rename inventor_id inventor_id
	append using withdata_control
	save withdata,replace // inventor_id year with data (duplicated control, 1:1)
	use withdata,clear

	use US_dynamic,clear
	drop identifier citing_year year_breakthrough
	bys inventor_id year:gen n=_n
	keep if n==1
	drop n
	joinby inventor_id year using withdata
	}

gen Dit=1 if treated==1 & year>= year_breakthrough
replace Dit=0 if Dit==.

gen years_post=year-year_breakthrough
replace years_post =10 if years_post >10
replace years_post =-6 if years_post <-6


//首先生成年份虚拟变量与实验组虚拟变量的交互项
forvalues i = 6 (-1) 1{
  gen pre_`i' = (years_post == -`i' & treated == 1) 
}

gen current = (years_post == 0 & treated == 1)

forvalues j = 1(1)10{
  gen  post_`j' = (years_post == `j' & treated == 1)
}

drop pre_1 //将政策前第一期作为基准组，很重要！！！

areg `var' pre_* current  post_* ///
$X i.year, absorb( inventor_id ) r

*(Plot parallel trend)
coefplot, baselevels ///
keep(pre_* current post_*) ///
vertical ///转置图形
yline(0,lcolor(edkblue*0.8)) ///加入y=0这条虚线 
xline(6, lwidth(vthin) lpattern(dash) lcolor(teal)) ///
ylabel(,labsize(*0.75)) xlabel(,labsize(*0.75)) ///
ytitle("Estimated coefficient + 95% confidence interval", size(small)) ///加入Y轴标题,大小small
xtitle("Years after technological breakthrough", size(small)) ///加入X轴标题，大小small 
addplot(line @b @at) ///增加点之间的连线
ciopts(lpattern(dash) recast(rcap) msize(medium)) ///CI为虚线上下封口
msymbol(circle_hollow) ///plot空心格式
scheme(s1mono)  xlabel(1 "-6" 2"-5" 3"-4" 4"-3" 5"-2" 6"0" 7"1" 8"2" 9"3" 10"4")




*(Baseline)
areg `var' Dit $X i.year, absorb( inventor_id ) r
}


**DID For new ties: collaboration counts with new collaborators
{
*(lead and lag)
*Get real format
use finalformat.dta,clear
keep if treated==1
merge m:1 inventor_id year using psm_matched_treated_id.dta
keep if _merge==3
drop _merge
append using finalformat_onlycontrol.dta

drop if year<1986

*remove missing obs
/*
merge m:1 inventor_id year using tie_persistence_years.dta
keep if _merge==3
drop _merge
*/
merge m:1 inventor_id year using new_collab_times.dta
drop if _merge==2
replace new_collab_times = 0 if new_collab_times==.
drop _merge

bys inventor_id: egen min_year=min(year) if treated==1
bys inventor_id: egen max_year=max(year) if treated==1
drop if (min_year>=year_breakthrough | max_year<=year_breakthrough) &  treated==1
drop min max
save US_dynamic,replace

	*keep only matched pairs
	{   
	use US_dynamic,clear
	keep if treated==0
	bys inventor_id year: gen n=_n
	keep if n==1
	keep inventor_id year
	rename inventor_id inventor_id_control // control with data
	save withdata_control,replace

	use US_dynamic,clear
	keep if treated==1
	bys inventor_id year: gen n=_n
	keep if n==1
	keep inventor_id year identifier year_breakthrough citing_year
	rename inventor_id inventor_id_treated // treated with data

	merge m:1 inventor_id_treated year using psm_matched.dta
	keep if _merge==3
	drop _merge
	merge m:1 inventor_id_control year using withdata_control
	keep if _merge==3
	drop _merge
	save withdata_matched,replace

	use withdata_matched,clear
	/*
	bys inventor_id_control year:gen n=_n
	keep if n==1
	*/
	keep inventor_id_control year identifier citing_year year_breakthrough
	rename inventor_id inventor_id
	save withdata_control,replace
	use withdata_matched,clear
	keep inventor_id_treated year identifier citing_year year_breakthrough
	rename inventor_id inventor_id
	append using withdata_control
	save withdata,replace // inventor_id year with data (duplicated control, 1:1)
	use withdata,clear

	use US_dynamic,clear
	drop identifier citing_year year_breakthrough
	bys inventor_id year:gen n=_n
	keep if n==1
	drop n
	joinby inventor_id year using withdata
	}

gen Dit=1 if treated==1 & year>= year_breakthrough
replace Dit=0 if Dit==.

gen years_post=year-year_breakthrough
replace years_post =10 if years_post >10
replace years_post =-6 if years_post <-6


//首先生成年份虚拟变量与实验组虚拟变量的交互项
forvalues i = 6 (-1) 1{
  gen pre_`i' = (years_post == -`i' & treated == 1) 
}

gen current = (years_post == 0 & treated == 1)

forvalues j = 1(1)10{
  gen  post_`j' = (years_post == `j' & treated == 1)
}

drop pre_1 //将政策前第一期作为基准组，很重要！！！

egen group = group(identifier)
areg new_collab_times_perpat pre_* current  post_* ///
$X i.year, absorb( inventor_id ) r

*(Plot parallel trend)
coefplot, baselevels ///
keep(pre_* current post_*) ///
vertical ///转置图形
yline(0,lcolor(edkblue*0.8)) ///加入y=0这条虚线 
xline(6, lwidth(vthin) lpattern(dash) lcolor(teal)) ///
ylabel(,labsize(*0.75)) xlabel(,labsize(*0.75)) ///
ytitle("Estimated coefficient + 95% confidence interval", size(small)) ///加入Y轴标题,大小small
xtitle("Years after technological breakthrough", size(small)) ///加入X轴标题，大小small 
addplot(line @b @at) ///增加点之间的连线
ciopts(lpattern(dash) recast(rcap) msize(medium)) ///CI为虚线上下封口
msymbol(circle_hollow) ///plot空心格式
scheme(s1mono)  xlabel(1 "-6" 2"-5" 3"-4" 4"-3" 5"-2" 6"0" 7"1" 8"2" 9"3" 10"4" 11"5" 12"6" 13"7" 14"8" 15"9" 16"10")



*(Baseline)
areg new_collab_times_perpat Dit i.year , absorb( inventor_id ) r
est sto reg1
areg new_collab_times_perpat Dit $X i.year, absorb( inventor_id ) r
est sto reg2
areg new_collab_times_perpat pre_* current  post_* ///
$X i.year, absorb( inventor_id ) r
est sto reg3
}


**DID For old ties collaboration counts with old collaborators
{
*(lead and lag)
*Get real format
use finalformat.dta,clear
keep if treated==1
merge m:1 inventor_id year using psm_matched_treated_id.dta
keep if _merge==3
drop _merge
append using finalformat_onlycontrol.dta

drop if year<1986

*remove missing obs
/*
merge m:1 inventor_id year using tie_persistence_years.dta
keep if _merge==3
drop _merge
*/
merge m:1 inventor_id year using old_collab_times.dta
drop if _merge==2
replace old_collab_times = 0 if old_collab_times==.
drop _merge

bys inventor_id: egen min_year=min(year) if treated==1
bys inventor_id: egen max_year=max(year) if treated==1
drop if (min_year>=year_breakthrough | max_year<=year_breakthrough) &  treated==1
drop min max
save US_dynamic,replace

	*keep only matched pairs
	{   
	use US_dynamic,clear
	keep if treated==0
	bys inventor_id year: gen n=_n
	keep if n==1
	keep inventor_id year
	rename inventor_id inventor_id_control // control with data
	save withdata_control,replace

	use US_dynamic,clear
	keep if treated==1
	bys inventor_id year: gen n=_n
	keep if n==1
	keep inventor_id year identifier year_breakthrough citing_year
	rename inventor_id inventor_id_treated // treated with data

	merge m:1 inventor_id_treated year using psm_matched.dta
	keep if _merge==3
	drop _merge
	merge m:1 inventor_id_control year using withdata_control
	keep if _merge==3
	drop _merge
	save withdata_matched,replace

	use withdata_matched,clear
	/*
	bys inventor_id_control year:gen n=_n
	keep if n==1
	*/
	keep inventor_id_control year identifier citing_year year_breakthrough
	rename inventor_id inventor_id
	save withdata_control,replace
	use withdata_matched,clear
	keep inventor_id_treated year identifier citing_year year_breakthrough
	rename inventor_id inventor_id
	append using withdata_control
	save withdata,replace // inventor_id year with data (duplicated control, 1:1)
	use withdata,clear

	use US_dynamic,clear
	drop identifier citing_year year_breakthrough
	bys inventor_id year:gen n=_n
	keep if n==1
	drop n
	joinby inventor_id year using withdata
	}

gen Dit=1 if treated==1 & year>= year_breakthrough
replace Dit=0 if Dit==.

gen years_post=year-year_breakthrough
replace years_post =10 if years_post >10
replace years_post =-6 if years_post <-6


//首先生成年份虚拟变量与实验组虚拟变量的交互项
forvalues i = 6 (-1) 1{
  gen pre_`i' = (years_post == -`i' & treated == 1) 
}

gen current = (years_post == 0 & treated == 1)

forvalues j = 1(1)10{
  gen  post_`j' = (years_post == `j' & treated == 1)
}

drop pre_1 //将政策前第一期作为基准组，很重要！！！

egen group=group(identifier)
areg old_collab_times_perpat pre_* current  post_* ///
$X i.year , absorb( inventor_id ) r

*(Plot parallel trend)
coefplot, baselevels ///
keep(pre_* current post_*) ///
vertical ///转置图形
yline(0,lcolor(edkblue*0.8)) ///加入y=0这条虚线 
xline(6, lwidth(vthin) lpattern(dash) lcolor(teal)) ///
ylabel(,labsize(*0.75)) xlabel(,labsize(*0.75)) ///
ytitle("Estimated coefficient + 95% confidence interval", size(small)) ///加入Y轴标题,大小small
xtitle("Years after technological breakthrough", size(small)) ///加入X轴标题，大小small 
addplot(line @b @at) ///增加点之间的连线
ciopts(lpattern(dash) recast(rcap) msize(medium)) ///CI为虚线上下封口
msymbol(circle_hollow) ///plot空心格式
scheme(s1mono)  xlabel(1 "-6" 2"-5" 3"-4" 4"-3" 5"-2" 6"0" 7"1" 8"2" 9"3" 10"4" 11"5" 12"6" 13"7" 14"8" 15"9" 16"10")



*(Baseline)
areg old_collab_times_perpat Dit i.year , absorb( inventor_id ) r
est sto reg1
areg old_collab_times_perpat Dit $X i.year, absorb( inventor_id ) r
est sto reg2
areg old_collab_times_perpat pre_* current  post_* ///
$X i.year, absorb( inventor_id ) r
est sto reg3
}





**DID For disuption
{
*(lead and lag)
*Get real format
use finalformat.dta,clear
keep if treated==1
merge m:1 inventor_id year using psm_matched_treated_id.dta
keep if _merge==3
drop _merge
append using finalformat_onlycontrol.dta

drop if year<1986

*remove missing obs
merge m:1 inventor_id year using local_spill.dta
drop if _merge==2
drop _merge
replace local_ = 0 if local_ == .
replace local_ = local_ / cumulative_patent_counts 

bys inventor_id: egen min_year=min(year) if treated==1
bys inventor_id: egen max_year=max(year) if treated==1
drop if (min_year>=year_breakthrough | max_year<=year_breakthrough) &  treated==1
drop min max
save US_dynamic,replace

	*keep only matched pairs
	{   
	use US_dynamic,clear
	keep if treated==0
	bys inventor_id year: gen n=_n
	keep if n==1
	keep inventor_id year
	rename inventor_id inventor_id_control // control with data
	save withdata_control,replace

	use US_dynamic,clear
	keep if treated==1
	bys inventor_id year: gen n=_n
	keep if n==1
	keep inventor_id year identifier year_breakthrough citing_year
	rename inventor_id inventor_id_treated // treated with data

	merge m:1 inventor_id_treated year using psm_matched.dta
	keep if _merge==3
	drop _merge
	merge m:1 inventor_id_control year using withdata_control
	save temp_temp.dta,replace
	use temp_temp.dta,clear
	keep if _merge==3
	drop _merge
	save withdata_matched,replace

	use withdata_matched,clear
	/*
	bys inventor_id_control year:gen n=_n
	keep if n==1
	*/
	keep inventor_id_control year identifier citing_year year_breakthrough
	rename inventor_id inventor_id
	save withdata_control,replace
	use withdata_matched,clear
	keep inventor_id_treated year identifier citing_year year_breakthrough
	rename inventor_id inventor_id
	append using withdata_control
	save withdata,replace // inventor_id year with data (duplicated control, 1:1)
	use withdata,clear

	use US_dynamic,clear
	drop identifier citing_year year_breakthrough
	bys inventor_id year:gen n=_n
	keep if n==1
	drop n
	joinby inventor_id year using withdata
	}

gen Dit=1 if treated==1 & year>= year_breakthrough
replace Dit=0 if Dit==.

gen years_post=year-year_breakthrough
replace years_post =10 if years_post >10
replace years_post =-7 if years_post <-7


//首先生成年份虚拟变量与实验组虚拟变量的交互项
forvalues i = 7 (-1) 1{
  gen pre_`i' = (years_post == -`i' & treated == 1) 
}

gen current = (years_post == 0 & treated == 1)

forvalues j = 1(1)10{
  gen  post_`j' = (years_post == `j' & treated == 1)
}

drop pre_1 //将政策前第一期作为基准组，很重要！！！

egen group = group(identifier)
areg local_spill pre_* current  post_*  ///
i.group $X i.year, absorb( inventor_id ) r

*(Plot parallel trend)
coefplot, baselevels ///
keep(pre_* current post_*) ///
vertical ///转置图形
yline(0,lcolor(edkblue*0.8)) ///加入y=0这条虚线 
xline(7, lwidth(vthin) lpattern(dash) lcolor(teal)) ///
ylabel(,labsize(*0.75)) xlabel(,labsize(*0.75)) ///
ytitle("Treatment effect", size(small)) ///加入Y轴标题,大小small
xtitle("Years after treatment", size(small)) ///加入X轴标题，大小small 
addplot(line @b @at) ///增加点之间的连线
ciopts(lpattern(dash) recast(rcap) msize(medium)) ///CI为虚线上下封口
msymbol(circle_hollow) ///plot空心格式
scheme(s1mono)


*(Baseline)
areg local_spill Dit  $X i.group i.year, absorb( inventor_id ) r
}






**DID For ..... ties
{
*(lead and lag)
*Get real format
use finalformat.dta,clear
keep if treated==1
merge m:1 inventor_id year using psm_matched_treated_id.dta
keep if _merge==3
drop _merge
append using finalformat_onlycontrol.dta

drop if year<1986

*remove missing obs
merge m:1 inventor_id year using local_ties.dta
drop if _merge==2
drop _merge

bys inventor_id: egen min_year=min(year) if treated==1
bys inventor_id: egen max_year=max(year) if treated==1
drop if (min_year>=year_breakthrough | max_year<=year_breakthrough) &  treated==1
drop min max
save US_dynamic,replace

	*keep only matched pairs
	{   
	use US_dynamic,clear
	keep if treated==0
	bys inventor_id year: gen n=_n
	keep if n==1
	keep inventor_id year
	rename inventor_id inventor_id_control // control with data
	save withdata_control,replace

	use US_dynamic,clear
	keep if treated==1
	bys inventor_id year: gen n=_n
	keep if n==1
	keep inventor_id year identifier year_breakthrough citing_year
	rename inventor_id inventor_id_treated // treated with data

	merge m:1 inventor_id_treated year using psm_matched.dta
	keep if _merge==3
	drop _merge
	merge m:1 inventor_id_control year using withdata_control
	save temp_temp.dta,replace
	use temp_temp.dta,clear
	keep if _merge==3
	drop _merge
	save withdata_matched,replace

	use withdata_matched,clear
	/*
	bys inventor_id_control year:gen n=_n
	keep if n==1
	*/
	keep inventor_id_control year identifier citing_year year_breakthrough
	rename inventor_id inventor_id
	save withdata_control,replace
	use withdata_matched,clear
	keep inventor_id_treated year identifier citing_year year_breakthrough
	rename inventor_id inventor_id
	append using withdata_control
	save withdata,replace // inventor_id year with data (duplicated control, 1:1)
	use withdata,clear

	use US_dynamic,clear
	drop identifier citing_year year_breakthrough
	bys inventor_id year:gen n=_n
	keep if n==1
	drop n
	joinby inventor_id year using withdata
	}

gen Dit=1 if treated==1 & year>= year_breakthrough
replace Dit=0 if Dit==.

gen years_post=year-year_breakthrough
replace years_post =10 if years_post >10
replace years_post =-7 if years_post <-7


//首先生成年份虚拟变量与实验组虚拟变量的交互项
forvalues i = 7 (-1) 1{
  gen pre_`i' = (years_post == -`i' & treated == 1) 
}

gen current = (years_post == 0 & treated == 1)

forvalues j = 1(1)10{
  gen  post_`j' = (years_post == `j' & treated == 1)
}

drop pre_1 //将政策前第一期作为基准组，很重要！！！

egen group = group(identifier)
areg total_ties_perpat pre_* current  post_*  ///
i.group $X i.year, absorb( inventor_id )

*(Plot parallel trend)
coefplot, baselevels ///
keep(pre_* current post_*) ///
vertical ///转置图形
yline(0,lcolor(edkblue*0.8)) ///加入y=0这条虚线 
xline(7, lwidth(vthin) lpattern(dash) lcolor(teal)) ///
ylabel(,labsize(*0.75)) xlabel(,labsize(*0.75)) ///
ytitle("Treatment effect", size(small)) ///加入Y轴标题,大小small
xtitle("Years after treatment", size(small)) ///加入X轴标题，大小small 
addplot(line @b @at) ///增加点之间的连线
ciopts(lpattern(dash) recast(rcap) msize(medium)) ///CI为虚线上下封口
msymbol(circle_hollow) ///plot空心格式
scheme(s1mono)


*(Baseline)
areg total_ties_perpat Dit  $X i.group i.year, absorb( inventor_id ) r
}





logout,save(Model2) excel replace fix(3): ///
esttab reg1 reg2 reg3,b(%6.3f) nogap compress star(* 0.1 ** 0.05 *** 0.01)  ///
ar2 se scalar(N) nocon indicate("Time FE=*.year")
