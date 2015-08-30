#!/bin/bash

. $INIT_STEPS

mkdir -p $decodelatdir

showprogress init 5 "Decoding"
for ip in `seq 1 $nparallel`; do
	(
	for uttid in `cat $splittestids.$ip`; do
		if [[ ! -s $mergefstdir/$uttid.M.fst.txt ]]; then
			>&2 echo -e -n "WARNING: Omitted $uttid"
			continue
		fi
		showprogress go

		scale-FST-weights.pl $Mscale < $mergefstdir/${uttid}.M.fst.txt \
			| fstcompile --isymbols=$engalphabet --osymbols=$engalphabet \
			| tee $mergefstdir/$uttid.M.fst \
			| fstcompose $GTPLfst - | fstproject --project_output=false -  > $decodelatdir/${uttid}.GTPLM.fst

		if [[ -n $makeTPLM ]]; then
			fstcompose $TPLfst $mergefstdir/$uttid.M.fst \
				| fstproject --project_output=false -  > $decodelatdir/${uttid}.TPLM.fst
		fi
	done
	) &
done
wait;
showprogress end "Done"
