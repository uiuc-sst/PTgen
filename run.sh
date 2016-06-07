#!/bin/bash
# Script to build and evaluate probabilistic transcriptions.
#
# This script is split into 15 stages.
# To resume execution at a particular stage,
# set the variable $startstage in the settings file.
#
# Although stages 9-13 are very fast, we keep them as separate stages
# for tuning hyper-parameters such as # of phone deletions/insertions,
# and because they *are* functionally distinct.

SCRIPT="$(readlink --canonicalize-existing "$0")"
SCRIPTPATH="$(dirname "$SCRIPT")"
SRCDIR="$SCRIPTPATH/steps"
UTILDIR="$SCRIPTPATH/util"

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
export PATH=$PATH:$SRCDIR:$UTILDIR:$OPENFSTDIR:$CARMELDIR:$KALDIDIR

if [[ ! -d $DATA ]]; then
  if [ -z ${DATA_URL+x} ]; then
    echo "Missing DATA directory $DATA, and no \$DATA_URL to get it from. Check $1."; exit 1
  fi
  tarball=`basename $DATA_URL`
  # $DATA_URL is e.g. http://www.ifp.illinois.edu/something/foo.tgz
  # $tarball is foo.tgz
  if [ -f $tarball ]; then
    echo "Found tarball $tarball, previously downloaded from $DATA_URL."
  else
    echo "Downloading $DATA_URL."
    wget --no-verbose $DATA_URL || exit 1
  fi
  # Check the name of the tarball's first file (probably a directory).  Strip the trailing slash.
  tarDir=`tar tvf $tarball | head -1 | awk '{print $NF}' | sed -e 's_\/$__'`
  if [[ "$tarDir" != "$DATA" ]]; then
    echo "Tarball $tarball contains $tarDir, not \$DATA $DATA."; exit 1
  fi
  echo "Extracting $tarball, hopefully into \$DATA $DATA."
  tar xzf $tarball || ( echo "Unexpected contents in $tarball.  Aborting."; exit 1 )
  if [[ ! -d $DATA ]]; then
    echo "Still missing DATA directory $DATA. Check $DATA_URL and $1."; exit 1
  fi
  echo "Installed \$DATA $DATA."
fi
if [[ ! -d $DATA ]]; then
  echo "Still missing DATA directory $DATA. Check $DATA_URL and $1."; exit 1
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
	startstage=1
fi
if [[ -z $endstage ]]; then
	endstage=99999
fi

if [[ $startstage -le 8 && 8 -le $endstage ]]; then
  hash carmel 2>/dev/null || { echo >&2 "Missing program 'carmel'.  Stage 8 would abort."; exit 1; }
fi
if [[ $startstage -le 15 && 15 -le $endstage ]]; then
  hash compute-wer 2>/dev/null || { echo >&2 "Missing program 'compute-wer'.  Stage 15 would abort."; exit 1; }
fi

## STAGE 1 ##
# Preprocess transcripts from crowd workers.
#
# Reads the files $engdict and $TURKERTEXT/*/batchfile, where * covers $ALL_LANGS.
# May use the variable $rmprefix. 
# Creates the file $transcripts.
SECONDS=0
stage=1
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	mkdir -p "$(dirname "$transcripts")"
	showprogress init 1 "Preprocessing transcripts"
	for L in "${ALL_LANGS[@]}"; do
		if [[ -n $rmprefix ]]; then
			prefixarg="--rmprefix $rmprefix"
		fi
		preprocess_turker_transcripts.pl --multiletter $engdict $prefixarg < $TURKERTEXT/$L/batchfile
		showprogress go
	done > $transcripts
	showprogress end
	echo "Stage 1 took" $SECONDS "seconds."; SECONDS=0
else
	usingfile "$transcripts" "preprocessed transcripts"
fi

## STAGE 2 ##
# Filter data.
#
# Modifies the file $transcripts.
# Creates the file $simfile.
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	>&2 echo -n "Creating transcript similarity scores... "
	mkdir -p "$(dirname "$simfile")"
	grep "#" $transcripts > $tmpdir/transcripts 
	mv $tmpdir/transcripts $transcripts
	compute_turker_similarity < $transcripts > $simfile
	>&2 echo "Done."
	echo "Stage 2 took" $SECONDS "seconds."; SECONDS=0
else
	usingfile $simfile "transcript similarity scores"
fi

## STAGE 3 ##
# Prepare data lists.
#
# Via $langmap, expands variable $TRAIN_LANG's abbreviations into full language names.
# Reads each $LISTDIR/language_name/{train, dev, test}.
# Creates the files $trainids, $testids, $adaptids.
# Splits those files into parts {$splittrainids, $splittestids, $splitadaptids}.xxx, where xxx is numbers.
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	case $TESTTYPE in
	dev | eval)
	  ;;
	*)
	  >&2 echo "\$TESTTYPE $TESTTYPE must be either 'dev' or 'eval'.  Check $1."; exit 1
	  ;;
	esac
	>&2 echo -n "Splitting training/test data into parallel jobs... "
	datatype='train'   create-datasplits.sh $1
	datatype='adapt'   create-datasplits.sh $1
	datatype=$TESTTYPE create-datasplits.sh $1
	>&2 echo "Done."
	echo "Stage 3 took" $SECONDS "seconds."; SECONDS=0
else
	usingfile "$(dirname "$splittestids")" "test & train ID lists in"
fi

## STAGE 4 ##
# Merge text from crowd workers.
#
# Creates file $aligndist.
# Creates directory $mergedir and files therein:
# language_xxx.txt, part-x-language_xxx.txt.
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	mergetxt.sh $1
	echo "Stage 4 took" $SECONDS "seconds."; SECONDS=0
else
	usingfile $mergedir "merged transcripts in"
fi

## STAGE 5 ##
# Convert merged text into merged FST sausages.
#
# Uses variable $alignertofstopt.
# Reads the files in the directory $mergedir.
# Reads the files {$splittrainids, $splittestids, $splitadaptids}.xxx.
# Creates the files $mergefstdir/*.M.fst.txt.
# Creates the files $mergefstdir/*.M.fst.
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	mergefst.sh $1
	echo "Stage 5 took" $SECONDS "seconds."; SECONDS=0
else
	usingfile "$mergedir" "merged transcript FSTs in"
fi

## STAGE 6 ##
# Initialize the phone-2-letter model, P.
#
# Uses variables $carmelinitopt and $delimsymbol.
# Reads files $phnalphabet and $engalphabet.
# Creates file $initcarmel.
((stage++))
if [[ $startstage -le $stage && "$TESTTYPE" != "eval" && $stage -le $endstage ]]; then
	>&2 echo -n "Creating untrained phone-2-letter model ($Pstyle style)... "
	mkdir -p "$(dirname "$initcarmel")"
	create-initcarmel.pl `echo $carmelinitopt` $phnalphabet $engalphabet $delimsymbol > $initcarmel
	>&2 echo "Done."
	echo "Stage 6 took" $SECONDS "seconds."; SECONDS=0
else
	usingfile "$initcarmel" "untrained phone-2-letter model"
fi

## STAGE 7 ##
# Create training data to learn the phone-2-letter mappings defined in P.
#
# Reads files $TRANSDIR/$TRAIN_LANG[*]/ref_train
# Creates temporary file $reffile.
# Creates file $carmeltraintxt.
((stage++))
if [[ $startstage -le $stage && "$TESTTYPE" != "eval" && $stage -le $endstage ]]; then
	>&2 echo "Creating carmel training data... "
	prepare-phn2let-traindata.sh $1 > $carmeltraintxt
	echo "Stage 7 took" $SECONDS "seconds."; SECONDS=0
else
	usingfile "$carmeltraintxt" "training text for phone-2-letter model"
fi

## STAGE 8 ##
# EM-train P.
#
# Reads files $carmeltraintxt and $initcarmel.
# Creates logfile $tmpdir/carmelout.
# Creates file $initcarmel.trained.
((stage++))
if [[ $startstage -le $stage && "$TESTTYPE" != "eval" && $stage -le $endstage ]]; then
	>&2 echo -n "Training phone-2-letter model (see $tmpdir/carmelout)..."
	hash carmel 2>/dev/null || { >&2 echo "Missing program 'carmel'.  Aborting."; exit 1; }
	carmel -\? --train-cascade -t -f 1 -M 20 -HJ $carmeltraintxt $initcarmel 2>&1 \
		| tee $tmpdir/carmelout | awk '/^i=|^Computed/ {printf "."; fflush (stdout)}' >&2
	>&2 echo " Done."

	# Todo: sanity check for carmel's training.
	#
	# Read $initcarmel.trained.
	# Split each line at whitespace into tokens.
	# Parse the last token into a float.
	# Sort the floats.
	# Discard the first 10% and last 10%.
	# Compute the standard deviation.
	# If that's less than some threshold, warn that carmel's training was insufficient.
	#
	# Or, more elaborately:
	# Collect each line's third token, the entropy per symbol.
	# If that's close to log(number of maps, e.g. 56),
	# then that symbol's probabilities are too uniform,
	# i.e., that symbol was insufficiently trained.

	echo "Stage 8 took" $SECONDS "seconds."; SECONDS=0
else
	usingfile "$initcarmel.trained" "trained phone-2-letter model"
fi

## STAGE 9 ##
# Convert P to an OpenFst-style FST.
#
# Reads file $initcarmel.trained.
# Uses variables $disambigdel, $disambigins, $phneps, and $leteps.
# May use variable $Pscale, to scale P's weights.
# Creates logfile $tmpdir/trainedp2let.fst.txt.
# Creates file $Pfst.
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
	echo "Stage 9 took" $SECONDS "seconds."; SECONDS=0
else
	usingfile "$Pfst" "P (phone-2-letter model) FST"
fi

## STAGE 10 ##
# Prepare the language model FST, G.
#
# Reads files $phnalphabet and $phonelm.
# Uses variables $disambigdel $disambigins
# May use variable $Gscale, to scale G's weights.
# Creates file $Gfst.
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	if [[ -z $Gscale ]]; then
		Gscale=1
	fi
	>&2 echo -n "Creating G (phone-model) FST with disambiguation symbols [GSCALE=$Gscale]... "
	mkdir -p "$(dirname "$Gfst")"
	fstprint --isymbols=$phnalphabet --osymbols=$phnalphabet $phonelm \
		| addloop.pl "$disambigdel" "$disambigins" \
		| scale-FST-weights.pl $Gscale \
		| fstcompile --isymbols=$phnalphabet --osymbols=$phnalphabet \
		| fstarcsort --sort_type=olabel > $Gfst
	>&2 echo "Done."
	echo "Stage 10 took" $SECONDS "seconds."; SECONDS=0
else
	usingfile "$Gfst" "G (phone language model) FST"
fi

## STAGE 11 ##
# Create a prior over letters and represent as an FST, L.
#
# Reads files in directory $mergedir.
# Reads files $trainids and $engalphabet.
# May use variable $Lscale, to scale L's weights.
# Creates file $Lfst.
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	if [[ -z $Lscale ]]; then
		Lscale=1
	fi
	>&2 echo -n "Creating L (letter statistics FST) [LSCALE=$Lscale]... "
	mkdir -p "$(dirname "$Lfst")"
	create-letpriorfst.pl $mergedir $trainids \
		| scale-FST-weights.pl $Lscale \
		| fstcompile --osymbols=$engalphabet --isymbols=$engalphabet - \
		| fstarcsort --sort_type=ilabel - > $Lfst
	>&2 echo "Done."
	echo "Stage 11 took" $SECONDS "seconds."; SECONDS=0
else
	usingfile $Lfst "L (letter statistics FST)"
fi

## STAGE 12 ##
# Create an auxiliary FST T that restricts the number of phone deletions
# and letter insertions, through tunable parameters Tnumdel and Tnumins.
#
# Uses variables $disambigdel $disambigins $Tnumdel $Tnumins.
# Creates file $Tfst.  
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	>&2 echo "Creating T (deletion/insertion limiting FST)... "
	create-delinsfst.pl $disambigdel $disambigins $Tnumdel $Tnumins < $phnalphabet \
		| fstcompile --osymbols=$phnalphabet --isymbols=$phnalphabet - > $Tfst
	>&2 echo "Done."
	echo "Stage 12 took" $SECONDS "seconds."; SECONDS=0
else
	usingfile $Tfst "T (deletion/insertion limiting FST)"
fi

## STAGE 13 ##
# Create TPL and GTPL FSTs.
#
# Reads files $Lfst $Tfst $Gfst.
# Creates files $TPLfst and $GTPLfst.
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	>&2 echo -n "Creating TPL and GTPL FSTs... "
	mkdir -p "$(dirname "$TPLfst")"
	fstcompose $Pfst $Lfst | fstcompose $Tfst - | fstarcsort --sort_type=olabel \
		 | tee $TPLfst | fstcompose $Gfst - | fstarcsort --sort_type=olabel > $GTPLfst
	>&2 echo "Done."
	echo "Stage 13 took" $SECONDS "seconds."; SECONDS=0
else
	usingfile "$GTPLfst" "GTPL FST"
fi

## STAGE 14 ##
# Decode.  Create lattices for each merged utterance FST (M),
# both with (GTPLM) and without (TPLM) a language model.
#
# Reads the files $splittestids.xxx or $splitadaptids.xxx.
# Reads the files $mergefstdir/*.M.fst.txt.
# Creates and then reads the files $mergefstdir/*.M.fst.
# Reads the files $GTPLfst and $TPLfst.
# Creates the files $decodelatdir/*.GTPLM.fst and $decodelatdir/*.TPLM.fst
# Creates $decodelatdir.
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
	echo "Stage 14 took" $SECONDS "seconds."; SECONDS=0
else
	usingfile "$decodelatdir" "decoded lattices in"
fi

## STAGE 15 ##
# Evaluate the GTPLM lattices, stand-alone.
#
# Reads files $splittestids.xxx $evalreffile $phnalphabet $decodelatdir/*.GTPLM.fst $testids.
# Uses variables $evaloracle $prunewt.
# May create file $hypfile.
# Creates $evaloutput, the evalution of error rates.
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
	if [[ -n $decode_for_adapt ]]; then
		>&2 echo "Not evaluating PTs (adaptation mode)."
	else
		evaluate_PTs.sh $1 | tee $evaloutput >&2
		echo "Stage 15 took" $SECONDS "seconds."; SECONDS=0
	fi
else
	>&2 echo "Stage 15: nothing to do."
fi

if [[ -z $debug ]]; then
	rm -rf $tmpdir
fi
