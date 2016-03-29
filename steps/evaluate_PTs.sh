#!/bin/bash
# Evaluate PTs using phone error rates computed on a test set
# of transcripts in the target language.

. $INIT_STEPS

if [[ -z $testids ]]; then
  echo "evaluate_PTs.sh: no variable testids in settings file '$1'. Aborting."; exit 1
fi
if [[ -z $decodelatdir ]]; then
  echo "evaluate_PTs.sh: no variable decodelatdir in settings file '$1'. Aborting."; exit 1
fi
if [[ -z $evalreffile ]]; then
  echo "evaluate_PTs.sh: no variable evalreffile in settings file '$1'. Aborting."; exit 1
fi
if [[ ! -s $evalreffile ]]; then
  echo "evaluate_PTs.sh: no file $evalreffile, evalreffile in settings file '$1'. Aborting."; exit 1
  # The executable compute-wer would fail.
fi
if [[ -z $phnalphabet ]]; then
  echo "evaluate_PTs.sh: no variable phnalphabet in settings file '$1'. Aborting."; exit 1
fi
if [[ (-n $evaloracle && -z $prunewt) ]]; then
  echo "evaluate_PTs.sh: corrupt variables evaloracle or prunewt in settings file '$1'. Aborting."; exit 1
fi

mktmpdir

editfst=$tmpdir/edit.fst
create-editfst.pl < $phnalphabet | fstcompile - > $editfst 

showprogress init 5 "Evaluating PTs"
oracleerror=0
for ip in `seq 1 $nparallel`; do
	(
	for uttid in `cat $splittestids.$ip`; do
		showprogress go
		latfile=$decodelatdir/$uttid.GTPLM.fst

		if [[ ! -s $latfile ]]; then
			>&2 echo -e "\nevaluate_PTs.sh: no decoded lattice file '$latfile'. Aborting."; exit 1
		fi
		if [[ -n $evaloracle ]]; then
			# Accumulate each wer into the number oracleerror.
			reffst=$tmpdir/$uttid.ref.fst 
			prunefst=$tmpdir/$uttid.prune.fst
			egrep "$uttid[ 	]" $evalreffile | cut -d' ' -f2- | make-acceptor.pl \
				| fstcompile --acceptor=true --isymbols=$phnalphabet  > $reffst
			fstprune --weight=$prunewt $latfile | fstprint | cut -f1-4 | uniq \
				| perl -a -n -e 'chomp; if($#F <= 2) { print "$F[0]\n"; } else { print "$_\n"; }' \
				| fstcompile - | fstarcsort --sort_type=olabel > $prunefst
			wer=`fstcompose $editfst $reffst | fstcompose $prunefst - \
				| fstshortestdistance --reverse | head -1 | cut -f2`
			oracleerror=`echo "$oracleerror + $wer" | bc`
		fi

		# Print the best hypothesis.
		echo -e -n "$uttid\t"
		fstshortestpath $latfile | fstprint --osymbols=$phnalphabet | reverse_fst_path.pl
	done > $tmpdir/hyp.$ip.txt
	) &
done
wait
showprogress end

> $tmpdir/hyp.txt
for ip in `seq 1 $nparallel`; do
	cat $tmpdir/hyp.$ip.txt >> $tmpdir/hyp.txt
done
if [[ ! -s $tmpdir/hyp.txt ]]; then
	>&2 echo "evaluate_PTs.sh: made no hypotheses.  Aborting."; exit 1
fi

if [[ ! -z $hypfile ]]; then
	cp $tmpdir/hyp.txt $hypfile
fi

hash compute-wer 2>/dev/null || { echo >&2 "evaluate_PTs.sh: missing program compute-wer. Aborting."; exit 1; }
compute-wer --text --mode=present ark:$evalreffile ark:$tmpdir/hyp.txt

if [[ -n $evaloracle ]]; then
	lines=`wc -l $evalreffile | cut -d' ' -f1`
	words=`wc -w $evalreffile | cut -d' ' -f1`
	per=`echo "scale=5; $oracleerror / ($words - $lines)" | bc -l`
	echo "Oracle Error-rate (prune-wt: $prunewt): $oracleerror Relative: $per"
fi
if [[ -z $debug ]]; then
	rm -rf $tmpdir
fi
