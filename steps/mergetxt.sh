#!/bin/bash

. $INIT_STEPS

if [ "$DEBUG"==yes ]; then
    set -x
fi

mkdir -p $mergedir

create-distances.pl > $aligndist # e.g., Exp/uzbek/aligndists.txt

showprogress init 100 "Merging transcripts"
for ip in `seq -f %02g $nparallel`; do
	(
	for uttid in `cat $splittrainids.$ip $splittestids.$ip $splitadaptids.$ip`; do
		vttid=`echo $uttid | sed 's/uzbek/UZB/'`
		# These two yield the same number, often about 22, sporadically 0.
		#   grep $vttid $simfile | wc -l
		#   grep $vttid $transcripts | wc -l
		actualparts=(`grep $vttid $simfile | sed 's/,.*//'`)
		npartsReal=${#actualparts[*]}
		oldway=false
		if [ $npartsReal == 0 ]; then
		  npartsReal=$nparts
		  oldway=true
		fi
		if [[ -s $mergedir/$uttid.txt && `grep "$delimsymbol" $mergedir/$uttid.txt | wc -l` == $npartsReal ]]; then
		  echo Already merged uttid $uttid.
		  continue
		fi
		if $oldway ; then
		  echo Merging $npartsReal parts into vttid $vttid.
		fi
		showprogress go
		touch $mergedir/$uttid.txt
		for p in `seq 1 $npartsReal`; do
			set +e # prevent matchless grep from exiting this script
			if [ "$oldway" = "true" ]; then
			  part="part-$p-$uttid"
			  str=`grep "$part," $simfile`
			  tstr=`grep -i "$part:" $transcripts`
			else
			  part=${actualparts[`expr $p - 1`]}
			  # echo reading part $part
			  # The next two greps are a major bottleneck when $transcripts is 13 MB, $simfile 4 MB.
			  # Replace with a hash table or something?
			  tstr=`grep -i "$part:" $transcripts`
			  str=`grep -i "$part," $simfile`
			fi
			set -e
			if [[ -z $str || -z $tstr ]]; then
				>&2 echo -e "\nmergetxt.sh WARNING: either $simfile or $transcripts lacks\n  $part,\n  which came from an uttid in one of $splittrainids.$ip $splittestids.$ip $splitadaptids.$ip."
				echo Abandoning and deleting $mergedir/$uttid.txt.
				rm -f $mergedir/$uttid.txt 2>/dev/null
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
