#****************************************************************************
#* simscripts set_env.sh
#****************************************************************************

# set -x

rootdir=`pwd`

while test "x$rootdir" != "x"; do
  runtest=`find $rootdir -maxdepth 4 -name runtest.pl` 
  if test "x$runtest" != "x"; then
    break;
  fi
  rootdir=`dirname $rootdir`
done


if test "x$runtest" = "x"; then
  echo "Error: Failed to find root directory"
else

 # Found multiple runtest.pl scripts. Take the shortest one
  n_runtest=`echo $runtest | wc -w`
  if test $n_runtest -gt 1; then
    echo "Note: found multiple runtest.pl scripts: $runtest"
    pl_min=1000000000
    for rt in $runtest; do
    	pl=`echo $rt | wc -c`
    	if test $pl -lt $pl_min; then
    		pl_min=$pl
    		real_rt=$rt
    	fi
    done
    runtest=$real_rt
  fi
   
  if test "x$runtest" = "x"; then
    echo "Error: Failed to disambiguate runtest.pl"
  else
    SIMSCRIPTS_DIR=`dirname $runtest`
    export SIMSCRIPTS_DIR=`dirname $SIMSCRIPTS_DIR`
    echo "SIMSCRIPTS_DIR=$SIMSCRIPTS_DIR"
    # TODO: check whether the PATH already contains the in directory
    PATH=${SIMSCRIPTS_DIR}/bin:$PATH

    is_bash=`echo $SHELL | sed -e's%^.*\(bash\).*$%\1%g'`
    if test "x$is_bash" = "xbash"; then
      . $SIMSCRIPTS_DIR/lib/bash_helpers.sh
    fi


    # Environment-specific variables
	export SIMSCRIPTS_PROJECT_ENV=true
    if test -f $SIMSCRIPTS_DIR/../env/env.sh; then
    	echo "Note: sourcing environment-specific env.sh"
        . $SIMSCRIPTS_DIR/../env/env.sh
    fi
    unset SIMSCRIPTS_PROJECT_ENV
  fi
fi




