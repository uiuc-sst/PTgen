#!/bin/bash

. $INIT_STEPS

[ -s $langmap ] || { >&2 echo -e "\n$0: missing or empty langmap file $langmap. Check $1."; exit 1; }

# Needs $datatype from run.sh's stage 3.
# (It would be nice to pass this in as $2 instead of as an explicit variable,
# but steps/init.sh insists on only one argument, the settings_file.)

case $datatype in
dev | eval)
  [ $TESTTYPE == $datatype ] || { >&2 echo -e "\n$0: when \$datatype is $datatype, so must \$TESTTYPE.  Aborting."; exit 1; }
  ;;
esac

case $datatype in
train) LANG=( "${TRAIN_LANG[@]}" ); dtype="train"; ids_file=$trainids; splitids_file=$splittrainids ;;
adapt) LANG=( "${DEV_LANG[@]}"   ); dtype="train"; ids_file=$adaptids; splitids_file=$splitadaptids ;;
dev)   LANG=( "${DEV_LANG[@]}"   ); dtype="dev";   ids_file=$testids;  splitids_file=$splittestids  ;;
eval)  LANG=( "${EVAL_LANG[@]}"  ); dtype="test";  ids_file=$testids;  splitids_file=$splittestids  ;;
*)     >&2 echo -e "\n$0: Data split type $datatype should be [train|dev|adapt|eval].  Aborting."; exit 1 ;;
esac

case $datatype in
train)
  [ ! -z ${TRAIN_LANG+x} ] || { >&2 echo -e "\n$0: no \$TRAIN_LANG. Check $1. Aborting."; exit 1; } ;;
adapt | dev)
  [ ! -z ${DEV_LANG+x}   ] || { >&2 echo -e "\n$0: no \$DEV_LANG. Check $1. Aborting."; exit 1; } ;;
eval)
  [ ! -z ${EVAL_LANG+x}  ] || { >&2 echo -e "\n$0: no \$EVAL_LANG. Check $1. Aborting."; exit 1; } ;;
esac

mkdir -p $(dirname $ids_file)
for L in ${LANG[@]}; do
	full_lang_name=$(awk '/'$L'/ {print $2}' $langmap)
	[ ! -z "$full_lang_name" ] || { >&2 echo -e "\n$0: no language $L in $langmap. Aborting."; exit 1; }
	[ -d "$LISTDIR/$full_lang_name" ] || { >&2 echo -e "\n$0: missing directory $LISTDIR/$full_lang_name. Aborting.\nSee https://github.com/uiuc-sst/PTgen/blob/master/datasplit.md."; exit 1; }
	[ -s "$LISTDIR/$full_lang_name/$dtype" ] || { >&2 echo -e "\n$0: missing or empty file $LISTDIR/$full_lang_name/$dtype. Aborting.\nSee https://github.com/uiuc-sst/PTgen/blob/master/datasplit.md."; exit 1; }
	sed -e 's:.wav::' -e 's:.mp3::' $LISTDIR/$full_lang_name/$dtype
done > $ids_file

[ -s $ids_file ] || { >&2 echo -e "\n$0: generated empty ids_file $ids_file. Aborting."; exit 1; }

# "split -n r/42 ..." makes 42 equal-size parts, without breaking lines, with round robin (shuffled) distribution.
# "--numeric-suffixes=1" names them .01 .02 ... .42, instead of .aa .ab ... .
# To iterate over these files, use "seq -f %02g $nparallel".
mkdir -p $(dirname $splitids_file)
split --numeric-suffixes=1 -n r/$nparallel $ids_file $splitids_file.$i
