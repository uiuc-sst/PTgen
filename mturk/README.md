# How to create tasks for Amazon Mechanical Turk

## [Login](https://requester.mturk.com/begin_signin).
- Click on Create.
- Using an existing project, at right click on Copy.
- Edit the copy as needed.

## Get a collection of recordings of speech, in .wav or .flac format.
- Concatenate them, monophonic and with a consistent sampling rate.

Examples:

- `sox in/*.wav -c 1 -r 22050 /tmp/a.wav avg`

- `for f in in/*.flac; do sox "$f" in/"$( basename ${f%.flac}.wav )"; done; sox in/*.wav ...`
    
   (There's a bug in sox when directly concatenating .flac files,
   so convert those to .wav first.)

## Remove silent intervals, and split the concatenation into monophonic clips of 1.25 seconds, in .mp3 and .ogg format.

- [`./split.rb`](./split.rb)

This script reads `/tmp/a.wav` and writes `/tmp/turkAudio.tar`.
It takes about 1 minute per hour of input.

## On ifp-serv-03:
- `cd /workspace/speech_web/mc/`
- `mkdir myTest; cd myTest`
- Into here, copy `turkAudio.tar` that was made by `split.rb`.
- `tar xf turkAudio.tar`

## Create a "Batch file."
[`./make-csv.rb 5001 > foo.csv`](./make-csv.rb)

(The number 5001 is 1 more than the biggest filename, e.g., 05000.mp3.)

## Submit the batch file to Mechanical Turk's "Publish Batch."
If needed, first split foo.csv into quarters (each starting with the
original's first line), and submit it only one quarter at a time.
That yields intermediate results more quickly, because one quarter of
the clips get completed before any others start.  It also lets you fund
the account a little at a time.

- If you like, as transcriptions trickle in, collect them and run PTgen on the results so far.

Click on Mechanical Turk's "Manage results," "download csv."
- `mv Batch*.csv PTgen/test/myTest/batchfiles-raw`
- `cat PTgen/test/myTest/batchfiles-raw/Batch*.csv PTgen/test/myTest/data/batchfiles/myLanguageCode/batchfile/`
