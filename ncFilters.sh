# These derived from examples found here: http://nco.sourceforge.net/nco.html#filters
# NB: Untested on Csh, Ksh, Sh, Zsh! Send us feedback!
# Bash shell (/bin/bash) users place these in .bashrc

# ncattget $att_nm $var_nm $fl_nm : What attributes does variable have?
function ncattget { ncks -M -m ${3} | grep -E -i "^${2} attribute [0-9]+: ${1}" | cut -f 11- -d ' ' | sort ; }

# ncunits $att_val $fl_nm : Which variables have given units?
function ncunits { ncks -M -m ${2} | grep -E -i " attribute [0-9]+: units.+ ${1}" | cut -f 1 -d ' ' | sort ; }

# ncavg $var_nm $fl_nm : What is mean of variable?
function ncavg { ncwa -y avg -O -C -v ${1} ${2} ~/foo.nc ; ncks -H -C -v ${1} ~/foo.nc | cut -f 3- -d ' ' ; }

# ncavg $var_nm $fl_nm : What is mean of variable?
function ncavg { ncap2 -O -C -v -s "foo=${1}.avg();print(foo)" ${2} ~/foo.nc | cut -f 3- -d ' ' ; }

# ncdmnsz $dmn_nm $fl_nm : What is dimension size?
function ncdmnsz { ncks -m -M ${2} | grep -E -i ": ${1}, size =" | cut -f 7 -d ' ' | uniq ; }

# ncVarlist $fl_nm : What variables are in file?
function ncVarList { ncks -m ${1} | grep -E ': type' | cut -f 1 -d ' ' | sed 's/://' | sort ; }

# mvVarType
function ncVarType { 
    functionId funcId
    if [ -z "$2" ] ## only one arg in
    then
	for var in `ncVarList ${1}`
	do 
	    ncVarType $var ${1}
	done 
    else
	local dumFile=/tmp/ncDum${USER}${funcId}.nc
	type=`ncap2 -O -C -v -s "foo=${1}.type();print(foo)" ${2} $dumFile | cut -f 3- -d ' '`
	\rm -f $dumFile
	echo ${1} : Type=$type
    fi
}


# ncVarMax $var_nm $fl_nm : What is maximum of variable?
# if only 1 variable (filename) then print the info for all variables in the file.
# if varname is specified, then print for only that variable
function ncVarMax { 
    functionId funcId
    local dumFile=/tmp/ncDum${USER}${funcId}.nc
    if [ -z "$2" ] ## only one arg in
    then
	for var in `ncVarList ${1}`
	do 
	    ncVarMax $var ${1}
	done 
    else
	max=`ncap2 -O -C -v -s "foo=${1}.max();print(foo)" ${2} $dumFile | cut -f 3- -d ' '`
	\rm -f $dumFile
	echo ${1} : Max=$max
    fi
}

# ncmdn $var_nm $fl_nm : What is median of variable?
function ncmdn { ncap2 -O -C -v -s "foo=gsl_stats_median_from_sorted_data(${1}.sort());print(foo)" ${2} ~/foo.nc | cut -f 3- -d ' ' ; }

# ncrng $var_nm $fl_nm : What is range of variable?
function ncVarRng { 
    functionId funcId
    local dumFile=/tmp/ncDum${USER}${funcId}.nc
    if [ -z "$2" ] ## only one arg in
    then
	for var in `ncVarList ${1}`
	do 
	    ncVarRng $var ${1}
	done 
    else

	type=`ncVarType $1 $2 | cut -f 2- -d '='`
	if [[ $type == 3 ]] 
	then 
	    rng=`ncap2 -O -C -v -s "foo_min=${1}.min();foo_max=${1}.max();print(foo_min,\"( %i\");print(\" , \");print(foo_max,\"%i )\")" ${2} $dumFile`
	else 
	    rng=`ncap2 -O -C -v -s "foo_min=${1}.min();foo_max=${1}.max();print(foo_min,\"( %f\");print(\" , \");print(foo_max,\"%f )\")" ${2} $dumFile`
	fi 

	if [[ $zeroDiffs == 0 ]]
	then 
	    nonZeros=`echo $rng | sed 's/[^1-9]//g'`
	    if [ -e $nonZeros ]; then 
		\rm -f $dumFile
		return 0
	    fi
	fi
	outputId='Range' ## basic identifier
	callFunc=${FUNCNAME[-1]}  ##modify the identitier based on calling routine name
	if [[ $callFunc == 'ncVarDiff' ]]; then outputId=`echo DIFF $outputId`; fi 
	echo ${1} : $outputId=$rng
	\rm -f $dumFile
    fi
    return 0
}

## var or no var specified. 
## ncVarDiff [var] file1 file2
## var can be a comma separated list of variables!
## e.g.
##jamesmcc@hydro-c1:~/DART/lanai/models/wrfHydro/work> ncVarDiff LAI,WT,WOOD RESTART.2013091200_DOMAIN3.orig restart.nc 
function ncVarDiff {

    OPTIND=1
    local zeroDiffs=0
    while getopts ":z" opt; do
	case $opt in
	    z) zeroDiffs=1
	       ;;
	    \?)
		echo "Invalid option: -$OPTARG" >&2
		;;
	esac
    done
    
    shift $((OPTIND-1))
    [ "$1" = "--" ] && shift

    functionId funcId
    local dumFile=/tmp/ncDum${USER}${funcId}.nc
    if [ -z "$3" ] ## only two args in
    then
	if ! checkFiles $1 $2; then return 1; fi
	ncdiff ${1} ${2} ${dumFile}
    else 
	if ! checkFiles $2 $3; then return 1; fi
	ncdiff -v ${1} ${2} ${3} $dumFile
    fi 
    ncVarRng $dumFile
    \rm -f $dumFile
    return 0
}


# ncmode $var_nm $fl_nm : What is mode of variable?
function ncmode { ncap2 -O -C -v -s "foo=gsl_stats_median_from_sorted_data(${1}.sort());print(foo)" ${2} ~/foo.nc | cut -f 3- -d ' ' ; }

# ncrecsz $fl_nm : What is record dimension size?
function ncrecsz { ncks -M ${1} | grep -E -i "^Record dimension:" | cut -f 8- -d ' ' ; }

## get a function id for managin file creation/removal
function functionId {
    eval "$1=${BASHPID}${FUNCNAME[1]}"
}
    
## check file eixistence b/c resulting error messages can be extremely confusing.
function checkFiles {
    for file in "$@"
    do
	if [ ! -e $file ]
	then
	    echo "File does NOT exist: $file"
	    return 1
	fi 
    done
    return 0
}
