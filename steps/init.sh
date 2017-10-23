#!/bin/bash

# Parse settings_file ($1) into a bunch of $variables.
# Define some utility functions.

scriptname=$(basename "$0")

nparallel=$(nproc | sed "s/$/-1/" | bc)	# One fewer than the number of CPU cores.

# Read the settings file.
[ $# -eq 1 ] || { echo "Usage: $scriptname settings_file"; exit 1; }
[ -f $1 ] || { echo "$scriptname: missing settings file '$1'." && exit 1; }
. $1

export EXPLOCAL=$EXP/$LANG_NAME

# Data splits.
trainids=$EXPLOCAL/lists/train			# Made by stage 3, read by 11.
adaptids=$EXPLOCAL/lists/adapt			# Internal to stage 3, to create $splitadaptids.
testids=$EXPLOCAL/lists/$TESTTYPE		# Made by stage 3, read by 15.

# Intermediate files.
transcripts=$EXPLOCAL/transcripts.txt		# Made by stage 1,  modified by 2.
simfile=$EXPLOCAL/simscores.txt			# Made by stage 2,  read by 4.
mergedir=$EXPLOCAL/mergedir			# Made by stage 4,  read by 11.
aligndist=$EXPLOCAL/aligndists.txt		# Internal to stage 4, via $aligneropt.
mergefstdir=$EXPLOCAL/mergefstdir		# Made by stage 5 and 14 (the files in that dir), read by 7 and 14.
splittrainids=$EXPLOCAL/lists/trainids		# Made by stage 3,  read by 5.
splitadaptids=$EXPLOCAL/lists/adaptids		# Made by stage 3,  read by 5 and 14.
splittestids=$EXPLOCAL/lists/testids		# Made by stage 3,  read by 5, 14 and 15.
initcarmel=$EXPLOCAL/carmel/$Pstyle		# Made by stage 6,  read by 8. ($initcarmel.trained is made by 8, read by 9.)
carmeltraintxt=$EXPLOCAL/carmel/training.txt	# Made by stage 7,  read by 8.
Pfst=$EXPLOCAL/P.fst				# Made by stage 9,  read by 13.
Gfst=$EXPLOCAL/$LANG_NAME.G.fst			# Made by stage 10, read by 13.
Lfst=$EXPLOCAL/L.fst				# Made by stage 11, read by 13.
Tfst=$EXPLOCAL/T.fst				# Made by stage 12, read by 13.
TPLfst=$EXPLOCAL/TPL.fst			# Made by stage 13, read by 14.
GTPLfst=$EXPLOCAL/GTPL.fst			# Made by stage 13, read by 14.
decodelatdir=$EXPLOCAL/decode			# Made by stage 14, read by 15.
hypfile=$EXPLOCAL/hypotheses.txt		# Made by stage 15, read by human.
evaloutput=$EXPLOCAL/eval.txt			# Made by stage 15, read by human.

# Reread the settings file, for any definitions therein that use variables set in the previous few dozen lines,
# e.g. $aligneropt, $alignertofstopt, $carmelinitopt.
. $1

# Make a temporary directory for the caller.
# (Change /tmp to something else, for servers with harsh quotas on /tmp.)
mktmpdir() {
  export tmpdir=/tmp/$scriptname-$$
  mkdir -p $tmpdir
  >&2 echo "Made tmpdir $tmpdir."
}

# Verify that a previously created file exists, and report that.
usingfile() {
  [[ -e $1 ]] || { >&2 echo "$scriptname: no file \"$1\" for $2. Aborting."; exit 1; }
  >&2 echo "Reusing $2 $1."
}

# Print a row of dots.
# showprogress init x "Creating widgets":	print first line, and set frequency of dots.
# showprogress go:				possibly print another dot.
# showprogress end:				print "Done."
#
# To show an error message more noticeably at the start of a line, instead of
# mid-line after the most recent dot, use echo -e "\nError message."
showprogress() {
  local arg="$1"
  case $arg in
    init)
      __progress_counter__=1
      __progress_stepsize__=$2
      >&2 echo -n "$3..."
      ;;
    go)
      if [[ $((__progress_counter__ % __progress_stepsize__)) -eq 0 ]] ; then
	      >&2 echo -n "."
      fi
      ((__progress_counter__++))
      ;;
    end)
      >&2 echo " Done."
      ;;
  esac
}
