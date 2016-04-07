#!/bin/bash

. $INIT_STEPS

mkdir -p $mergedir

create-distances.pl > $aligndist

showprogress init 100 "Merging transcripts"
for ip in `seq -f %02g $nparallel`; do
	(
	for uttid in `cat $splittrainids.$ip $splittestids.$ip $splitadaptids.$ip`; do
		showprogress go
		if [[ -s $mergedir/$uttid.txt && `grep "$delimsymbol" $mergedir/$uttid.txt | wc -l` == $nparts ]]; then
			continue
		fi
		> $mergedir/$uttid.txt
		for p in `seq 1 $nparts`; do
			set +e
			part="part-$p-$uttid"
			str=`grep "$part," $simfile`
			tstr=`grep -i "$part:" $transcripts`
			set -e
			if [[ -z $str || -z $tstr ]]; then
				>&2 echo -e "\nmergetxt.sh WARNING: neither $simfile nor $transcripts contains\n\t$part,\n\twhich came from an uttid in one of $splittrainids.$ip $splittestids.$ip $splitadaptids.$ip,\n\tfor p from 1 to $nparts."
				rm -f $mergedir/$uttid.txt 2>/dev/null
				break
			fi

			idx=`expr $topN + 1`
				# Example:
				# $str  is "part-1-dutch_141129_376553-4,4:1,7:1,2:0.916667,3:0.916667,8:0.833333,5:0.583333,6:0.5,1:-0,9:-0"
				# $tstr is "part-1-dutch_141129_376553-4:a S#b o r S#b a S d o#b o t s#o l f#p a s#o a f t#o u s e#o z\nb o t s"
				# $turkerindex goes from "2" to n.
				# Get the ith comma-delimited field of $str: "4:1", "7:1", "2:0.916667", etc;
				# from that, get the first colon-delimited field.
				# Then $turker is 4,7,2, etc.
				#
				# Sporadically, this emits: cut: option requires an argument -- 'f'
				# So either $turkerindex or $turker is empty.
				# The former, if $idx is corrupt?
				# The latter, if $str is corrupt? If $str is too short, cut -f9 emits only "\n".  That would cause that error.
			for turkerindex in `seq 2 $idx`; do
				turker=`echo $str | cut -d',' -f$turkerindex | cut -d':' -f1`
				echo $tstr | cut -d':' -f2- | cut -d'#' -f$turker
			done | aligner $aligneropt > $mergedir/part-$p-$uttid.txt

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
