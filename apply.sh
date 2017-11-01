#!/bin/bash

# Script to build and evaluate probabilistic transcriptions (aka transcripts).
# First run ./prepare.sh, to make Exp/prepare/P.fst and L.fst, which this script reads.

# This script is split into stages.
# See $startstage and $endstage in the settings file.

# If the settings file has mcasr=1, then for each short mp3 clip this reads,
# instead of English-letter transcripts,
# mcasr/s5c/data/LANGUAGE/lang/phones.txt phone-string transcripts
# computed by https://github.com/uiuc-sst/mcasr.

SCRIPTPATH=$(dirname $(readlink --canonicalize-existing $0))
SRCDIR=$SCRIPTPATH/steps
UTILDIR=$SCRIPTPATH/util

export INIT_STEPS=$SRCDIR/init.sh
. $INIT_STEPS

# config.sh is in the local directory, which might differ from that of run.sh.
# If there's no config.sh, that's still okay if binaries are already in $PATH.
if [ -s config.sh ]; then
  . config.sh
  export PATH=$PATH:$OPENFSTDIR:$KALDIDIR
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$OPENFSTLIB1:$OPENFSTLIB2 # for libfstscript.so and libfst.so
fi

if ! hash compute-wer 2>/dev/null; then
  read -p "Enter the Kaldi directory containing compute-wer: " KALDIDIR
  # Typical values:
  # foo/kaldi-trunk/src/bin
  # Append this value, without erasing any previous values.
  echo KALDIDIR=\"$KALDIDIR\" >> config.sh
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
export PATH=$PATH:$SRCDIR:$UTILDIR:$OPENFSTDIR:$KALDIDIR

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
#;;;; [ ! -z $phnalphabet ] || { echo "No variable phnalphabet in file '$1'."; exit 1; }
#;;;; [ -s $phnalphabet ] || { echo "Missing or empty phnalphabet file $phnalphabet. Check $1."; exit 1; }
[ -s $phonelm ] || { echo "Missing or empty phonelm file $phonelm. Check $1."; exit 1; }
[ ! -z $applyPrepared ] || { echo "Run run.sh instead of apply.sh, because variable \$applyPrepared is missing."; exit 1; }

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
if [[ $startstage -le 15 && 15 -le $endstage ]]; then
  hash compute-wer 2>/dev/null || { echo >&2 "Missing program 'compute-wer'. Stage 15 would abort."; exit 1; }
fi

set -e

## STAGE 0 ##
[ -s $EXPLOCAL/../prepare/P.fst ] || { echo "Missing or empty P.fst file $EXPLOCAL/../prepare/P.fst."; exit 1; }
[ -s $EXPLOCAL/../prepare/L.fst ] || { echo "Missing or empty L.fst file $EXPLOCAL/../prepare/L.fst."; exit 1; }
ln -fs $EXPLOCAL/../prepare/P.fst $Pfst
ln -fs $EXPLOCAL/../prepare/L.fst $Lfst
if [[ $(fstinfo $Pfst |grep "# of states" | awk '{print $NF}') -lt 9 ]]; then
   >&2 echo "P.fst has suspiciously few states.  Rerun prepare.sh?"
   # All the Exp/decode/*.PLM.fst will likely get 0 states.
fi
if [[ $(fstinfo $Lfst |grep "# of states" | awk '{print $NF}') -lt 9 ]]; then
   >&2 echo "L.fst has suspiciously few states.  Rerun prepare.sh?"
   # All the Exp/decode/*.PLM.fst will likely get 0 states.
fi
# todo: wget P.fst and L.fst from a sister to $DATA_URL.
#   But then, how can we quickly run apply.sh on variations on them,
#   to quickly measure how changes to prepare.sh affect WER?  Hmm.
# todo: instead, just a single $PLfst, what stage 13 simplified to?

## STAGE 1 ##
# Preprocess transcripts from crowd workers.
# Creates the file $transcripts, e.g. Exp/uzbek/transcripts.txt.
SECONDS=0
stage=1
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
  if [[ -n $mcasr ]]; then
    # Copies preprocessed transcripts from crowd workers.
    # Reads one of the files $SCRIPTPATH/mcasr/*.txt.
    [ ! -z $INCIDENT_LANG ] || { >&2 echo "No variable INCIDENT_LANG in file '$1'."; exit 1; }
    [ -s $SCRIPTPATH/mcasr/stage1-$INCIDENT_LANG.txt ] || { >&2 echo "Missing or empty file $SCRIPTPATH/mcasr/stage1-$INCIDENT_LANG.txt. Check $1."; exit 1; }
    mkdir -p $(dirname $transcripts)
    ln -fs $SCRIPTPATH/mcasr/stage1-$INCIDENT_LANG.txt $transcripts
    echo "Stage 1 using transcripts $SCRIPTPATH/mcasr/stage1-$INCIDENT_LANG.txt."
    # Collect the uttids, and split them into 90% train and 10% eval sets.
    rm -f $LISTDIR/IL5/{train,adapt,test,eval}*
    sed 's/:.*//' $transcripts | sort -u | shuf > /tmp/ids
    numLines=$(wc -l < /tmp/ids)
    numTrain=$(printf %.0f `echo "$numLines*.9" | bc`)
    head -n $numTrain /tmp/ids > $LISTDIR/IL5/train
    tail -n +$(($numTrain + 1)) /tmp/ids > $LISTDIR/IL5/test # ;;;; Or to .../eval?
    rm /tmp/ids
    echo "Stage 1 took" $SECONDS "seconds."; SECONDS=0

  else

    >&2 echo "$0: non-MCASR still under construction."; exit 1 # ;;;;
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
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
  >&2 echo -n "Splitting training data into parallel jobs... "
  TESTTYPE=eval TRAIN_LANG=$INCIDENT_LANG datatype='train' create-datasplits.sh $1
  TESTTYPE=eval EVAL_LANG=$INCIDENT_LANG  datatype='eval'  create-datasplits.sh $1
  >&2 echo "Done."
  echo "Stage 3 took" $SECONDS "seconds."; SECONDS=0
else
  usingfile $(dirname $splittestids) "ID lists in"
fi

## STAGE 4 ##
# For each utterance ($uttid), merge its transcripts.
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
# Reads files {$splittrainids, $splittestids, $splitadaptids}.xxx.
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

## STAGE 6-9 ##
# Omitted.
((stage++))
((stage++))
((stage++))
((stage++))

## STAGE 10 ##
# Deprecated ($Gfst).
((stage++))

## STAGE 11 ##
# Omitted.
((stage++))

## STAGE 12 ##
# Deprecated ($Tfst).
((stage++))

## STAGE 13 ##
# Create PL FST.
#
# Reads files $Pfst and $Lfst.
# Creates file $PLfst.
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
  >&2 echo -n "Creating PL FST... "
  mkdir -p $(dirname $TPLfst)
  fstcompose $Pfst $Lfst | fstarcsort --sort_type=olabel > $PLfst
  >&2 echo "Done."
  echo "Stage 13 took" $SECONDS "seconds."; SECONDS=0
else
  usingfile $PLfst "PL FST"
fi

## STAGE 14 ##
# Decode.  Create a lattice for each merged utterance FST (M).
#
# Reads the files $splittestids.xxx or $splitadaptids.xxx.
# Reads the files $mergefstdir/*.M.fst.txt.
# Creates and then reads the files $mergefstdir/*.M.fst.
# Reads the file $PLfst.
# Creates $decodelatdir and $decodelatdir/*.PLM.fst.
# Each PLM.fst is over $phnalphabet, a lattice over phones.
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
  >&2 echo -n "Decoding lattices PLM"
  mkdir -p $decodelatdir
  decode_PTs.sh $1
  echo "Stage 14 took" $SECONDS "seconds."; SECONDS=0
else
  usingfile $decodelatdir "decoded lattices in"
fi
set +e

## STAGE 15 ##
# Evaluate the PLM lattices.
#
# Reads files $splittestids.xxx $evalreffile $phnalphabet $decodelatdir/*.PLM.fst $testids.
# Uses variables $evaloracle $prunewt.
# May create file $hypfile.
# Creates $evaloutput, the evalution of error rates.
((stage++))
if [[ $startstage -le $stage && $stage -le $endstage ]]; then
  evaluate_PTs.sh $1 | tee $evaloutput >&2
  echo "Stage 15 took" $SECONDS "seconds."; SECONDS=0
else
  >&2 echo "Stage 15: nothing to do."
fi

if [ -z $debug ]; then
  rm -rf $tmpdir
fi
