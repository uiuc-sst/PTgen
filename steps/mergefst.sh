#!/bin/bash

. $INIT_STEPS

# Exit if there is any error.
set -e

if [[ ! -d $mergedir ]] ; then
	>&2 echo "mergefst.sh: no directory $mergedir.  Aborting."; exit 1
fi

mkdir -p $mergefstdir
showprogress init 100 "Merging transcript FSTs (unscaled)"
for ip in `seq 1 $nparallel`; do
	(
	for uttid in `cat $splittrainids.$ip $splittestids.$ip $splitadaptids.$ip`; do
		if [[ -s $mergedir/$uttid.txt ]] ; then
			showprogress go
			convert-aligner-to-fst.pl `echo $alignertofstopt` < $mergedir/$uttid.txt \
				| convert-prob-to-neglog.pl | tee $mergefstdir/$uttid.M.fst.txt \
				| fstcompile --isymbols=$engalphabet --osymbols=$engalphabet \
				| fstarcsort --sort_type=ilabel - > $mergefstdir/$uttid.M.fst
		else
			>&2 echo -e -n "\nmergefst.sh: skipping utterance $uttid."
		fi
	done
	) &
done
wait
showprogress end
