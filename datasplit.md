How to create the uttid's (utterance identifiers),
split them randomly into train/dev/eval: 2/3 train, 1/6 dev, 1/6 eval,
and put them in data/lists/$lang/train, dev, eval.

The bash commands are:

    # Stage 1's preprocess_turker_transcripts.pl makes uttid's like "part-7-uzbek_432_013" from the batchfile.
    # Stage 2 will fail now, but after the rest of these commands, it'll succeed.
    ../../run.sh settings

    # lang=uzbek; cd /r/lorelei/PTgen/test/2016-08-24
    # lang=uyghur;  cd /r/lorelei/PTgen/test/2016-12-04
    lang=russian;  cd PTgen/test/mcasr-rus

    # Make uttid's like "$lang_432_013".
    grep $lang /tmp/Exp/$lang/transcripts.txt | sed -e 's/:.*//' -e 's/part-[^-]*-//' | sort -u | shuf > /tmp/ids
    # If that is empty, instead grep RUS ... .

To split ids into 2/3 train, 1/6 dev, 1/6 eval:

    # Split ids into train and not-train.
    numLines=$(wc -l < /tmp/ids)
    numTrain=$(printf %.0f `echo "$numLines*.6666667" | bc`)
    head -n $numTrain /tmp/ids > train
    tail -n +$(($numTrain + 1)) /tmp/ids > /tmp/not-train

    # Split not-train ids into dev and eval.
    numDev=$(printf %.0f `echo "$(wc -l < /tmp/not-train)*.5" | bc`)
    head -n $numDev /tmp/not-train > dev
    tail -n +$(($numDev + 1)) /tmp/not-train > eval
    # Verify split: cat train dev eval > /tmp/x; diff /tmp/x /tmp/ids

    mv train dev eval data/lists/$lang

    # Rerun ../../run.sh settings from stage 2.

To instead "split" *all* train, 0 dev, 0 eval:

    cp /tmp/ids data/lists/$lang/train
    cp /tmp/ids data/lists/$lang/dev
    cp /tmp/ids data/lists/$lang/eval
    # rm -f data/lists/$lang/dev; touch data/lists/$lang/dev
    # rm -f data/lists/$lang/eval; # touch data/lists/$lang/eval

----
Notes:
$ids_file == $trainids == /tmp/Exp/$lang/lists/train contains uttid's.
