#!/bin/bash

. $INIT_STEPS

if [[ ! -s $langmap ]]; then
  echo "Missing or empty langmap file $langmap. Check $1."; exit 1
fi

# Needs $datatype from run.sh's stage 3.  Related to $TESTTYPE in settings_file?
# (It would be nice to pass this in as $2 instead of as an explicit variable,
# but steps/init.sh insists on only one argument, the settings_file.)

case $datatype in
train)
	LANG=( "${TRAIN_LANG[@]}" )
	dtype="train"
	ids_file=$trainids
	splitids_file=$splittrainids
	;;
dev)
	LANG=( "${DEV_LANG[@]}" )
	dtype="dev"
	ids_file=$testids
	splitids_file=$splittestids
	;;
adapt)
	LANG=( "${DEV_LANG[@]}" )
	dtype="train"
	ids_file=$adaptids
	splitids_file=$splitadaptids
	;;
eval)
	LANG=( "${EVAL_LANG[@]}" )
	dtype="test"
	ids_file=$testids
	splitids_file=$splittestids
	;;
*)
	>&2 echo "create-datasplits.sh ERROR: Data split type \"$datatype\" should be [eval|dev|train|adapt]."
	exit 1
esac

mkdir -p "$(dirname "$ids_file")"
mkdir -p "$(dirname "$splitids_file")"
for L in ${LANG[@]}; do
	full_lang_name=`awk '/'$L'/ {print $2}' $langmap`
	sed -e 's:.wav::' -e 's:.mp3::' $LISTDIR/$full_lang_name/$dtype
done > $ids_file
split -n r/$nparallel $ids_file $tmpdir/split-${dtype}.
for i in `seq 1 $nparallel`; do
	mv `ls $tmpdir/split-${dtype}.* | head -1` ${splitids_file}.$i
done
