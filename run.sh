#!/bin/bash
# Script to build and evaluate probabilistic transcriptions.
#
# This script is split into multiple stages (1 - 15).
# Resume execution at a particular stage by defining the variable $startstage.

SRCDIR="$(dirname "$0")/steps"
UTILDIR="$(dirname "$0")/util"
OPENFSTDIR="/ws/rz-cl-2/hasegawa/amitdas/corpus/ws15-pt-data/data/rsloan/openfst-1.5.0/src/bin/.libs"
KALDIDIR="/ws/rz-cl-2/hasegawa/xyang45/work/kaldi-trunk/src/bin/"
CARMELDIR="/r/lorelei/bin-carmel/linux64" # todo: move this into a not-git config file
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/ws/rz-cl-2/hasegawa/amitdas/corpus/ws15-pt-data/data/rsloan/openfst-1.5.0/src/lib/.libs:/ws/rz-cl-2/hasegawa/amitdas/corpus/ws15-pt-data/data/rsloan/openfst-1.5.0/src/script/.libs # for libfstscript.so and libfst.so
export PATH=$PATH:$SRCDIR:$UTILDIR:$OPENFSTDIR:$CARMELDIR:$KALDIDIR
export INIT_STEPS=$SRCDIR/init.sh

. $INIT_STEPS

if [[ ! -d $ROOT ]]; then
  echo "Missing ROOT directory $ROOT. Check $1."; exit 1
fi
if [[ ! -d $LISTDIR ]]; then
  echo "Missing LISTDIR directory $LISTDIR. Check $1."; exit 1
fi
if [[ ! -d $TRANSDIR ]]; then
  echo "Missing TRANSDIR directory $TRANSDIR. Check $1."; exit 1
fi
if [[ ! -d $TURKERTEXT ]]; then
  echo "Missing TURKERTEXT directory $TURKERTEXT. Check $1."; exit 1
fi
if [[ ! -s $engdict ]]; then
  echo "Missing or empty engdict file $engdict. Check $1."; exit 1
fi
if [[ ! -s $engalphabet ]]; then
  echo "Missing or empty engalphabet file $engalphabet. Check $1."; exit 1
fi
if [[ ! -s $phnalphabet ]]; then
  echo "Missing or empty phnalphabet file $phnalphabet. Check $1."; exit 1
fi
if [[ ! -s $phonelm ]]; then
  echo "Missing or empty phonelm file $phonelm. Check $1."; exit 1
fi
# Unused: $langmap $evalreffile

mktmpdir

>&2 echo "Creating experiment directory $EXPLOCAL."
mkdir -p $EXPLOCAL
cp "$1" $EXPLOCAL/settings

if [[ -z $startstage ]]; then
	startstage=1;
fi

if [[ -z $endstage ]]; then
	endstage=1000; #large number
fi

if [[ $startstage -le 8 && 8 -le $endstage ]]; then
  hash carmel 2>/dev/null || { echo >&2 "Missing program 'carmel'.  Stage 8 would abort."; exit 1; }
fi
if [[ $startstage -le 15 && 15 -le $endstage ]]; then
  hash compute-wer 2>/dev/null || { echo >&2 "Missing program 'compute-wer'.  Stage 15 would abort."; exit 1; }
fi

## STAGE 1 ##
# Preprocess transcripts obtained from crowd workers
stage=1
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	mkdir -p "$(dirname "$transcripts")"
	showprogress init 1 "Creating processed transcripts... "
	for L in "${ALL_LANGS[@]}"; do
		if [[ -n $rmprefix ]]; then
			prefixarg="--rmprefix $rmprefix"
		fi
		preprocess_turker_transcripts.pl --multiletter $engdict $prefixarg < $TURKERTEXT/${L}/batchfile
		showprogress go
	done > $transcripts
	showprogress end "Done"
else
	usingfile "$transcripts" "Processed transcripts"
fi

## STAGE 2 ##
# Filter data
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	>&2 echo -n "Creating transcript similarity scores... "
	mkdir -p "$(dirname "$simfile")"
	grep "#" $transcripts > $tmpdir/transcripts 
	mv $tmpdir/transcripts $transcripts
	compute_turker_similarity $transcripts > $simfile
	>&2 echo " Done"
else
	usingfile $simfile "Transcript similarity scores"
fi

## STAGE 3 ##
# Prepare data lists
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	>&2 echo "Splitting training/test data for parallel jobs... "
	datatype='train' create-datasplits.sh $1
	datatype='dev'   create-datasplits.sh $1
#	datatype='test'  create-datasplits.sh $1
	datatype='adapt' create-datasplits.sh $1
else
	usingfile "$(dirname "$splittestids")" "Test & Train ID lists in"
fi

## STAGE 4 ##
# Merge text from crowd workers
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	>&2 echo -n "Merging transcripts... "
	mergetxt.sh $1
else
	usingfile $mergedir "Merged transcripts in"
fi

## STAGE 5 ##
# Convert merged text into merged FST sausage-style structures
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	>&2 echo -n "Merging transcript FSTs (unscaled)... "
	mergefst.sh $1
else
	usingfile "$mergedir" "Merged transcript FSTs in"
fi

## STAGE 6 ##
# Initialize the phone-2-letter model (P)
((stage++))
if [[ $startstage -le $stage && "$TESTTYPE" != "eval" && $stage -le $endstage ]]; then
	>&2 echo -n "Creating untrained phone-2-letter model ($Pstyle style)... "
	mkdir -p "$(dirname "$initcarmel")"
	create-initcarmel.pl `echo $carmelinitopt` $phnalphabet $engalphabet $delimsymbol > $initcarmel
	>&2 echo " Done"
else
	usingfile "$initcarmel" "Untrained phone-2-letter model"
fi

## STAGE 7 ##
# Create training data to learn phone-2-letter mappings defined in P
((stage++))
if [[ $startstage -le $stage && "$TESTTYPE" != "eval" && $stage -le $endstage ]]; then
	>&2 echo "Creating carmel training data... "
	for L in ${TRAIN_LANG[@]}; do
		cat $TRANSDIR/${L}/ref_train 
	done > $reffile
	prepare-phn2let-traindata.sh $1
else
	usingfile "$carmeltraintxt" "Training text for phone-2-letter model"
fi

## STAGE 8 ##
# EM-train P
((stage++))
if [[ $startstage -le $stage && "$TESTTYPE" != "eval" && $stage -le $endstage ]]; then
	hash carmel 2>/dev/null || { echo >&2 "Missing program 'carmel'.  Aborting."; exit 1; }
	>&2 echo -n "Starting carmel training (output in $tmpdir/carmelout)... "
	carmel -\? --train-cascade -t -f 1 -M 20 -HJ $carmeltraintxt $initcarmel 2>&1 \
		| tee $tmpdir/carmelout | awk '/^i=|^Computed/ {printf "."; fflush (stdout)}' >&2
	# From $CARMELDIR.
	# If "carmel" is not found, no error is printed!
	# It just leaves "./run.sh: line 138: carmel: command not found"
	# in /tmp/run.sh-29085.dir/carmelout.
	>&2 echo "Done"
else
	usingfile "$initcarmel.trained" "Trained phone-2-letter model"
fi


## STAGE 9 ##
# Represent P as an OpenFst style FST
# Optionally, scale weights in P with $Pscale
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	>&2 echo -n "Creating P (phone-2-letter FST) in openFST format... "
	if [[ -z $Pscale ]]; then
		Pscale=1
	fi
	>&2 echo -n " [PSCALE=$Pscale] ... "
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
# Prepare the language model FST, G
# Optionally, scale weights in G with $Gscale
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	>&2 echo -n "Creating G (phone-model) FST with disambiguation symbols... "
	if [[ -z $Gscale ]]; then
		Gscale=1
	fi
	>&2 echo -n " [GSCALE=$Gscale] ... "

	mkdir -p "$(dirname "$Gfst")"
#	>&2 echo -n " $phnalphabet $phnalphabet $phonelm zxcv"
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
# Create a prior over letters and represent as an FST, L
# Optionally, scale weights in L with $Lscale
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	>&2 echo -n "Creating L (letter statistics FST)... "
	if [[ -z $Lscale ]]; then
		Lscale=1
	fi
	>&2 echo -n " [LSCALE=$Lscale] ... "
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
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	>&2 echo "Creating T (deletion/insertion limiting FST)... "
	create-delinsfst.pl $disambigdel $disambigins $Tnumdel $Tnumins < $phnalphabet \
		| fstcompile --osymbols=$phnalphabet --isymbols=$phnalphabet - > $Tfst
else
	usingfile $Tfst "T (deletion/insertion limiting FST)"
fi

## STAGE 13 ##
# Create TPL and GTPL FSTs
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	>&2 echo "Creating TPL and GTPL fsts... "
	mkdir -p "$(dirname "$TPLfst")"
	fstcompose $Pfst $Lfst | fstcompose $Tfst - | fstarcsort --sort_type=olabel \
		| tee $TPLfst | fstcompose $Gfst - | fstarcsort --sort_type=olabel > $GTPLfst
else
	usingfile "$GTPLfst" "GTPL FST"
fi

## STAGE 14 ##
# Decoding: create lattices for each merged utterance FST (M)
# both with (GTPLM) and without (TPLM) a language model
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	if [[ -n $makeTPLM && -n $makeGTPLM ]]; then
		msgtext="GTPLM and TPLM"
	elif [[ -n $makeTPLM ]]; then
		msgtext="TPLM"
	elif [[ -n $makeGTPLM ]]; then
		msgtext="GTPLM"
	fi
	>&2 echo -n "Creating decoded lattices $msgtext... "
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
# Evaluate the GTPLM lattices, stand-alone
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	if [[ -n $decode_for_adapt ]]; then
		>&2 echo "Not evaluating PTs (adaptation mode)... "
	else
		>&2 echo "Evaluating decoded lattices"
		evaluate_PTs.sh $1 | tee $evaloutput >&2
	fi
else
	>&2 echo "Stage 15: nothing to do."
fi

if [[ -z $debug ]]; then
	rm -rf $tmpdir
fi
