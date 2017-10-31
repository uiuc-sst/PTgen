#!/bin/bash

# Build Exp/prepare/P.fst and L.fst from purely WS15 transcriptions.

SCRIPTPATH=$(dirname $(readlink --canonicalize-existing $0))
SRCDIR=$SCRIPTPATH/steps
UTILDIR=$SCRIPTPATH/util

export INIT_STEPS=$SRCDIR/init.sh
. $INIT_STEPS

# config.sh is in the local directory, which might differ from that of run.sh.
# If there's no config.sh, that's still okay if binaries are already in $PATH.
if [ -s config.sh ]; then
  . config.sh
  export PATH=$PATH:$OPENFSTDIR:$CARMELDIR:$KALDIDIR
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$OPENFSTLIB1:$OPENFSTLIB2 # for libfstscript.so and libfst.so
fi

if ! hash compute-wer 2>/dev/null; then
  read -p "Enter the Kaldi directory containing compute-wer: " KALDIDIR
  # Typical values:
  # foo/kaldi-trunk/src/bin
  # Append this value, without erasing any previous values.
  echo KALDIDIR=\"$KALDIDIR\" >> config.sh
fi

if ! hash carmel 2>/dev/null; then
  read -p "Enter the directory containing carmel: " CARMELDIR
  # Typical values:
  # foo/bin-carmel/linux64
  # $HOME/carmel/linux64
  echo CARMELDIR=\"$CARMELDIR\" >> config.sh
fi

if ! hash fstcompile 2>/dev/null; then
  read -p "Enter the directory containing fstcompile and other OpenFST programs (/foo/bar/.../bin/.libs): " OPENFSTDIR
  # Typical values:
  # foo/openfst-1.5.0/src/bin/.libs
  echo OPENFSTDIR=\"$OPENFSTDIR\" >> config.sh
  # Expect to find libfstscript.so and libfst.so relative to OPENFSTDIR.
  # foo/openfst-1.5.0/src/bin/.libs becomes
  # foo/openfst-1.5.0/src/lib/.libs and
  # foo/openfst-1.5.0/src/script/.libs
  OPENFSTLIB1=$(echo $OPENFSTDIR | sed 's_bin/.libs$_lib/.libs_')
  OPENFSTLIB2=$(echo $OPENFSTDIR | sed 's_bin/.libs$_script/.libs_')
  echo OPENFSTLIB1=\"$OPENFSTLIB1\" >> config.sh
  echo OPENFSTLIB2=\"$OPENFSTLIB2\" >> config.sh
fi

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$OPENFSTLIB1:$OPENFSTLIB2 # for libfstscript.so and libfst.so
export PATH=$PATH:$SRCDIR:$UTILDIR:$OPENFSTDIR:$CARMELDIR:$KALDIDIR

if [ ! -d $DATA ]; then
  if [ -z ${DATA_URL+x} ]; then
    echo "Missing DATA directory '$DATA', and no \$DATA_URL to get it from. Check $1."; exit 1
  fi
  tarball=$(basename $DATA_URL)
  # $DATA_URL is e.g. http://www.ifp.illinois.edu/something/foo.tgz
  # $tarball is foo.tgz
  if [ -f $tarball ]; then
    echo "Found tarball $tarball, previously downloaded from $DATA_URL."
  else
    echo "Downloading $DATA_URL."
    wget --no-verbose $DATA_URL || exit 1
  fi
  # Check the name of the tarball's first file (probably a directory).  Strip the trailing slash.
  tarDir=$(tar tvf $tarball | head -1 | awk '{print $NF}' | sed -e 's_\/$__')
  [ "$tarDir" == "$DATA" ] || { echo "Tarball $tarball contains $tarDir, not \$DATA '$DATA'."; exit 1; }
  echo "Extracting $tarball, hopefully into \$DATA '$DATA'."
  tar xzf $tarball || { echo "Unexpected contents in $tarball.  Aborting."; exit 1; }
  [ -d $DATA ] || { echo "Still missing DATA directory '$DATA'. Check $DATA_URL and $1."; exit 1; }
  echo "Installed \$DATA '$DATA'."
fi
[ -d $DATA ] || { echo "Still missing DATA directory '$DATA'. Check $DATA_URL and $1."; exit 1; }
[ -d $LISTDIR ] || { echo "Missing LISTDIR directory $LISTDIR. Check $1."; exit 1; }
[ -d $TRANSDIR ] || { echo "Missing TRANSDIR directory $TRANSDIR. Check $1."; exit 1; }
[ -d $TURKERTEXT ] || { echo "Missing TURKERTEXT directory $TURKERTEXT. Check $1."; exit 1; }
[ -s $engdict ] || { echo "Missing or empty engdict file $engdict. Check $1."; exit 1; }
[ -s $engalphabet ] || { echo "Missing or empty engalphabet file $engalphabet. Check $1."; exit 1; }
[ ! -z $phnalphabet ] || { echo "No variable phnalphabet in file '$1'."; exit 1; }
[ -s $phnalphabet ] || { echo "Missing or empty phnalphabet file $phnalphabet. Check $1."; exit 1; }
[ -s $phonelm ] || { echo "Missing or empty phonelm file $phonelm. Check $1."; exit 1; }

mktmpdir

if [ -d $EXPLOCAL ]; then
  >&2 echo "Using experiment directory $EXPLOCAL."
else
  >&2 echo "Creating experiment directory $EXPLOCAL."
  mkdir -p $EXPLOCAL
fi
cp $1 $EXPLOCAL/settings

[ ! -z $startstage ] || startstage=1
[ ! -z $endstage ] || endstage=99999
echo "Running stages $startstage through $endstage."

if [[ $startstage -le 2 && 2 -le $endstage ]]; then
  hash compute_turker_similarity 2>/dev/null || { echo >&2 "Missing program 'compute_turker_similarity'. First \"cd PTgen/src; make\"."; exit 1; }
fi
if [[ $startstage -le 8 && 8 -le $endstage ]]; then
  hash carmel 2>/dev/null || { echo >&2 "Missing program 'carmel'. Stage 8 would abort.  Please install it from www.isi.edu/licensed-sw/carmel."; exit 1; }
fi

## STAGE 1 ##
# Preprocess transcripts from crowd workers.
# Creates the file $transcripts, e.g. Exp/uzbek/transcripts.txt.
# (Interspeech paper, figure 1, y^(i)).
SECONDS=0
stage=1
set -e
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
  if [[ -n $mcasr ]]; then
    # Copies preprocessed transcripts from crowd workers.
    # Reads the files $SCRIPTPATH/mcasr/*.txt.
    [ ! -z $LANG_CODE ] || { >&2 echo "No variable LANG_CODE in file '$1'."; exit 1; }
    [ -s $SCRIPTPATH/mcasr/stage1-$LANG_CODE.txt ] || { >&2 echo "Missing or empty file $SCRIPTPATH/mcasr/stage1-$LANG_CODE.txt. Check $1."; exit 1; }
    mkdir -p $(dirname $transcripts)
    cp $SCRIPTPATH/mcasr/stage1-$LANG_CODE.txt $transcripts
    cat $SCRIPTPATH/mcasr/stage1-sbs.txt >> $transcripts
    echo "Stage 1 collected transcripts $SCRIPTPATH/mcasr/stage1-$LANG_CODE.txt and $SCRIPTPATH/mcasr/stage1-sbs.txt."
    echo "Stage 1 took" $SECONDS "seconds."; SECONDS=0
  else
    # Reads the files $engdict and $TURKERTEXT/*/batchfile, where * covers $ALL_LANGS.
    # Uses the variable $rmprefix, if defined.
    mkdir -p $(dirname $transcripts)
    showprogress init 1 "Preprocessing transcripts"
    for L in "${ALL_LANGS[@]}"; do
      [[ -z $rmprefix ]] || prefixarg="--rmprefix $rmprefix"
      preprocess_turker_transcripts.pl --multiletter $engdict $prefixarg < $TURKERTEXT/$L/batchfile
      showprogress go
    done > $transcripts
    showprogress end
    echo "Stage 1 took" $SECONDS "seconds."; SECONDS=0
  fi
else
    usingfile $transcripts "preprocessed transcripts"
fi

## STAGE 2 ##
# For each utterance, rank each transcript by its similarity to the
# other transcripts (Interspeech paper, section 3).
#
# Reads the file $transcripts.
# Creates the file $simfile, which is read by stage 4's steps/mergetxt.sh.
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
  >&2 echo -n "Creating transcript similarity scores... "
  mkdir -p $(dirname $simfile)
  compute_turker_similarity < $transcripts > $simfile
  >&2 echo "Done."
  echo "Stage 2 took" $SECONDS "seconds."; SECONDS=0
else
  usingfile $simfile "transcript similarity scores"
fi

## STAGE 3 ##
# Prepare data lists.
#
# Via $langmap, expand variable $TRAIN_LANG's abbreviations into full language names.
# Reads each $LISTDIR/language_name/train.
# Creates the file $trainids.
# Splits that into parts $splittrainids.xxx, where xxx is numbers.
#
# The files language_name/train contain lines such as "arabic_140925_362941-6".
# Each line may point to:
# - a textfile containing a known-good transcription, data/nativetranscripts/arabic/arabic_140925_362941-6.txt
# - many lines in data/batchfiles/AR/batchfile that contain http://.../arabic_140925_362941-6.mp3
#   and one crowdsourced transcription thereof
# - a line in data/nativetranscripts/AR/ref_train: arabic_140925_362941-6 followed by a string of phonemes
# - a line in data/lists/arabic/arabic.txt: arabic_140925_362941-6 followed by either "discard" or "retain"

((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
  # Simplified steps/create-datasplits.sh.
  [ -s $langmap ] || { >&2 echo -e "\n$0: missing or empty langmap file $langmap. Check $1."; exit 1; }
  [ ! -z ${TRAIN_LANG+x} ] || { >&2 echo -e "\n$0: no \$TRAIN_LANG. Check $1. Aborting."; exit 1; }
  >&2 echo -n "Splitting training data into parallel jobs... "
  mkdir -p $(dirname $trainids)
  LANG=( "${TRAIN_LANG[@]}" )
  for L in ${LANG[@]}; do
    full_lang_name=$(awk '/'$L'/ {print $2}' $langmap)
    [ ! -z $full_lang_name ] || { >&2 echo -e "\n$0: no language $L in $langmap. Aborting."; exit 1; }
    [ -d $LISTDIR/$full_lang_name ] || { >&2 echo -e "\n$0: missing directory $LISTDIR/$full_lang_name. Aborting.\nSee https://github.com/uiuc-sst/PTgen/blob/master/datasplit.md."; exit 1; }
    [ -s $LISTDIR/$full_lang_name/train ] || { >&2 echo -e "\n$0: missing or empty file $LISTDIR/$full_lang_name/train Aborting.\nSee https://github.com/uiuc-sst/PTgen/blob/master/datasplit.md."; exit 1; }
    sed -e 's:.wav::' -e 's:.mp3::' $LISTDIR/$full_lang_name/train
  done > $trainids
  [ -s $trainids ] || { >&2 echo -e "\n$0: generated empty trainids $trainids. Aborting."; exit 1; }
  mkdir -p $(dirname $splittrainids)
  split --numeric-suffixes=1 -n r/$nparallel $trainids $splittrainids.$i
  >&2 echo "Done."
  echo "Stage 3 took" $SECONDS "seconds."; SECONDS=0
else
  usingfile $(dirname $splittrainids) "train ID lists in"
fi

## STAGE 4 ##
# For each utterance ($uttid), merge all of its transcriptions.
#
# Creates file $aligndist, e.g. Exp/uzbek/aligndists.txt.
# Creates directory $mergedir and files therein:
# language_xxx.txt, part-x-language_xxx.txt, $uttid.txt
# (Interspeech paper, section 2.1).
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
  mergetxt.sh $1
  echo "Stage 4 took" $SECONDS "seconds."; SECONDS=0
else
  usingfile $mergedir "merged transcripts in"
fi

## STAGE 5 ##
# Convert each merged transcript into a sausage, "a confusion network rho(lambda|T)
# over representative transcripts in the annotation-language orthography,"
# "an orthographic confusion network."
#
# Uses variable $alignertofstopt.
# Reads files $mergedir/*.
# Reads files $splittrainids.xxx.
# Creates directory $mergefstdir and, therein, for each uttid,
# a transcript FST *.M.fst over the English letters $engalphabet
# (IEEE TASLP paper, fig. 4, left side).
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
  mergefst.sh $1
  echo "Stage 5 took" $SECONDS "seconds."; SECONDS=0
else
  usingfile $mergedir "merged transcript FSTs in"
fi

## STAGE 6 ##
# Initialize the phone-2-letter model, P, aka:
# - the "mismatched channel" of the Interspeech paper, paragraph below table 1.
#
# - the "misperception G2P rho(lambda|phi)" of the TASLP paper, section III.B.
#
# - A model of the probability that an American listener writes a given letter,
# upon hearing a given foreign phoneme.  It assumes that what matters is
# only the American ear, not the utterance's language.  Thus we can learn
# p(letter|phoneme) by using phones from many languages, which cover all
# of the phones in the utterance's language.  Then we compute
#     Phone sequence = arg max  prod_n  p(letter_n | phone_n)
# where p(letter_n | phone_n) is the size-1 version of the mismatch channel.
# Given that phone sequence, we compute
#     Word sequence  = arg max  prod_n  p(phone_n | word that spans phones including phone n)
# where p(phone_n | word that spans phones) = 1 (0) if phone_n is (isn't) part of the word.
# So this model is just a dictionary specifying which phone sequence
# should be considered to correspond to each possible word.  We get this
# dictionary in two steps: (1) assume that the words specified by a machine
# translation engine are the *only* possible words; (2) for each such word,
# convert the sequence of graphemes into a sequence of phones using e.g.
# http://isle.illinois.edu/sst/data/g2ps/Uyghur/Uyghur_Arabic_orthography_dict.html .
#
# Uses variables $Pstyle, $carmelinitopt and $delimsymbol.
# Reads files $phnalphabet and $engalphabet.
# Creates file $initcarmel, e.g. Exp/uzbek/carmel/simple.
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
  >&2 echo -n "Creating untrained phone-2-letter model ($Pstyle style)... "
  mkdir -p $(dirname $initcarmel)
  create-initcarmel.pl $carmelinitopt $phnalphabet $engalphabet $delimsymbol > $initcarmel
  >&2 echo "Done."
  echo "Stage 6 took" $SECONDS "seconds."; SECONDS=0
else
  usingfile $initcarmel "untrained phone-2-letter model"
fi

## STAGE 7 ##
# Create training data to learn the phone-2-letter mappings defined in P.
#
# Reads files $TRANSDIR/$TRAIN_LANG[*]/ref_train.
# Concatenates them into temporary file $reffile, e.g. Exp/uzbek/ref_train_text.
# Creates file $carmeltraintxt, e.g. Exp/uzbek/carmel/training.txt.
#
# In each ref_train file, each line is an identifier followed by a sequence of phonemes,
# given by passing the transcription through a G2P converter or a dictionary.
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
  >&2 echo "Creating carmel training data... "
  prepare-phn2let-traindata.sh $1 > $carmeltraintxt
  echo "Stage 7 took" $SECONDS "seconds."; SECONDS=0
else
  usingfile $carmeltraintxt "training text for phone-2-letter model"
fi
set +e

## STAGE 8 ##
# EM-train P.
#
# Reads files $carmeltraintxt and $initcarmel.
# Creates logfile $tmpdir/carmelout.
# Creates file $initcarmel.trained.
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
  >&2 echo -n "Training phone-2-letter model (see $tmpdir/carmelout)..."
  # Read a list of I/O pairs, e.g. Exp/russian/carmel/simple.
  # This list is pairs of lines; each pair is an input sequence followed by an output sequence.
  # Rewrite this list as an FST with new weights, e.g. Exp/russian/carmel/simple.trained.
  #   -f 1 does Dirichlet-prior smoothing.
  #   -M 20 limits training iterations to 20.
  #   -HJ formats output.
  #
  #   "coproc" runs carmel in a parallel shell whose stdout we can grep,
  #   to kill it when it prints something that shows that it's about to
  #   get stuck in an infinite loop.
  # Or:
  #   sudo apt-get install expect;
  #   carmel | tee carmelout | expect -c 'expect -timeout -1 "No derivations"
  coproc { carmel -\? --train-cascade -t -f 1 -M 1 -HJ $carmeltraintxt $initcarmel 2>&1 | tee $tmpdir/carmelout; }
  # ;;;; -M 20
  grep -q -m1 "No derivations in transducer" <&${COPROC[0]} && \
    [[ $COPROC_PID ]] && kill -9 $COPROC_PID && \
    >&2 echo -e "\nAborted carmel before it entered an infinite loop."
  # Another grep would be "0 states, 0 arcs".
  # The grep obviates the need for an explicit wait statement.
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
  usingfile ${initcarmel}.trained "trained phone-2-letter model"
fi

## STAGE 9 ##
# Convert P to OpenFst format.
#
# Reads file $initcarmel.trained.
# Uses variables $disambigdel, $disambigins, $phneps, and $leteps.
# Creates logfile $tmpdir/trainedp2let.fst.txt.
# Creates file $Pfst, mapping $phnalphabet to $engalphabet.
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
  [ -s ${initcarmel}.trained ] || { >&2 echo "Empty ${initcarmel}.trained, so can't create $Pfst. Aborting."; exit 1; }
  >&2 echo -n "Creating P (phone-2-letter) FST... "
  Pscale=1
  phneps='<eps>'
  leteps='-'
  disambigdel='#2'
  disambigins='#3'
  convert-carmel-to-fst.pl < ${initcarmel}.trained \
    | sed -e 's/e\^-\([0-9]*\)\..*/1.00e-\1/g' | convert-prob-to-neglog.pl \
    | scale-FST-weights.pl $Pscale \
    | fixp2let.pl $disambigdel $disambigins $phneps $leteps \
    | tee $tmpdir/trainedp2let.fst.txt \
    | fstcompile --isymbols=$phnalphabet --osymbols=$engalphabet > $Pfst
  >&2 echo "Done."
  echo "Stage 9 took" $SECONDS "seconds."; SECONDS=0
else
  usingfile $Pfst "P (phone-2-letter) FST"
fi

## STAGE 10 ##
# Omitted.

## STAGE 11 ##
# Create a prior over letters and represent as an FST, L.
#
# Reads files in directory $mergedir.
# Reads files $trainids and $engalphabet.
# Creates file $Lfst, over the symbols $engalphabet.
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
  >&2 echo -n "Creating L (letter statistics) FST... "
  Lscale=1
  mkdir -p $(dirname $Lfst)
  create-letpriorfst.pl $mergedir $trainids \
    | scale-FST-weights.pl $Lscale \
    | fstcompile --osymbols=$engalphabet --isymbols=$engalphabet - \
    | fstarcsort --sort_type=ilabel - > $Lfst
  >&2 echo "Done."
  echo "Stage 11 took" $SECONDS "seconds."; SECONDS=0
else
  usingfile $Lfst "L (letter statistics) FST"
fi

if [ -z $debug ]; then
  rm -rf $tmpdir
fi
