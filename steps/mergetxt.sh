#!/bin/bash

. $INIT_STEPS

mkdir -p $mergedir

create-distances.pl > $aligndist

showprogress init 100 "Merging transcripts"
for ip in `seq 1 $nparallel`; do
	(
	for uttid in `cat $splittrainids.$ip $splittestids.$ip $splitadaptids.$ip`; do
		showprogress go
		if [[ -s $mergedir/$uttid.txt && `grep "$delimsymbol" $mergedir/$uttid.txt | wc -l` == $nparts ]]; then
			continue;
		fi
		> $mergedir/$uttid.txt
		for p in `seq 1 $nparts`; do
			set +e
			part="part-$p-$uttid"
			str=`grep "$part," $simfile`
			tstr=`grep -i "$part:" $transcripts`
			set -e
			if [[ -z $str || -z $tstr ]]; then
				>&2 echo -e -n "\nmergetxt.sh WARNING: neither $simfile nor $transcripts contains $part."
				rm -f $mergedir/$uttid.txt 2>/dev/null
				break
			fi

			idx=`expr $topN + 1`;
			for turkerindex in `seq 2 $idx`; do
				turker=`echo $str | cut -d',' -f$turkerindex | cut -d':' -f1`;
				echo $tstr | cut -d':' -f2- | cut -d'#' -f${turker}
			done | aligner `echo $aligneropt` > $mergedir/part-$p-$uttid.txt

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
wait;
showprogress end
