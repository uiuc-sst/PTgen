#!/bin/bash

. $INIT_STEPS

if [[ -z $makeGTPLM && -z $decode_for_adapt ]]; then
  >&2 echo "$0: evaluation mode lacks flag makeGTPLM=1.  Aborting."
  exit 1
fi

mkdir -p $decodelatdir

if [[ -n $decode_for_adapt ]]; then
  splitids=$splitadaptids
else
  splitids=$splittestids
fi

showprogress init 30 "" # Long description is in caller, ../run.sh.
for ip in `seq -f %02g $nparallel`; do
  (
  for uttid in `cat $splitids.$ip`; do
    if [[ ! -s $mergefstdir/$uttid.M.fst.txt ]]; then
      >&2 echo -e "`basename $0`: omitting $uttid because of missing file $mergefstdir/$uttid.M.fst.txt."
      # That file might exist and be empty, but usually it is just missing.
      continue
    fi
    showprogress go

    scale-FST-weights.pl $Mscale < $mergefstdir/$uttid.M.fst.txt \
      | fstcompile --isymbols=$engalphabet --osymbols=$engalphabet \
      > $mergefstdir/$uttid.M.fst

    if [[ -n $makeGTPLM ]]; then
      fstcompose $GTPLfst $mergefstdir/$uttid.M.fst | fstproject --project_output=false - > $decodelatdir/$uttid.GTPLM.fst
#     if [ `fstinfo $decodelatdir/$uttid.GTPLM.fst |grep "# of states" | awk 'NF>1{print $NF}'` = "0" ]; then
#	>&2 echo -e "`basename $0`: made empty $decodelatdir/$uttid.GTPLM.fst."
#	echo "details for $GTPLfst $mergefstdir/$uttid.M.fst composed:"
#	fstinfo $GTPLfst | head -6 | tail -2
#	fstinfo $mergefstdir/$uttid.M.fst | head -6 | tail -2
#	fstcompose $GTPLfst $mergefstdir/$uttid.M.fst | fstinfo | head -6 | tail -2
#     fi
    fi

    if [[ -n $makeTPLM ]]; then
      fstcompose $TPLfst $mergefstdir/$uttid.M.fst | fstproject --project_output=false - \
	> $decodelatdir/$uttid.TPLM.fst
#     if [ `fstinfo $decodelatdir/$uttid.TPLM.fst |grep "# of states" | awk 'NF>1{print $NF}'` = "0" ]; then
#	>&2 echo -e "`basename $0`: made empty $decodelatdir/$uttid.TPLM.fst."
#     fi
    fi
  done
  ) &
done
wait
showprogress end
