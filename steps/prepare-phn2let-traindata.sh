#!/bin/bash

. $INIT_STEPS

# Exit if there is any error.
set -e

[ -s $trainids ] || { >&2 echo "$0: missing or empty training file $trainids. Aborting."; exit 1; }

reffile=$EXPLOCAL/ref_train_text
for L in ${TRAIN_LANG[@]}; do
	[ -s $TRANSDIR/$L/ref_train ] || { >&2 echo "$0: \$TRAIN_LANG $TRAIN_LANG includes $L, but $TRANSDIR/$L/ref_train is empty. Aborting."; exit 1; }
	cat $TRANSDIR/$L/ref_train
done > $reffile

[ -s $reffile ] || { >&2 echo "$0: made empty $reffile, so skipping all utterances.  No training data."; exit 1; }

# Only for mcasr!
if true; then
  >&2 echo "`basename $0`: for MCASR, converting IPA phones to mcasr phone-indexes."
  # Convert IPA phones to mcasr phone-indexes.
  rm -f $reffile.tmp
  mv $reffile $reffile.tmp
  mcasr-phone2index.rb < $reffile.tmp > $reffile
  rm -f $reffile.tmp
fi

showprogress init 60 "Preparing training data"

# Without parallelizing, this stage would take 60 to 70% of run.sh's time.  (Carmel is most of the rest.)

# nLOTS is way more than $nparallel, but less than split's limit of 100 (or use split -a).
# Better might be a precise value like $nparallel * $nrand,
# or parallelizing the inner $nrand loop as well as the outer $nLOTS loop.
nLOTS=98
rm -f $trainids.* $carmeltraintxt.* # Just in case old temporary files were still there.
split --numeric-suffixes=1 -n r/$nLOTS $trainids $trainids.

for ip in `seq -w 1 $nLOTS`; do
  [ -s $trainids.$ip ] || { >&2 echo -e "\n$0: empty split-file $trainids.$ip. Aborting."; exit 1; }
	
  ( while read uttid; do
    if [[ ! -s $mergefstdir/$uttid.M.fst ]]; then
      >&2 echo -e "\n`basename $0`: skipping utterance with empty $mergefstdir/$uttid.M.fst."
      continue
    fi
    showprogress go
    refstring=`egrep "$uttid[ 	]" $reffile |
      cut -d' ' -f2- |
      sed -e 's/^[ \t]*/"/' -e 's/[ \t]*$/"/' -e 's/[ \t]\+/" "/g'`
    if [[ -z $refstring ]]; then
      >&2 echo -e "\n`basename $0`: skipping utterance lacking a reference string, $uttid."
      continue
    fi
    for rn in `seq 1 $nrand`; do
      echo $refstring
      #   --max_length: type = int32, default = 2147483647
      #    Number of paths to generate
      fstrandgen --npath=1 --select=log_prob $mergefstdir/$uttid.M.fst |
	fstprint --osymbols=$engalphabet |
	reverse_randgenfstpaths.pl $uttid |
	cut -d' ' -f2- |
	sed -e 's/^[ \t]*/"/' -e 's/[ \t]*$/"/' -e 's/[ \t]\+/" "/g'
    done
  done < $trainids.$ip > $carmeltraintxt.$ip
  ) &
done
wait

cat $carmeltraintxt.*
rm -f $trainids.* $carmeltraintxt.* # Clean up temporary files.
showprogress end
