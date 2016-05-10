export KALDI_ROOT=/ws/ifp-48_1/hasegawa/amitdas/work/ws15-pt-data/kaldi-trunk
export PATH=$PWD/utils/:$KALDI_ROOT/tools/sph2pipe_v2.5/:$KALDI_ROOT/src/bin:$KALDI_ROOT/tools/openfst/bin:$KALDI_ROOT/tools/irstlm/bin/:$KALDI_ROOT/src/fstbin/:$KALDI_ROOT/src/gmmbin/:$KALDI_ROOT/src/featbin/:$KALDI_ROOT/src/lm/:$KALDI_ROOT/src/sgmmbin/:$KALDI_ROOT/src/sgmm2bin/:$KALDI_ROOT/src/fgmmbin/:$KALDI_ROOT/src/latbin/:$KALDI_ROOT/src/nnetbin:$KALDI_ROOT/src/nnet2bin/:$KALDI_ROOT/src/kwsbin:$PWD:$PATH:/export/ws15-pt-data/python-3.4.3/bin
export LC_ALL=C
export IRSTLM=$KALDI_ROOT/tools/irstlm
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/local/lib64:$KALDI_ROOT/tools/openfst/lib:$LD_LIBRARY_PATH  #/usr/local/cuda/lib64/stubs:
export SBS_DATADIR=/ws/rz-cl-2/hasegawa/amitdas/corpus/ws15-pt-data/data

export KALDIDIR=$KALDI_ROOT
export CARMELDIR=$PWD/../carmel/bin
export OPENFSTDIR=$KALDIDIR/tools/openfst/src/bin/.libs
export OPENFSTLIB1=$KALDIDIR/tools/openfst/src/lib/.libs
export OPENFSTLIB2=$KALDIDIR/tools/openfst/src/script/.libs
export DATA=$SBS_DATADIR/pt-gen
