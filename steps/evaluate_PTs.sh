#!/bin/bash
# Evaluate PTs using phone error rates computed on a
# test set of transcripts in the target language.

. $INIT_STEPS

[ ! -z $testids ] || { >&2 echo "$0: no variable testids in file '$1'. Aborting."; exit 1; }
[ ! -z $decodelatdir ] || { >&2 echo "$0: no variable decodelatdir in file '$1'. Aborting."; exit 1; }
[ ! -z $evalreffile ] || { >&2 echo "$0: no variable evalreffile in file '$1'. Aborting."; exit 1; }
[[ ! (-n $evaloracle && -z $prunewt) ]] || { >&2 echo "$0: corrupt variables evaloracle or prunewt in file '$1'. Aborting."; exit 1; }
[ -s $evalreffile ] || { >&2 echo "$0: missing or empty file '$evalreffile', evalreffile in file '$1'. Aborting."; exit 1; }
# $evalreffile is the known-good transcriptions for compute-wer, e.g. data/nativetranscripts/uzbek/dev_text.
hash compute-wer 2>/dev/null || { >&2 echo "$0: missing program compute-wer. Aborting."; exit 1; }

mktmpdir

# Make an edit distance FST with sub/ins/del costs for each phone.
editfst=$tmpdir/edit.fst
create-editfst.pl < $phnalphabet | fstcompile > $editfst 

showprogress init 15 "Evaluating PTs"
for ip in `seq -f %02g $nparallel`; do
	(
	[ -s $splittestids.$ip ] || { >&2 echo "`basename $0`: missing or empty file $splittestids.$ip."; }
	oracleerror=0
	# Read all the uttid's in, e.g., /tmp/Exp/uzbek/lists/testids.*.
	for uttid in `cat $splittestids.$ip`; do
		showprogress go
		# $uttid ==, e.g., uzbek_371_001
		latfile=$decodelatdir/$uttid.GTPLM.fst
		[ -s $latfile ] || { >&2 echo -e "\n$0: no decoded lattice '$latfile'. Skipping $uttid."; continue; }
		if [[ -n $evaloracle ]]; then
			# Make an acceptor for known-good transcription (phones).
			reffst=$tmpdir/$uttid.ref.fst
			egrep "$uttid[ 	]" $evalreffile | cut -d' ' -f2- | make-acceptor.pl \
				| fstcompile --acceptor=true --isymbols=$phnalphabet  > $reffst
			# Prune the utterance FST.
			prunefst=$tmpdir/$uttid.prune.fst
			fstprune --weight=$prunewt $latfile | fstprint | cut -f1-4 | uniq \
				| perl -a -n -e 'chomp; if($#F <= 2) { print "$F[0]\n"; } else { print "$_\n"; }' \
				| fstcompile | fstarcsort --sort_type=olabel > $prunefst
			# Accumulate each phone error rate into the number oracleerror.
			per=`fstcompose $editfst $reffst | fstcompose $prunefst - \
				| fstshortestdistance --reverse | head -1 | cut -f2`
			oracleerror=`echo "$oracleerror + $per" | bc`
			>&2 echo -e "Oracle PER (Job $ip): PER for $uttid = $per; Cumulative PER = $oracleerror"
		fi
		# Print a *plausible* hypothesis (fstrandgen), not just the very best one (fstshortestpath).
		echo -e -n "$uttid\t"
		fstrandgen --select=log_prob $latfile | fstrmepsilon | fstprint --osymbols=$phnalphabet | reverse_fst_path.pl
	done > $tmpdir/hyp.$ip.txt
	[[ -n $evaloracle ]] && echo "$oracleerror" > $tmpdir/oracleerror.$ip.txt
	) &
done
wait
showprogress end

> $tmpdir/hyp.txt
for ip in `seq -f %02g $nparallel`; do
	cat $tmpdir/hyp.$ip.txt >> $tmpdir/hyp.txt
done
if [[ ! -s $tmpdir/hyp.txt ]]; then
	>&2 echo "evaluate_PTs.sh: made no hypotheses.  Aborting."; exit 1
fi
if [[ ! -z $hypfile ]]; then
	cp $tmpdir/hyp.txt $hypfile
fi

# Compute word error rate rather than phone error rate.
>&2 echo "Converting $hypfile from phone strings to word strings."
cp $hypfile $hypfile.PERnotWER
phone2word.rb < $hypfile.PERnotWER > $hypfile

jonmay=${hypfile}.jonmay.txt
>&2 echo "Concatenating $hypfile entries into $jonmay."
hyp2jonmay.rb < $hypfile > $jonmay

compute-wer --text --mode=present ark:$evalreffile ark:$hypfile

if [[ -n $evaloracle ]]; then
	oracleerror=`cat $tmpdir/oracleerror.*.txt | awk 'BEGIN {sum=0} {sum=sum+$1} END{print sum}'`
	lines=`wc -l $evalreffile | cut -d' ' -f1`
	words=`wc -w $evalreffile | cut -d' ' -f1`
	per=`echo "scale=5; $oracleerror / ($words - $lines)" | bc -l`
	echo "lines = $lines, words = $words"
	echo "Oracle error rate (prune-wt: $prunewt): $oracleerror Relative: $per"
fi

if [[ -z $debug ]]; then
	rm -rf $tmpdir
fi
