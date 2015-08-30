#!/bin/bash

. $INIT_STEPS

if [[ -z $makeGTPLM && -z $decode_for_adapt ]]; then
	>&2 echo "Make GTPLM flag should be set in evaluation mode"
	exit 1
fi

mkdir -p $decodelatdir

splitids=$splittestids;
if [[ -n $decode_for_adapt ]]; then
	splitids=$splitadaptids;
fi


showprogress init 5 "Decoding"
for ip in `seq 1 $nparallel`; do
	(
	for uttid in `cat $splitids.$ip`; do
		if [[ ! -s $mergefstdir/$uttid.M.fst.txt ]]; then
			>&2 echo -e -n "WARNING: Omitted $uttid"
			continue
		fi
		showprogress go

		scale-FST-weights.pl $Mscale < $mergefstdir/${uttid}.M.fst.txt \
			| fstcompile --isymbols=$engalphabet --osymbols=$engalphabet \
			> $mergefstdir/$uttid.M.fst

		if [[ -n $makeGTPLM ]]; then
			fstcompose $GTPLfst $mergefstdir/$uttid.M.fst \
				| fstproject --project_output=false -  > $decodelatdir/${uttid}.GTPLM.fst
		fi

		if [[ -n $makeTPLM ]]; then
			fstcompose $TPLfst $mergefstdir/$uttid.M.fst \
				| fstproject --project_output=false -  > $decodelatdir/${uttid}.TPLM.fst
		fi
	done
	) &
done
wait;
showprogress end "Done"
