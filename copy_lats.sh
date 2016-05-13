#!/bin/bash
#
# Usage: ./run_language_matrix.sh
#
# Script to copy PT lattices generated in PTgen directory 
# to ws15-pt-data directory @rizzo
 
SBS_DATADIR=/media/srv/rizzo/corpus/ws15-pt-data/data
PTGEN_DIR=/media/srv/ifp-48/work/PTgen/Tmp/Exp

ALL_LANGS=(AM AR CA DI HG MD SW)
TEST_LANGS=(AM CA DI HG MD SW)

LANG_MAP="$SBS_DATADIR/lists/lang_codes.txt"

for TEST_LANG in ${TEST_LANGS[@]}; do
  # Let the list of training languages be $ALL_LANGS minus test language
  TRAIN_LANGS=`echo ${ALL_LANGS[@]/$TEST_LANG}`  
  for L in "" ${TRAIN_LANGS[*]}; do
	TRAIN_LANG=`echo ${TRAIN_LANGS[@]/$L}`
	TRAIN_LC=$(echo $TRAIN_LANG |sed 's/ /_/g')
	
	srcd=${TEST_LANG}_tr_${TRAIN_LC}/decode
	src=${PTGEN_DIR}/$srcd
	
	[[ ! -d $src ]] && echo "WARNING!!!! $src does not exist" && continue
	
	dstd=${TEST_LANG}/tr_${TRAIN_LC}
	dst=${SBS_DATADIR}/pt-roundrobin/${TEST_LANG}/tr_${TRAIN_LC}
	mkdir -p $dst
	
	echo "cp -R $src/* $dst"
	cp -R $src/* $dst	
	echo "Done: TEST LANG = ${TEST_LANG}, TRAIN LANG = ${TRAIN_LC}"
  done
done
