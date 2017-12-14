#!/bin/bash

. $INIT_STEPS

if [ -z $applyPrepared ]; then
  if [[ -z $makeGTPLM && -z $decode_for_adapt ]]; then
    >&2 echo "$0: evaluation mode lacks flag makeGTPLM=1. Aborting."
    exit 1
  fi
fi

[ ! -z $Mscale ] || Mscale=1

if [[ -n $decode_for_adapt ]]; then
  splitids=$splitadaptids
else
  splitids=$splittestids
fi

# Pipeline for making *PLM.fst's.
fstSimplify()
{
  fstproject --project_output=false - | fstrmepsilon
}

showprogress init 50 "" # Long description is in caller.
mkdir -p $decodelatdir
for ip in $(seq -f %02g $nparallel); do
  [ -s $splitids.$ip ] || continue
  # If $splitids.$ip is empty, that may just mean that the pre-split file $splitids
  # had fewer than $nparallel lines.  Don't complain.
  (
  while read uttid; do
    if [ ! -s $mergefstdir/$uttid.M.fst.txt ]; then
      # Stage 5 mergefst.sh didn't make that M.fst.txt, because mergedir/$uttid.txt was empty.
      # No big deal, just a clip with no speech, e.g. only music.  Don't whine.
#     >&2 echo -e "$(basename $0): no M.fst.txt, so omitting $uttid."
      continue
    fi
    showprogress go

    scale-FST-weights.pl $Mscale < $mergefstdir/$uttid.M.fst.txt |
      fstcompile --isymbols=$engalphabet --osymbols=$engalphabet \
	> $mergefstdir/$uttid.M.fst

    # Compose and then project onto the input alphabet $phnalphabet,
    # yielding an FSA rather than an FST.
    if [ ! -z $applyPrepared ]; then
      fstcompose $PLfst $mergefstdir/$uttid.M.fst | fstSimplify > $decodelatdir/$uttid.PLM.fst
    else
      if [[ -n $makeTPLM ]]; then
	fstcompose $TPLfst $mergefstdir/$uttid.M.fst | fstSimplify > $decodelatdir/$uttid.TPLM.fst
      fi
      if [[ -n $makeGTPLM ]]; then
	fstcompose $GTPLfst $mergefstdir/$uttid.M.fst | fstSimplify > $decodelatdir/$uttid.GTPLM.fst
#       if [ $(fstinfo $decodelatdir/$uttid.GTPLM.fst |grep "# of states" | awk 'NF>1{print $NF}') = "0" ]; then
#  	>&2 echo -e "$(basename $0): made empty $decodelatdir/$uttid.GTPLM.fst."
#  	echo "details for $GTPLfst $mergefstdir/$uttid.M.fst composed:"
#  	fstinfo $GTPLfst | head -6 | tail -2
#  	fstinfo $mergefstdir/$uttid.M.fst | head -6 | tail -2
#  	fstcompose $GTPLfst $mergefstdir/$uttid.M.fst | fstinfo | head -6 | tail -2
#       fi
      fi
    fi
  done < $splitids.$ip
  ) &
done
wait
showprogress end

if ! find $decodelatdir -mindepth 1 | read ; then
  # $decodelatdir is empty.  Made no TPLMs or GTPLMs.
  >&2 echo "$0: no uttid in $splitids.* had speech.  Are the uttids in data/lists/*/eval missing from $transcripts?"
  # Todo: check much earlier that data/lists/*/*'s uttids are in $transcripts.
  exit 1
fi
