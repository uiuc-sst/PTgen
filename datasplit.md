# How to split utterances (uttid's) into train/dev/eval sets.

This explains how to create the uttid's (utterance identifiers),
split them randomly into three disjoint sets of 2/3 train, 1/6 dev, 1/6 eval,
and put those uttid's in `data/lists/$lang/{train,dev,eval}`.
They will also end up in `$ids_file` aka `$trainids` aka `Exp/$lang/lists/train`.

Stage 1's `preprocess_turker_transcripts.pl` makes uttid's like `part-7-uzbek_432_013` from the batchfile.
So at the end of the `settings` file, set `startstage=1` and `endstage=3`.
     ../../run.sh settings

Stage 2 fails now, but after the rest of these commands, it'll succeed.
Do one of these, or something similar:

     lang=uzbek;    cd PTgen/test/2016-08-24
     lang=uyghur;   cd PTgen/test/2016-12-04
     lang=russian;  cd PTgen/test/mcasr-rus

Now make uttid's like `$lang_432_013`:
     grep $lang /tmp/Exp/$lang/transcripts.txt | sed -e 's/:.*//' -e 's/part-[^-]*-//' | sort -u | shuf > /tmp/ids
If `/tmp/ids` turns out to be empty, replace `$lang` with whatever you see that's appropriate in `transcripts.txt`.
For example, `grep RUS ... `.

### To split ids into 2/3 train, 1/6 dev, 1/6 eval:

Split the ids into train and not-train.

     numLines=$(wc -l < /tmp/ids)
     numTrain=$(printf %.0f `echo "$numLines*.6666667" | bc`)
     head -n $numTrain /tmp/ids > train
     tail -n +$(($numTrain + 1)) /tmp/ids > /tmp/not-train

Split not-train ids into dev and eval.

     numDev=$(printf %.0f `echo "$(wc -l < /tmp/not-train)*.5" | bc`)
     head -n $numDev /tmp/not-train > dev
     tail -n +$(($numDev + 1)) /tmp/not-train > eval

If the split worked, this command's output will be empty.

    diff <(cat train dev eval) /tmp/ids

Move the files to the destination directory.
     mv train dev eval data/lists/$lang

In `settings`, set `startstage=2`, and rerun:
     ../../run.sh settings

### To instead split ids into *all* train, 0 dev, 0 eval:

     cp /tmp/ids data/lists/$lang/train
     rm -f data/lists/$lang/dev; touch data/lists/$lang/dev
     rm -f data/lists/$lang/eval; touch data/lists/$lang/eval
