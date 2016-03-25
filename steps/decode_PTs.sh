#!/bin/bash

. $INIT_STEPS

if [[ -z $makeGTPLM && -z $decode_for_adapt ]]; then
	>&2 echo "decode_PTs.sh: aborting.  In evaluation mode, make GTPLM flag must be set."
	exit 1
fi

mkdir -p $decodelatdir

splitids=$splittestids;
if [[ -n $decode_for_adapt ]]; then
	splitids=$splitadaptids;
fi

showprogress init 5 "" # Long description is in caller, ../run.sh.
for ip in `seq 1 $nparallel`; do
	(
	for uttid in `cat $splitids.$ip`; do
		if [[ ! -s $mergefstdir/$uttid.M.fst.txt ]]; then
			>&2 echo -e "decode_PTs.sh WARNING: omitted $uttid because of missing or empty file $mergefstdir/$uttid.M.fst.txt."
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
showprogress end
