#!/bin/bash

. $INIT_STEPS

if [[ ! -s $langmap ]]; then
  >&2 echo -e "\ncreate-datasplits.sh: missing or empty langmap file $langmap. Check $1."; exit 1
fi

# Needs $datatype from run.sh's stage 3.
# (It would be nice to pass this in as $2 instead of as an explicit variable,
# but steps/init.sh insists on only one argument, the settings_file.)

case $datatype in
dev | eval)
  if [[ $TESTTYPE != $datatype ]]; then
    >&2 echo -e "\ncreate-datasplits.sh: when \$datatype is $datatype, so must \$TESTTYPE.  Aborting."; exit 1
  fi
  ;;
esac

case $datatype in
train) LANG=( "${TRAIN_LANG[@]}" ); dtype="train"; ids_file=$trainids; splitids_file=$splittrainids ;;
adapt) LANG=( "${DEV_LANG[@]}"   ); dtype="train"; ids_file=$adaptids; splitids_file=$splitadaptids ;;
dev)   LANG=( "${DEV_LANG[@]}"   ); dtype="dev";   ids_file=$testids;  splitids_file=$splittestids  ;;
eval)  LANG=( "${EVAL_LANG[@]}"  ); dtype="test";  ids_file=$testids;  splitids_file=$splittestids  ;;
*)     >&2 echo -e "\ncreate-datasplits.sh: Data split type $datatype should be [train|dev|adapt|eval].  Aborting."; exit 1 ;;
esac
case $datatype in
train)
  if [ -z ${TRAIN_LANG+x} ]; then
    >&2 echo -e "\ncreate-datasplits.sh: no \$TRAIN_LANG.  Check $1.  Aborting."; exit 1
  fi ;;
adapt | dev)
  if [ -z ${DEV_LANG+x} ]; then
    >&2 echo -e "\ncreate-datasplits.sh: no \$DEV_LANG.  Check $1.  Aborting."; exit 1
  fi ;;
eval)
  if [ -z ${EVAL_LANG+x} ]; then
    >&2 echo -e "\ncreate-datasplits.sh: no \$EVAL_LANG.  Check $1.  Aborting."; exit 1
  fi ;;
esac
mkdir -p "$(dirname "$ids_file")"
for L in ${LANG[@]}; do
	full_lang_name=`awk '/'$L'/ {print $2}' $langmap`
	if [ -z "$full_lang_name" ]; then
		>&2 echo -e "\ncreate-datasplits.sh: no language $L in $langmap.  Aborting."; exit 1
	fi
	if [ ! -s "$LISTDIR/$full_lang_name/$dtype" ]; then
		>&2 echo -e "\ncreate-datasplits.sh: no file $LISTDIR/$full_lang_name/$dtype.  Aborting."; exit 1
	fi
	sed -e 's:.wav::' -e 's:.mp3::' $LISTDIR/$full_lang_name/$dtype
done > $ids_file

if [[ ! -s $ids_file ]]; then
  >&2 echo -e "\ncreate-datasplits.sh generated an empty ids_file $ids_file.  Aborting."; exit 1
fi

# "split -n r/42 ..." makes 42 equal-size parts, without breaking lines, with round robin distribution.
# "--numeric-suffixes=1" names them .01 .02 ... .42, instead of .aa .ab ... .
# To iterate over these files, use "seq -f %02g $nparallel".
mkdir -p "$(dirname "$splitids_file")"
split --numeric-suffixes=1 -n r/$nparallel $ids_file $splitids_file.$i
