#!/bin/bash

. $INIT_STEPS

# Exit if there is any error.
set -e

[ -d $mergedir ] || { >&2 echo "$0: no directory $mergedir.  Aborting."; exit 1; }

mkdir -p $mergefstdir
showprogress init 100 "Merging transcript FSTs (unscaled)"
for ip in `seq -f %02g $nparallel`; do
	(
	cat $splittrainids.$ip $splittestids.$ip $splitadaptids.$ip | shuf | while read uttid; do
		if [[ ! -s $mergedir/$uttid.txt ]] ; then
			>&2 echo -e -n "\n`basename $0`: skipping empty utterance $mergedir/$uttid.txt."
		else
			showprogress go
			convert-aligner-to-fst.pl $alignertofstopt < $mergedir/$uttid.txt \
				| convert-prob-to-neglog.pl | tee $mergefstdir/$uttid.M.fst.txt \
				| fstcompile --isymbols=$engalphabet --osymbols=$engalphabet \
				| fstarcsort --sort_type=ilabel - > $mergefstdir/$uttid.M.fst
			# $uttid.M.fst should be an acyclic sausage, with one terminal state, that has zero cost.
			# No arc should have infinite cost.
			# Most arcs should have probability 1 (chain), or 0.5/0.5, 0.5/0.25/0.25, etc (sausage).
			# Even more strongly:
			# the set of arcs must be { (i,i+1) } for i from 0 to end-1,
			# with possible duplicates that echo different characters.
			# todo: Verify this.
			if [[ $(fstprint --acceptor $mergefstdir/$uttid.M.fst | grep Infinity) ]]; then
				>&2 echo -e -n "\n`basename $0`: made FST with infinite-cost arcs for $mergedir/$uttid.txt."
			fi
			# todo: if fstprint | grep "# of connected components" is not 1, warn that it is disconnected.
			# todo: if fstprint | grep "# of strongly conn components" is not equal to "number of states", warn that it has a loop.
		fi
	done
	) &
done
wait
showprogress end
