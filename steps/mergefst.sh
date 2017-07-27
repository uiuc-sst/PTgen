#!/bin/bash

. $INIT_STEPS

# Exit if there is any error.
set -e

[ -d $mergedir ] || { >&2 echo "$0: no directory $mergedir.  Aborting."; exit 1; }

mkdir -p $mergefstdir
showprogress init 100 "Merging transcript FSTs (unscaled)"
for ip in `seq -f %02g $nparallel`; do
	(
	for uttid in `cat $splittrainids.$ip $splittestids.$ip $splitadaptids.$ip`; do
		if [[ -s $mergedir/$uttid.txt ]] ; then
			showprogress go
			convert-aligner-to-fst.pl `echo $alignertofstopt` < $mergedir/$uttid.txt \
				| convert-prob-to-neglog.pl | tee $mergefstdir/$uttid.M.fst.txt \
				| fstcompile --isymbols=$engalphabet --osymbols=$engalphabet \
				| fstarcsort --sort_type=ilabel - > $mergefstdir/$uttid.M.fst
		else
			>&2 echo -e -n "\n`basename $0`: skipping empty utterance $mergedir/$uttid.txt."
		fi
	done
	) &
done
wait
showprogress end
