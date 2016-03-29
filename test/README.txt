These directories are like those in kaldi/egs.

If you contribute a new directory PTgen/test/foo,
to each of its settings files add a line

    DATA_URL=http://isle.illinois.edu/mc/PTgenTest/something.tgz

and on host ifp-serv-03, place the corresponding file

    /workspace/speech_web/mc/PTgenTest/something.tgz

Then the test will automatically download that data if needed.
