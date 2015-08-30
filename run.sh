#!/bin/bash
# Script to build probabilistic transcripts
# and evaluate them.
#
# This script is split into multiple stages (1 - 15).
# Execution can start at any particular stage by 
# defining the variable $startstage 

SRCDIR="$(dirname "$0")/steps"
UTILDIR="$(dirname "$0")/util"
export PATH=$PATH:$SRCDIR:$UTILDIR
export INIT_STEPS=$SRCDIR/init.sh

. $INIT_STEPS

if [[ ! -d $LISTDIR ||
	  ! -d $TRANSDIR ||
	  ! -d $TURKERTEXT ||
	  ! -s $langmap ||
	  ! -s $evalreffile ||
	  ! -s $engdict ||
	  ! -s $engalphabet ||
	  ! -s $phnalphabet ||
	  ! -s $phonelm ]]; then
	  echo "Missing or empty required files. Check settings."
	  exit 1
fi

mktmpdir

mkdir -p $EXPLOCAL
>&2 echo "Experiment directory: $EXPLOCAL"
cp "$1" $EXPLOCAL/settings

if [[ -z $startstage ]]; then
	startstage=1;
fi

## STAGE 1 ##
# Preprocessing transcripts obtained from crowd workers
stage=1
if [[ $startstage -le $stage ]]; then
	mkdir -p "$(dirname "$transcripts")"
	showprogress init 1 "Creating processed transcripts"
	for L in "${ALL_LANGS[@]}"; do
		preprocess_turker_transcripts.pl --multiletter $engdict < $TURKERTEXT/${L}/batchfile
		showprogress go
	done > $transcripts
	showprogress end "Done"
else
	usingfile "$transcripts" "Processed transcripts"
fi

## STAGE 2 ##
# Data filtering step
((stage++))
if [[ $startstage -le $stage ]]; then
	>&2 echo "Creating transcript similarity scores"
	mkdir -p "$(dirname "$simfile")"
	compute_turker_similarity $transcripts > $simfile
else
	usingfile $simfile "Transcript similarity scores"
fi

## STAGE 3 ##
# Data preparation
((stage++))
if [[ $startstage -le $stage ]]; then
	>&2 echo "Creating training/test data splits for parallel jobs"
	mkdir -p "$(dirname "$trainids")"
	createdataset train > $trainids
	mkdir -p "$(dirname "$testids")"
	createdataset dev > $testids
	mkdir -p "$(dirname "$adaptids")"
	createdataset adapt > $adaptids
	split -n r/$nparallel $testids  $tmpdir/split-test. 
	split -n r/$nparallel $trainids $tmpdir/split-train.
	split -n r/$nparallel $adaptids $tmpdir/split-adapt.
	mkdir -p "$(dirname "$splittestids")"
	mkdir -p "$(dirname "$splittrainids")"
	mkdir -p "$(dirname "$splitadaptids")"
	for i in `seq 1 $nparallel`; do
		mv `ls $tmpdir/split-test.* | head -1` ${splittestids}.$i
		mv `ls $tmpdir/split-train.* | head -1` ${splittrainids}.$i
		mv `ls $tmpdir/split-adapt.* | head -1` ${splitadaptids}.$i
	done
else
	usingfile "$(dirname "$splittestids")" "Test & Train ID lists in"
fi

## STAGE 4 ##
# Merging text from crowd workers
((stage++))
if [[ $startstage -le $stage ]]; then
	>&2 echo -n "Creating merged transcripts"
	mergetxt.sh $1
else
	usingfile $mergedir "Merged transcripts in"
fi


## STAGE 5 ##
# Creating merged FST sausage-style structures from merged text
((stage++))
if [[ $startstage -le $stage ]]; then
	>&2 echo -n "Creating merged transcript FSTs (unscaled)"
	mergefst.sh $1
else
	usingfile "$mergedir" "Merged transcript FSTs in"
fi

## STAGE 6 ##
# Creating a initialization for the phone-2-letter model (P)
((stage++))
if [[ $startstage -le $stage ]]; then
	>&2 echo -n "Creating untrained phone-2-letter model ($Pstyle style)"
	mkdir -p "$(dirname "$initcarmel")"
	create-initcarmel.pl `echo $carmelinitopt` $phnalphabet $engalphabet $delimsymbol > $initcarmel
	>&2 echo " Done"
else
	usingfile "$initcarmel" "Untrained phone-2-letter model"
fi

## STAGE 7 ##
# Creating training data to learn phone-2-letter mappings defined in P
((stage++))
if [[ $startstage -le $stage ]]; then
	>&2 echo "Creating carmel training data"
	for L in ${TRAIN_LANG[@]}; do
		cat $TRANSDIR/${L}/ref_train 
	done > $reffile
	prepare-phn2let-traindata.sh $1
else
	usingfile "$carmeltraintxt" "Training text for phone-2-letter model"
fi

## STAGE 8 ##
# EM training of P
((stage++))
if [[ $startstage -le $stage ]]; then
	>&2 echo -n "Starting carmel training (output in $tmpdir/carmelout) "
	carmel -\? --train-cascade -t -f 1 -M 20 -HJ $carmeltraintxt $initcarmel 2>&1 \
		| tee $tmpdir/carmelout | awk '/^i=|^Computed/ {printf "."; fflush (stdout)}' >&2
	>&2 echo "Done"
else
	usingfile "$initcarmel.trained" "Trained phone-2-letter model"
fi


## STAGE 9 ##
# Represent P as an OpenFst style FST
# Optionally, scale weights in P with $Pscale
((stage++))
if [[ $startstage -le $stage ]]; then
	>&2 echo -n "Creating P (phone-2-letter FST) in openFST format"
	if [[ -z $Pscale ]]; then
		Pscale=1
	fi
	>&2 echo -n " [PSCALE=$Pscale] ..."
	convert-carmel-to-fst.pl < ${initcarmel}.trained \
		| sed -e 's/e\^-\([0-9]*\)\..*/1.00e-\1/g' | convert-prob-to-neglog.pl \
		| scale-FST-weights.pl $Pscale \
		| fixp2let.pl "$disambigdel" "$disambigins" "$phneps" "$leteps" \
		| tee $tmpdir/trainedp2let.fst.txt \
		| fstcompile --isymbols=$phnalphabet --osymbols=$engalphabet  > $Pfst
	>&2 echo "Done"
else
	usingfile "$Pfst" "P (phone-2-letter model) FST"
fi

## STAGE 10 ##
# Preparing the language model FST, G
# Optionally, scale weights in G with $Gscale
((stage++))
if [[ $startstage -le $stage ]]; then
	>&2 echo -n "Creating G (phone-model) FST with disambiguation symbols"
	if [[ -z $Gscale ]]; then
		Gscale=1
	fi
	>&2 echo -n " [GSCALE=$Gscale] ..."

	mkdir -p "$(dirname "$Gfst")"
	fstprint --isymbols=$phnalphabet --osymbols=$phnalphabet $phonelm \
		| addloop.pl "$disambigdel" "$disambigins" \
		| scale-FST-weights.pl $Gscale \
		| fstcompile --isymbols=$phnalphabet --osymbols=$phnalphabet \
		| fstarcsort --sort_type=olabel > $Gfst
	>&2 echo "Done"
else
	usingfile "$Gfst" "G (Phone Language Model) FST"
fi

## STAGE 11 ##
# Creating a prior over letters and represent as an FST, L
# Optionally, scale weights in L with $Lscale
((stage++))
if [[ $startstage -le $stage ]]; then
	>&2 echo -n "Creating L (letter statistics FST)"
	if [[ -z $Lscale ]]; then
		Lscale=1
	fi
	>&2 echo -n " [LSCALE=$Lscale] ..."
	mkdir -p "$(dirname "$Lfst")"
	create-letpriorfst.pl $mergedir $priortrainfile \
		| scale-FST-weights.pl $Lscale \
		| fstcompile --osymbols=$engalphabet --isymbols=$engalphabet - \
		| fstarcsort --sort_type=ilabel - > $Lfst
	>&2 echo "Done"
else
	usingfile $Lfst "L (letter statistics FST)"
fi

## STAGE 12 ##
# Create an auxiliary FST, T, that restricts the number of 
# phone deletions and letter insertions, using tunable parameters
# Tnumdel and Tnumins
((stage++))
if [[ $startstage -le $stage ]]; then
	>&2 echo "Creating T (deletion/insertion limiting FST)..."
	create-delinsfst.pl $disambigdel $disambigins $Tnumdel $Tnumins < $phnalphabet \
		| fstcompile --osymbols=$phnalphabet --isymbols=$phnalphabet - > $Tfst
else
	usingfile $Tfst "T (deletion/insertion limiting FST)"
fi

## STAGE 13 ##
# Creating TPL and GTPL FSTs
((stage++))
if [[ $startstage -le $stage ]]; then
	>&2 echo "Creating TPL and GTPL fsts"
	mkdir -p "$(dirname "$TPLfst")"
	fstcompose $Pfst $Lfst | fstcompose $Tfst - | fstarcsort --sort_type=olabel \
		| tee $TPLfst | fstcompose $Gfst - | fstarcsort --sort_type=olabel > $GTPLfst
else
	usingfile "$GTPLfst" "GTPL FST"
fi

## STAGE 14 ##
# Decoding phase: create lattices for each merged utterance FST (M)
# both with (GTPLM) and without (TPLM) a language model
((stage++))
if [[ $startstage -le $stage ]]; then
	if [[ -n $makeTPLM && -n $makeGTPLM ]]; then
		msgtext="GTPLM and TPLM"
	elif [[ -n $makeTPLM ]]; then
		msgtext="TPLM"
	elif [[ -n $makeGTPLM ]]; then
		msgtext="GTPLM"
	fi
	>&2 echo -n "Creating decoded lattices $msgtext"
	if [[ -z $Mscale ]]; then
		Mscale=1
	fi
	>&2 echo " [MSCALE=$Mscale] "

	mkdir -p $decodelatdir
	decode_PTs.sh $1
else
	usingfile "$decodelatdir" "Decoded lattices in"
fi

## STAGE 15 ##
# Stand-alone evaluation of the GTPLM lattices
((stage++))
if [[ $startstage -le $stage ]]; then
	if [[ -n $decode_for_adapt ]]; then
		>&2 echo "Not evaluating PTs (adaptation mode)"
	else
		>&2 echo "Evaluating decoded lattices"
		evaluate_PTs.sh $1 | tee $evaloutput >&2
	fi
else
	>&2 echo "Nothing to do!"
fi

if [[ -z $debug ]]; then
	rm -rf $tmpdir
fi
