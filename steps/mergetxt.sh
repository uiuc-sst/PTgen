#!/bin/bash

. $INIT_STEPS

mkdir -p $mergedir

>&2 echo "`basename $0`: for MCASR, create-distances in PHONES not LETTERS."
create-distances-phones.pl > $aligndist # e.g., Exp/uzbek/aligndists.txt
# ;;;; create-distances.pl > $aligndist # e.g., Exp/uzbek/aligndists.txt

>&2 echo "`basename $0`: parsing $transcripts and $simfile."
rm -f /tmp/hash_transcripts.sh
makeHash.rb scrips < $transcripts > /tmp/hash_transcripts.sh
. /tmp/hash_transcripts.sh
makeHash.rb sims < $simfile > /tmp/hash_transcripts.sh
. /tmp/hash_transcripts.sh
rm -f /tmp/hash_transcripts.sh

# Values are ${scrips[@]}.  Keys are ${!scrips[@]}.  Size is ${#scrips[@]}.  Ditto for sims[].
# Before looking up a key in scrips, downcase it: key="${key,,}"
# echo "${scrips[uzb_001_001_017709_018816]}"

# Parallelizing more than $nparallel doesn't exploit more cores,
# because the files foo.$ip were split over only $nparallel parts
# by stage 3's create-datasplits.sh.  So just use shuf to balance
# the load somewhat.
showprogress init 200 "Merging transcripts"
for ip in `seq -f %02g $nparallel`; do
	(
	cat $splittrainids.$ip $splittestids.$ip $splitadaptids.$ip | shuf | while read uttid; do
		vttid=`echo $uttid | sed 's/uzbek/UZB/'`
		# These two yield the same number, often about 22, sporadically 0.
		#   grep -c $vttid $simfile
		#   grep -c $vttid $transcripts
		actualparts=(`grep $vttid $simfile | sed 's/,.*//'`)
		npartsReal=${#actualparts[*]}
		oldway=false
		if [ $npartsReal == 0 ]; then
		  npartsReal=$nparts
		  oldway=true
		fi
		if [[ -s $mergedir/$uttid.txt && `grep -c "$delimsymbol" $mergedir/$uttid.txt` == $npartsReal ]]; then
		  #echo Already merged uttid $uttid.
		  continue
		fi
		if $oldway ; then
		  echo Merging $npartsReal parts into vttid $vttid.
		fi
		showprogress go
		touch $mergedir/$uttid.txt
		for p in `seq 1 $npartsReal`; do
			if [ "$oldway" = "true" ]; then
			  part="part-$p-$uttid"
			  str=${sims[${part,,}]}
			  tstr=${scrips[${part,,}]}
			else
			  part=${actualparts[`expr $p - 1`]}
			  # echo reading part $part

			  # $part is e.g. IL6_EVAL_001_002_011245212_012494679
			  # After uzb, i.e., rus, tig, orm,
			  # there's only one match, and that's at the start of the line.
			  str=${sims[${part,,}]}
			  tstr=${scrips[${part,,}]}
			fi
			if [[ -z $str || -z $tstr ]]; then
			  	# This happens when
				# grep IL5_EVAL_033_012_086570606_087807328 ~/l/PTgen/mcasr/tir-clips.txt
				# yields only SPN_S.  Ignore it silently.
				#
				# But shouldn't a silent clip still map to a SIL phone, instead of being removed???
				#
				# >&2 echo -e "\nmergetxt.sh WARNING: either $simfile or $transcripts lacks\n  $part,\n  which came from an uttid in one of $splittrainids.$ip $splittestids.$ip $splitadaptids.$ip."
				# echo Abandoning and deleting $mergedir/$uttid.txt.
				# rm -f $mergedir/$uttid.txt 2>/dev/null
				break
			fi

			# Read the IDs of the best topN turkers (often 2, in settings);
			# read only THOSE turkers' transcriptions;
			# send those transcriptions through steps/aligner into mergedir/part-$p-$uttid.txt.
			idx=`expr $topN + 1`
				# Example:
				# $str  is "UZB_154_009_002796_003727,4:1,3:0.916667,5:0.916667,2:0.770833,1:-0"
				# $tstr is "UZB_154_009_002796_003727:2 1 # 9 24 19 28 48 61 25 42 61 48 27 1 # 24 14 42 28 27 27 20 24 32 24 28 16 18 50 # 27 48 9 48 27 20 24 7 24 28 18 42 # 27 48 9 48 27 24 7 12 28 43 48"
				# $turkerindex goes from "2" to n.
				# From $str, get the ith comma-delimited field: "4:1", "7:1", "2:0.916667", etc.
				# From that, get the first colon-delimited field.
				# Then $turker is 4,7,2, etc.
			for turkerindex in `seq 2 $idx`; do
				turker=`echo $str | cut -d',' -f$turkerindex | cut -d':' -f1`
				if [[ -z $turker ]]; then
				  # This utterance had only one turker, one transcription.
				  turker=1
				fi
				echo $tstr | cut -d':' -f2- | cut -d'#' -f$turker
			done | aligner $aligneropt | grep "[^ ]" > $mergedir/part-$p-$uttid.txt
			# $aligneropt contains $aligndist, made at the start of this script.
			#
			# The grep for a nonspace is a hack to eliminate blank lines.  Better would be
			# to detect and skip empty output[] rows in steps/aligner.cc,
			# or to see what inputs to steps/aligner can make it emit blank lines.

			cat $mergedir/part-$p-$uttid.txt >> $mergedir/$uttid.txt

			if [[ -n $delimsymbol ]] ; then
				( for x in `seq 1 $topN`; do
					echo -e -n "$delimsymbol\t"
				  done 
				  echo ) >> $mergedir/$uttid.txt
			fi
		done
	done
	) &
done
wait
showprogress end
