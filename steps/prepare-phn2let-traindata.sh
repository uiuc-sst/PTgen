#!/bin/bash

# Emit training data for carmel ($carmeltraintxt, Exp/uzbek/carmel/training.txt).

. $INIT_STEPS

set -e

[ -s $trainids ] || { >&2 echo "$0: missing or empty training file $trainids. Aborting."; exit 1; }

reffile=$EXPLOCAL/ref_train_text
for L in ${TRAIN_LANG[@]}; do
	[ -s $TRANSDIR/$L/ref_train ] || { >&2 echo "$0: \$TRAIN_LANG $TRAIN_LANG includes $L, but $TRANSDIR/$L/ref_train is empty. Aborting."; exit 1; }
	cat $TRANSDIR/$L/ref_train
done > $reffile
[ -s $reffile ] || { >&2 echo "$0: made empty $reffile, so skipping all utterances. No training data. Aborting."; exit 1; }

if [[ -n $mcasr ]]; then
  >&2 echo "$(basename $0): converting IPA phones to MCASR phone-indexes."
  # Convert IPA phones to mcasr phone-indexes.
  mcasr-phone2index.rb < $reffile > $reffile.tmp
  mv -f $reffile.tmp $reffile
fi

showprogress init 20 "Preparing training data for carmel"

# Without multithreading, this stage would take 60 to 70% of run.sh's time.  (Carmel is most of the rest.)

# nLOTS is way more than $nparallel, but less than split's limit of 100 (or use split -a).
# Better might be a precise value like $nparallel * $nrand,
# or parallelizing the inner $nrand loop as well as the outer $nLOTS loop.
nLOTS=98
rm -f $trainids.* $carmeltraintxt.* # Just in case old temporary files were still there.
split --numeric-suffixes=1 -n r/$nLOTS $trainids $trainids.
for ip in $(seq -w 1 $nLOTS); do
  [ -s $trainids.$ip ] || { >&2 echo -e "\n$0: made empty split-file $trainids.$ip. Aborting."; exit 1; }
done

for ip in $(seq -w 1 $nLOTS); do
  ( while read uttid; do
    if [[ ! -s $mergefstdir/$uttid.M.fst ]]; then
      >&2 echo -e "\n$(basename $0): skipping utterance with empty $mergefstdir/$uttid.M.fst."
      continue
    fi
    # When M.fst is large, this test is faster than fstinfo M.fst | grep "# of arcs" == "0".
    # Almost as fast: if $(fstprint M.fst) == "0".
    if [[ $(< $mergefstdir/$uttid.M.fst.txt) == "0" ]]; then
      # fstrandgen below would output nothing useful.
      >&2 echo -e "\n$(basename $0): skipping utterance with null $mergefstdir/$uttid.M.fst."
      continue
    fi

    showprogress go
    # Grepping $reffile 98x is quadratic, thus slow.
    # Todo: replace it with how mergetxt.sh uses makeHash.rb.
    #
    # Yes, that regex includes a hardcoded tab.
    refstring=$(egrep "$uttid[ 	]" $reffile |
      cut -d' ' -f2- |
      sed -e 's/^[ \t]*/"/' -e 's/[ \t]*$/"/' -e 's/[ \t]\+/" "/g')
    if [[ -z $refstring ]]; then
      # Don't complain.  # >&2 echo -e "\n$(basename $0): skipping utterance lacking a reference string, $uttid."
      continue
    fi

    # todo: instead of the loop, it would be faster to fstrandgen --npath=$nrand,
    # and interleave its outputs with copies of $refstring.
    for rn in $(seq 1 $nrand); do
      echo $refstring
      fstrandgen --npath=1 --select=log_prob $mergefstdir/$uttid.M.fst |
	fstprint --osymbols=$engalphabet |
	reverse_randgenfstpaths.pl $uttid |
	cut -d' ' -f2- |
	sed -e 's/^[ \t]*/"/' -e 's/[ \t]*$/"/' -e 's/[ \t]\+/" "/g'
    done
  done
  ) < $trainids.$ip > $carmeltraintxt.$ip &
done
wait

cat $carmeltraintxt.*
rm -f $trainids.* $carmeltraintxt.* # Clean up temporary files.
showprogress end
