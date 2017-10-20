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
if [[ -n $mcasr ]]; then
  [ ! -z $LANG_CODE ] || { >&2 echo "$0: no variable LANG_CODE in file '$1'. Aborting."; exit 1; }
  [ ! -z $DATE_USC ] || { >&2 echo "$0: no variable DATE_USC in file '$1'. Aborting."; exit 1; }
  [ ! -z $pronlex ] || { >&2 echo "$0: no variable pronlex in file '$1'. Aborting."; exit 1; }
# [ ! -z $mtvocab ] || { >&2 echo "$0: no variable mtvocab in file '$1'. Aborting."; exit 1; }
  [ -s $pronlex ] || { >&2 echo "$0: missing or empty file '$pronlex', pronlex in file '$1'. Aborting."; exit 1; }
# [ -s $mtvocab ] || { >&2 echo "$0: missing or empty file '$mtvocab', mtvocab in file '$1'. Aborting."; exit 1; }
fi

mktmpdir

# if false; then #;;;;
# Make an edit distance FST with sub/ins/del costs for each phone.
editfst=$tmpdir/edit.fst
create-editfst.pl < $phnalphabet | fstcompile > $editfst 

# todo: Move this showprogress block into its own stage, because it's much slower than the rest of this script.
showprogress init 50 "Evaluating PTs"
rm -f $tmpdir/hyp.*.txt
for ip in `seq -f %02g $nparallel`; do
	(
	[ -s $splittestids.$ip ] || { >&2 echo "`basename $0`: missing or empty file $splittestids.$ip."; }
	oracleerror=0
	# Read all the uttid's in $splittestids.*, e.g. Exp/myLanguage/lists/testids.*.
	while read uttid; do
		showprogress go
		# $uttid ==, e.g., uzbek_371_001, IL5_EVAL_111_007_023498070_024734810
		latfile=$decodelatdir/$uttid.GTPLM.fst # Decoded lattice.
		# A missing $latfile just means that the clip had no speech, e.g. only music.  Don't whine.
#		[[ -s $latfile ]] || >&2 echo -e "`basename $0`: no GTPLM: skip $uttid." # ;;;;
		[[ -s $latfile ]] || continue;
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
	done < $splittestids.$ip > $tmpdir/hyp.$ip.txt
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
  >&2 echo "$0 made no hypotheses.  Aborting."; exit 1
fi
if [[ ! -z $hypfile ]]; then
  cp $tmpdir/hyp.txt $hypfile
fi
# fi #;;;;

# if false; then #;;;;
set -e
if [[ -n $mcasr ]]; then
  # Convert from phones to words,
  # to compute word error rate rather than phone error rate.
  >&2 echo "Converting $hypfile from phone strings to word strings."
  sort -n < $hypfile > $hypfile.phones
  # Restitch clips, then convert phone strings to word strings.
  # Update $hypfile too, for compute-wer?
  jonmay=${hypfile}.restitched.txt
  jonmaydir=${hypfile}.jonmay.dir
  # It's ok for $mtvocab to be unset.
  phone2word.rb $pronlex $mtvocab < $hypfile.phones > $jonmay
  >&2 echo "Formatting $jonmay entries into $jonmaydir."
  hyp2jonmay.rb $jonmaydir $LANG_CODE $DATE_USC $EXPLOCAL < $jonmay
fi
set +e
#fi #;;;;

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
