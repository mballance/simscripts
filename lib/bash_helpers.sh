#****************************************************************************
#* bash_helpers.sh
#****************************************************************************

_runtest_pl_completion ()
{
  local cur
  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}

#  echo "COMP_WORDS=${COMP_WORDS[*]} COMP_LINE=$COMP_LINE cur=$cur" >> complete.txt

  case $cur in
    -*)
      COMPREPLY=( $( compgen -W '-test -count -max_par -j -rundir -clean -nobuild -i -quiet -sim -testlist -tl' -- $cur ) );;
  esac

  return 0
}

complete -F _runtest_pl_completion -o filenames $SIMSCRIPTS_DIR/bin/runtest.pl
complete -F _runtest_pl_completion -o filenames runtest.pl

