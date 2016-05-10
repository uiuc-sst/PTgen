#!/bin/bash
#
# Usage: ./run_language_matrix.sh
#
set -x
 
SBS_DATADIR=/ws/rz-cl-2/hasegawa/amitdas/corpus/ws15-pt-data/data
ASR_DIR=/ws/ifp-48_1/hasegawa/amitdas/work/ws15-pt-data/kaldi-trunk/egs/SBS-mul/s9/SBS-mul
PTGEN_DIR=$PWD

#ALL_LANGS=(AM AR CA DI DT HG MD SW)
ALL_LANGS=(AM AR CA DI HG MD SW)
TEST_LANGS=(AM CA DI HG MD SW)

LANG_MAP="$SBS_DATADIR/lists/lang_codes.txt"

for TEST_LANG in ${TEST_LANGS[@]}; do
  # Let the list of training languages be $ALL_LANGS minus test language
  TRAIN_LANGS=`echo ${ALL_LANGS[@]/$TEST_LANG}`
  
  # Now exclude one language from the list of all training languages to 
  # create a one-but-all training set. Generate PT lattices 
  # for the one-but-all training set. Then run ASR on the same one-but-all
  # training set.
  for L in "" ${TRAIN_LANGS[*]}; do
	TRAIN_LANG=`echo ${TRAIN_LANGS[@]/$L}`
	TRAIN_LC=$(echo $TRAIN_LANG |sed 's/ /_/g')
	lang_name=`awk '/'$TEST_LANG'/ {print $2}' $LANG_MAP`
	#echo "TRAIN = $TRAIN_LANG"
	#echo "TEST = $TEST_LANG"
	
	# PTgen
	cd $PTGEN_DIR
	ref_settings=test/ws15/settings-${lang_name}
	exp_settings=settings-${lang_name}-tr_${TRAIN_LC}
	EXPLOCAL='\$EXP\/\${TEST_LANG}_'"tr_${TRAIN_LC}"
	[[ ! -e $ref_settings ]] && echo "ref settings file does not exist: $ref_settings" && exit 1
	rm -rf $exp_settings
	
	# Edit the settings in the reference settings file to generate the TPLM lattices
	# for adapt utterances. Save the new settings in an expt settings file. 
	# Run PTgen using the expt settings file.
	echo "ref = $ref_settings, exp = $exp_settings, EXPLOCAL = $EXPLOCAL"
	# change TRAIN_LANG
	sed "s/^TRAIN_LANG=\(.*\)/TRAIN_LANG=($TRAIN_LANG)/" $ref_settings >> $exp_settings
	# change EXPLOCAL
	sed -i "s/^export EXPLOCAL=\(.*\)/export EXPLOCAL=$EXPLOCAL/" $exp_settings
	# Comment makeGTPLM
	sed -i "s/^makeGTPLM/#makeGTPLM/" $exp_settings
	# Comment evaloracle
	sed -i "s/^evaloracle/#evaloracle/" $exp_settings
	# Comment debug
	sed -i "s/^debug/#debug/" $exp_settings
	# Uncomment makeTPLM
	sed -i "s/^#makeTPLM=\(.*\)/makeTPLM=1/" $exp_settings
	# Uncomment decode_for_adapt
	sed -i "s/^#decode_for_adapt=\(.*\)/decode_for_adapt=1/" $exp_settings
	# Set startstage to 1
	sed -i "s/^startstage=\(.*\)/startstage=1/" $exp_settings
	# Set endstage to 14
	sed -i "s/^endstage=\(.*\)/endstage=14/" $exp_settings	
	./run.sh $exp_settings
	
	# Edit the settings in the expt settings file to generate the TPLM lattices
	# for test utterances. Run PTgen using the expt settings file.
	# Uncomment decode_for_adapt
	sed -i "s/^decode_for_adapt=\(.*\)/#decode_for_adapt=/" $exp_settings
	# Set startstage to 14
	sed -i "s/^startstage=\(.*\)/startstage=14/" $exp_settings
	./run.sh $exp_settings
	rm -rf $exp_settings
	
	# ASR
	cd $ASR_DIR
	dir_raw_pt=$PTGEN_DIR/Tmp/Exp/${TEST_LANG}_tr_${TRAIN_LC}/decode
	./run_1.sh --stage 0 "$TRAIN_LANG" "$TEST_LANG" $dir_raw_pt
	mkdir -p exp_${TEST_LANG}/tr_${TRAIN_LC}
	mv exp data mfcc exp_${TEST_LANG}/tr_${TRAIN_LC}/
  done
done
