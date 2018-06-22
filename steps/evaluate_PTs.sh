#!/bin/bash
# Evaluate PTs using phone error rates computed on a
# test set of transcripts in the target language.

. $INIT_STEPS

[ ! -z $testids ] || { >&2 echo "$0: no variable testids in file '$1'. Aborting."; exit 1; }
[ ! -z $decodelatdir ] || { >&2 echo "$0: no variable decodelatdir in file '$1'. Aborting."; exit 1; }
[[ ! (-n $evaloracle && -z $prunewt) ]] || { >&2 echo "$0: corrupt variables evaloracle or prunewt in file '$1'. Aborting."; exit 1; }
if [[ -n $mcasr ]]; then
  [ ! -z $LANG_CODE ] || { >&2 echo "$0: no variable LANG_CODE in file '$1'. Aborting."; exit 1; }
  [ ! -z $DATE_USC ] || { >&2 echo "$0: no variable DATE_USC in file '$1'. Aborting."; exit 1; }
  [ ! -z $pronlex ] || { >&2 echo "$0: no variable pronlex in file '$1'. Aborting."; exit 1; }
  [ ! -z $jonmayVersion ] || { >&2 echo "$0: no variable jonmayVersion in file '$1'. Aborting."; exit 1; }
  [ -s $pronlex ] || { >&2 echo "$0: missing or empty '$pronlex', pronlex in file '$1'. Aborting."; exit 1; }
  [ -s $jonmayVersion ] || { >&2 echo "$0: missing or empty '$jonmayVersion', jonmayVersion in file '$1'. Aborting."; exit 1; }
fi
if [[ -n $evaloracle ]]; then
  hash compute-wer 2>/dev/null || { >&2 echo "$0: missing program compute-wer. Aborting."; exit 1; }
  [ ! -z $evalreffile ] || { >&2 echo "$0: no variable evalreffile in file '$1'. Aborting."; exit 1; }
  [ -s $evalreffile ] || { >&2 echo "$0: missing or empty file '$evalreffile', evalreffile in file '$1'. Aborting."; exit 1; }
  # $evalreffile is the known-good transcriptions for compute-wer, e.g. data/nativetranscripts/uzbek/dev_text.
fi

mktmpdir

#if false; then #;;;;
# Make an edit distance FST with sub/ins/del costs for each phone.
editfst=$tmpdir/edit.fst
create-editfst.pl < $phnalphabet | fstcompile > $editfst 

# todo: Move this showprogress block into its own stage, because it's much slower than the rest of this script.
showprogress init 50 "Evaluating PTs"
rm -f $tmpdir/hyp.*.txt
for ip in $(seq -f %02g $nparallel); do
	(
	# If $splittestids.$ip is empty, it may just mean that nparallel exceeds the number of uttid's.  Don't complain.
	oracleerror=0 # Accumulator for $per.
	# Read all the uttid's in $splittestids.*, e.g. Exp/myLanguage/lists/testids.*.
	while read uttid; do
		showprogress go
		# $uttid is e.g., uzbek_371_001, IL5_EVAL_111_007_023498070_024734810
		if [ -z $applyPrepared ]; then
		  latfile=$decodelatdir/$uttid.GTPLM.fst
		else
		  latfile=$decodelatdir/$uttid.PLM.fst
		fi
		# $latfile is the decoded lattice.  If missing, that just means that the clip had no speech, e.g. only music.
		[ -s $latfile ] || continue;

		if [[ -n $evaloracle && ! -n $evalWER ]]; then
			# Measure PER, not WER.
			# Make an acceptor for known-good transcription (phones).
			foo=$(grep -E "$uttid[ 	]" $evalreffile)
			[ -z "$foo" ] && >&2 echo "$(basename $0): evalreffile $evalreffile lacks uttid $uttid." && continue
			# todo: instead of repeated greps, parse $evalreffile into a hash beforehand, like mergetxt.sh.
			reffst=$tmpdir/$uttid.ref.fst
			echo $foo | cut -d' ' -f2 | make-acceptor.pl | fstcompile --acceptor=true --isymbols=$phnalphabet > $reffst
			# Sanity check, faster than fstinfo.
			[ $(fstprint $reffst | wc -c) == '0' ] && >&2 echo "$(basename $0): made empty reference fst $reffst." && continue
			# Prune the utterance FST.
			prunefst=$tmpdir/$uttid.prune.fst
			fstprune --weight=$prunewt $latfile | fstprint | cut -f1-4 | uniq \
				| perl -a -n -e 'chomp; if($#F <= 2) { print "$F[0]\n"; } else { print "$_\n"; }' \
				| fstcompile | fstarcsort --sort_type=olabel > $prunefst
			# Calculate the phone error rate.
			fstTmp=$tmpdir/tmp.$ip.fst
			fstcompose $editfst $reffst | fstcompose $prunefst - > $fstTmp
			[ $(fstprint $fstTmp | wc -c) == '0' ] && >&2 echo "$(basename $0): empty PER fst." && continue # Sanity check, faster than fstinfo.
			tmp=$(fstshortestdistance --reverse < $fstTmp)
			rm $fstTmp
			[ -z "$tmp" ] && >&2 echo "$(basename $0): empty PER eval." && continue
			per=$(echo $tmp | head -1 | cut -f2)
			# Accumulate each phone error rate into the number oracleerror.
			oracleerror=$(echo "$oracleerror + $per" | bc)
			>&2 echo "Oracle: PER for $uttid = $per; Cumulative PER = $oracleerror"
		fi
#		echo "fstshortestpath $latfile using $phnalphabet < $splittestids.$ip" | >&2 sed "s/.home.camilleg.Tmp.Exp.//g" # debug
		echo -e -n "$uttid\t"
		if true; then
		  # Print one of many plausible hypotheses.
		  fstrandgen --select=log_prob $latfile | fstrmepsilon | fstprint --osymbols=$phnalphabet | reverse_fst_path.pl
		else
		  # Print only the very best hypothesis.
		  fstshortestpath $latfile | fstrmepsilon | fstprint --osymbols=$phnalphabet | reverse_fst_path.pl --shortestpath
		fi
	done < $splittestids.$ip > $tmpdir/hyp.$ip.txt
	[[ -n $evaloracle ]] && echo "$oracleerror" > $tmpdir/oracleerror.$ip.txt
	) &
done
wait
showprogress end

# It's ok for some hyp.*.txt to be empty, but not all.
cat $tmpdir/hyp.*.txt > $tmpdir/hyp.txt
if [[ ! -s $tmpdir/hyp.txt ]]; then
  >&2 echo "$0 made no hypotheses.  Aborting."; exit 1
fi
if [[ ! -z $hypfile ]]; then
  sort < $tmpdir/hyp.txt > $hypfile
fi
# fi #;;;;

# if false; then #;;;;
set -e
if [[ -n $mcasr ]]; then
  # Convert from phones to words,
  # to compute word error rate rather than phone error rate.
  >&2 echo "Converting $hypfile from phone strings to word strings."
  # Restitch clips, then convert phone strings to word strings.
  # Update $hypfile too, for compute-wer?
  jonmay=${hypfile}.restitched.txt
  # It's ok for $mtvocab to be unset.
  sort -n < $hypfile | tee $hypfile.phones | phone2word.rb $pronlex $mtvocab > $jonmay
  hyp2jonmay.rb ${hypfile}.jonmay.dir $LANG_CODE $DATE_USC $EXPLOCAL $jonmayVersion < $jonmay
  # Increment this before each sftp.
  # Todo: read this from settings file, via ARGV.
fi
set +e
#fi #;;;;

if [[ -n $evaloracle ]]; then
  compute-wer --text --mode=present ark:$evalreffile ark:$jonmay
  oracleerror=$(cat $tmpdir/oracleerror.*.txt | awk 'BEGIN {sum=0} {sum=sum+$1} END{print sum}')
  lines=$(wc -l < $evalreffile)
  words=$(wc -w < $evalreffile)
  per=$(echo "scale=5; $oracleerror / ($words - $lines)" | bc -l)
  echo "lines = $lines, words = $words"
  echo "Oracle error rate (prune-wt: $prunewt): $oracleerror Relative: $per"
fi

if [[ -z $debug ]]; then
  rm -rf $tmpdir
fi
