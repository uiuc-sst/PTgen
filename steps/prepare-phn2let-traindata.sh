#!/bin/bash

. $INIT_STEPS

# Exit if there is any error.
set -e

if [[ ! -s $trainids ]]; then
  >&2 echo "prepare-phn2let-traindata.sh: missing or empty training file $trainids. Aborting."; exit 1
fi

showprogress init 30 "Preparing training data"

reffile=$EXPLOCAL/ref_train_text
for L in ${TRAIN_LANG[@]}; do
	if [[ ! -s $TRANSDIR/$L/ref_train ]]; then
		>&2 echo "\$TRAIN_LANGS includes $L, but there's no file $TRANSDIR/$L/ref_train.  Aborting."; exit 1
	fi
	cat $TRANSDIR/$L/ref_train
done > $reffile

# Without parallelizing, this stage would take 60 to 70% of run.sh's time.  (Carmel is most of the rest.)

# nLOTS is way more than $nparallel, but less than split's limit of 100 (or use split -a).
# Better might be a precise value like $nparallel * $nrand,
# or parallelizing the inner $nrand loop as well as the outer $nLOTS loop.
nLOTS=98
split --numeric-suffixes=1 -n r/$nLOTS $trainids $trainids.

for ip in `seq -w 1 $nLOTS`; do
  if [[ ! -s $trainids.$ip ]]; then
    >&2 echo -e "\nprepare-phn2let-traindata.sh: no split-file $trainids.$ip. Aborting."; exit 1
  fi
  ( for uttid in `cat $trainids.$ip`; do
    if [[ ! -s $mergefstdir/$uttid.M.fst ]]; then
      >&2 echo -e "\nprepare-phn2let-traindata.sh: no file $mergefstdir/$uttid.M.fst. Skipping utterance."
      continue
    fi
    showprogress go
    refstring=`egrep "$uttid[ 	]" $reffile |
      cut -d' ' -f2- |
      sed -e 's/^[ \t]*/"/' -e 's/[ \t]*$/"/' -e 's/[ \t]\+/" "/g'`
    if [[ -z $refstring ]]; then
      >&2 echo -e "\nprepare-phn2let-traindata.sh: no reference string for $uttid. Skipping utterance."
      continue
    fi
    for rn in `seq 1 $nrand`; do
      echo $refstring
      fstrandgen --npath=1 --select=log_prob $mergefstdir/$uttid.M.fst |
	fstprint --osymbols=$engalphabet |
	reverse_randgenfstpaths.pl $uttid |
	cut -d' ' -f2- |
	sed -e 's/^[ \t]*/"/' -e 's/[ \t]*$/"/' -e 's/[ \t]\+/" "/g'
    done
  done ) > $carmeltraintxt.$ip &
done
wait

cat $carmeltraintxt.*
rm -f $trainids.* $carmeltraintxt.*
showprogress end
