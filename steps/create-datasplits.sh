#!/bin/bash

. $INIT_STEPS

# expects $datatype to be exported

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
	>&2 echo "ERROR: Invalid data split type: \"$datatype\". Should be [eval|dev|train|adapt]."
	exit 1
esac

mkdir -p "$(dirname "$ids_file")"
mkdir -p "$(dirname "$split_ids_file")"
for L in ${LANG[@]}; do
	full_lang_name=`awk '/'${L}'/ {print $2}' $langmap`;
	sed -e 's:.wav::' $LISTDIR/$full_lang_name/${dtype}
done > $ids_file
split -n r/$nparallel $ids_file  $tmpdir/split-$dtype.
for i in `seq 1 $nparallel`; do
	mv `ls $tmpdir/split-$dtype.* | head -1` ${split_ids_file}.$i
done
