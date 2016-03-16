#!/bin/bash

. $INIT_STEPS

mktmpdir

if [[ ! -s $reffile ]]; then
	>&2 echo "prepare-phn2let-traindata.sh: missing or empty reference file $reffile";
	exit 1;
fi

showprogress init 100 "Preparing training data"
( for uttid in `cat $trainids`; do
	if [[ -s $mergefstdir/${uttid}.M.fst ]]; then
		showprogress go
		refstring=`egrep "${uttid}[ 	]" $reffile \
			| cut -d' ' -f2- \
			| sed -e 's/^[ \t]*/"/' \
			| sed -e 's/[ \t]*$/"/' \
			| sed -e 's/[ \t]\+/" "/g'`
		if [[ -z $refstring ]]; then
			>&2 echo "prepare-phn2let-traindata.sh: WARNING: Empty reference string for $uttid. Skipping utterance."
			continue
		fi
		for rn in `seq 1 $nrand`; do
			echo $refstring
			fstrandgen --npath=1 --select=log_prob $mergefstdir/${uttid}.M.fst \
				| fstprint --osymbols=$engalphabet \
				| reverse_randgenfstpaths.pl $uttid \
				| cut -d' ' -f2- \
				| sed -e 's/^[ \t]*/"/' \
				| sed -e 's/[ \t]*$/"/' \
				| sed -e 's/[ \t]\+/" "/g'
		done
	else
		>&2 echo -e -n "\nprepare-phn2let-traindata.sh: WARNING: no file $mergefstdir/${uttid}.M.fst "
	fi
done ) > $carmeltraintxt
showprogress end
