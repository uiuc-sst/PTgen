#!/bin/bash
# Script to build and evaluate probabilistic transcriptions.
#
# This script is split into multiple stages (1 - 15).
# Resume execution at a particular stage by defining the variable $startstage.

SRCDIR="$(dirname "$0")/steps"
UTILDIR="$(dirname "$0")/util"

export INIT_STEPS=$SRCDIR/init.sh
. $INIT_STEPS

# config.sh is in the local directory, which might not be the same as that of run.sh.
if [[ -s config.sh ]]; then
  . config.sh
  export PATH=$PATH:$OPENFSTDIR:$CARMELDIR:$KALDIDIR
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$OPENFSTLIB1:$OPENFSTLIB2 # for libfstscript.so and libfst.so
else
  : # No config.sh, but that's okay if binaries are already in $PATH.
fi

if hash compute-wer 2>/dev/null; then
  : # found compute-wer
else
  read -p "Enter the Kaldi directory containing compute-wer: " KALDIDIR
  # Typical values:
  # /ws/rz-cl-2/hasegawa/xyang45/work/kaldi-trunk/src/bin
  # /r/lorelei/kaldi/kaldi-trunk/src/bin
  # Append this value, without erasing any previous values.
  echo "KALDIDIR=\"$KALDIDIR\"" >> config.sh
fi

if hash carmel 2>/dev/null; then
  :
else
  read -p "Enter the directory containing carmel: " CARMELDIR
  # Typical values:
  # /r/lorelei/bin-carmel/linux64
  # $HOME/carmel/linux64
  echo "CARMELDIR=\"$CARMELDIR\"" >> config.sh
fi

if hash fstcompile 2>/dev/null; then
  :
else
  read -p "Enter the directory containing fstcompile and other OpenFST programs (/foo/bar/.../bin/.libs): " OPENFSTDIR
  # Typical values:
  # /ws/rz-cl-2/hasegawa/amitdas/corpus/ws15-pt-data/data/rsloan/openfst-1.5.0/src/bin/.libs
  echo "OPENFSTDIR=\"$OPENFSTDIR\"" >> config.sh
  # Expect to find libfstscript.so and libfst.so relative to OPENFSTDIR.
  # /ws/rz-cl-2/hasegawa/amitdas/corpus/ws15-pt-data/data/rsloan/openfst-1.5.0/src/bin/.libs becomes
  # /ws/rz-cl-2/hasegawa/amitdas/corpus/ws15-pt-data/data/rsloan/openfst-1.5.0/src/lib/.libs and
  # /ws/rz-cl-2/hasegawa/amitdas/corpus/ws15-pt-data/data/rsloan/openfst-1.5.0/src/script/.libs
  OPENFSTLIB1=$(echo "$OPENFSTDIR" | sed 's_bin/.libs$_lib/.libs_')
  OPENFSTLIB2=$(echo "$OPENFSTDIR" | sed 's_bin/.libs$_script/.libs_')
  echo "OPENFSTLIB1=\"$OPENFSTLIB1\"" >> config.sh
  echo "OPENFSTLIB2=\"$OPENFSTLIB2\"" >> config.sh
fi

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$OPENFSTLIB1:$OPENFSTLIB2 # for libfstscript.so and libfst.so
export PATH=$PATH:$SRCDIR:$OPENFSTDIR:$CARMELDIR:$KALDIDIR

if [[ ! -d $DATA ]]; then
  echo "Missing DATA directory $DATA. Check $1."; exit 1
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
	showprogress init 1 "Processing transcripts"
	for L in "${ALL_LANGS[@]}"; do
		if [[ -n $rmprefix ]]; then
			prefixarg="--rmprefix $rmprefix"
		fi
		preprocess_turker_transcripts.pl --multiletter $engdict $prefixarg < $TURKERTEXT/${L}/batchfile
		showprogress go
	done > $transcripts
	showprogress end
else
	usingfile "$transcripts" "processed transcripts"
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
	>&2 echo "Done."
else
	usingfile $simfile "transcript similarity scores"
fi

## STAGE 3 ##
# Prepare data lists
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	>&2 echo -n "Splitting training/test data for parallel jobs... "
	datatype='train' create-datasplits.sh $1
	datatype='dev'   create-datasplits.sh $1
#	datatype='test'  create-datasplits.sh $1
	datatype='adapt' create-datasplits.sh $1
	>&2 echo "Done."
else
	usingfile "$(dirname "$splittestids")" "test & train ID lists in"
fi

## STAGE 4 ##
# Merge text from crowd workers
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	mergetxt.sh $1
else
	usingfile $mergedir "merged transcripts in"
fi

## STAGE 5 ##
# Convert merged text into merged FST sausage-style structures
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	mergefst.sh $1
else
	usingfile "$mergedir" "merged transcript FSTs in"
fi

## STAGE 6 ##
# Initialize the phone-2-letter model (P)
((stage++))
if [[ $startstage -le $stage && "$TESTTYPE" != "eval" && $stage -le $endstage ]]; then
	>&2 echo -n "Creating untrained phone-2-letter model ($Pstyle style)... "
	mkdir -p "$(dirname "$initcarmel")"
	create-initcarmel.pl `echo $carmelinitopt` $phnalphabet $engalphabet $delimsymbol > $initcarmel
	>&2 echo "Done."
else
	usingfile "$initcarmel" "untrained phone-2-letter model"
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
	usingfile "$carmeltraintxt" "training text for phone-2-letter model"
fi

## STAGE 8 ##
# EM-train P
((stage++))
if [[ $startstage -le $stage && "$TESTTYPE" != "eval" && $stage -le $endstage ]]; then
	>&2 echo -n "Training phone-2-letter model (see $tmpdir/carmelout)... "
	hash carmel 2>/dev/null || { echo >&2 "Missing program 'carmel'.  Aborting."; exit 1; }
	carmel -\? --train-cascade -t -f 1 -M 20 -HJ $carmeltraintxt $initcarmel 2>&1 \
		| tee $tmpdir/carmelout | awk '/^i=|^Computed/ {printf "."; fflush (stdout)}' >&2
	# From $CARMELDIR.
	# If "carmel" is not found, no error is printed!
	# It just leaves "./run.sh: line 138: carmel: command not found"
	# in /tmp/run.sh-29085.dir/carmelout.
	>&2 echo "Done."
else
	usingfile "$initcarmel.trained" "trained phone-2-letter model"
fi


## STAGE 9 ##
# Represent P as an OpenFst style FST
# Optionally, scale weights in P with $Pscale
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	if [[ -z $Pscale ]]; then
		Pscale=1
	fi
	>&2 echo -n "Creating P (phone-2-letter FST) in openFST format [PSCALE=$Pscale]... "
	convert-carmel-to-fst.pl < ${initcarmel}.trained \
		| sed -e 's/e\^-\([0-9]*\)\..*/1.00e-\1/g' | convert-prob-to-neglog.pl \
		| scale-FST-weights.pl $Pscale \
		| fixp2let.pl "$disambigdel" "$disambigins" "$phneps" "$leteps" \
		| tee $tmpdir/trainedp2let.fst.txt \
		| fstcompile --isymbols=$phnalphabet --osymbols=$engalphabet  > $Pfst
	>&2 echo "Done."
else
	usingfile "$Pfst" "P (phone-2-letter model) FST"
fi

## STAGE 10 ##
# Prepare the language model FST, G
# Optionally, scale weights in G with $Gscale
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	if [[ -z $Gscale ]]; then
		Gscale=1
	fi
	>&2 echo -n "Creating G (phone-model) FST with disambiguation symbols [GSCALE=$Gscale]... "
	mkdir -p "$(dirname "$Gfst")"
#	>&2 echo -n " $phnalphabet $phnalphabet $phonelm zxcv"
	fstprint --isymbols=$phnalphabet --osymbols=$phnalphabet $phonelm \
		| addloop.pl "$disambigdel" "$disambigins" \
		| scale-FST-weights.pl $Gscale \
		| fstcompile --isymbols=$phnalphabet --osymbols=$phnalphabet \
		| fstarcsort --sort_type=olabel > $Gfst
	>&2 echo "Done."
else
	usingfile "$Gfst" "G (phone language model) FST"
fi

## STAGE 11 ##
# Create a prior over letters and represent as an FST, L
# Optionally, scale weights in L with $Lscale
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	if [[ -z $Lscale ]]; then
		Lscale=1
	fi
	>&2 echo -n "Creating L (letter statistics FST) [LSCALE=$Lscale]... "
	mkdir -p "$(dirname "$Lfst")"
	create-letpriorfst.pl $mergedir $priortrainfile \
		| scale-FST-weights.pl $Lscale \
		| fstcompile --osymbols=$engalphabet --isymbols=$engalphabet - \
		| fstarcsort --sort_type=ilabel - > $Lfst
	>&2 echo "Done."
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
	>&2 echo -n "Creating TPL and GTPL FSTs... "
	mkdir -p "$(dirname "$TPLfst")"
	fstcompose $Pfst $Lfst | fstcompose $Tfst - | fstarcsort --sort_type=olabel \
		| tee $TPLfst | fstcompose $Gfst - | fstarcsort --sort_type=olabel > $GTPLfst
	>&2 echo "Done."
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
	if [[ -z $Mscale ]]; then
		Mscale=1
	fi
	>&2 echo -n "Decoding lattices $msgtext [MSCALE=$Mscale]"
	mkdir -p $decodelatdir
	decode_PTs.sh $1
	#>&2 echo "Done."
else
	usingfile "$decodelatdir" "decoded lattices in"
fi

## STAGE 15 ##
# Evaluate the GTPLM lattices, stand-alone
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	if [[ -n $decode_for_adapt ]]; then
		>&2 echo "Not evaluating PTs (adaptation mode)."
	else
		evaluate_PTs.sh $1 | tee $evaloutput >&2
	fi
else
	>&2 echo "Stage 15: nothing to do."
fi

if [[ -z $debug ]]; then
	rm -rf $tmpdir
fi
