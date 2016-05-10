Steps to run PTgen
===================
Let D=$PWD
0. Build Carmel under $D/carmel
> cd $D
> git https://github.com/irrawaddy28/carmel.git

Now you should see $D/carmel. Read the installation steps $D/carmel/MYREADME.md.
Install Carmel. After this Carmel will be installed as $D/carmel/bin/carmel.

1. Create $D/PTgen
> cd $D
> git clone https://github.com/irrawaddy28/PTgen.git (forked from https://github.com/ws15code/PTgen.git) 

This will create a directory "PTgen". 
> ls -l
total 8
drwxr-xr-x  7  4096 May  6 19:26 PTgen
drwxr-xr-x 15  4096 May  6 19:35 carmel


2. Build the necessary dependencies:
a) Build everything under PTgen/src
> cd $D/PTgen
> cd $D/src
> make
(make will prompt you to enter fst src/include path. I entered: /ws/ifp-48_1/hasegawa/amitdas/work/ws15-pt-data/kaldi-trunk/tools/openfst/src/include
Now compilation should go through fine and you should see be able to see 
two binary files: aligner, compute_turker_similarity)


#3. Now copy of your personal config.sh file to $D
#> cp ~/PTgen_config.sh $D/config.sh

#4. Now copy your personal settings file to $D/test/ws15
#> cp ~/settings-swahili $D/test/ws15

5. Now run the main script from $D
> cd $D
> ./run.sh test/ws15/settings-swahili

6. Use the following task specific settings to generate lattices in stage 14

The script can generate two kinds of lattices:
Raw lattices: These lattices have *.TPLM extension. These are not rescored using 
the language model (G) since we do the language model rescoring explicitly 
within our MAP adaptation.

Language model rescored lattices: These lattices have *.GTPLM extension. These are 
rescored the lattices since they have rescored using the language model (G). Such
lattices are primarily used in stage 15 for oracle error evaluation.

a) Generate raw lattices for adapt set (the utts in adapt set are the same as the PT training set in the ASR stage)
#makeGTPLM=1		# Used by stage 14.
#evaloracle=1		# Used by stage 15.
#debug=1	        # Used by stage 15.

makeTPLM=1		    # Used by stage 14.
decode_for_adapt=1	# Used by stage 14.  Omit stage 15. 

startstage=1
endstage=14

b) Generate raw lattices for test set (the utts in test set is the same as the test set in the ASR stage)
#makeGTPLM=1		# Used by stage 14.
#evaloracle=1		# Used by stage 15.
#debug=1	        # Used by stage 15.

makeTPLM=1		    # Used by stage 14.
#decode_for_adapt=	# Used by stage 14.  Omit stage 15.

startstage=14
endstage=14

c) Generate language model rescored lattices (*.GTPLM) for oracle error rate evaulation of test set
makeGTPLM=1		    # Used by stage 14.
evaloracle=1	    # Used by stage 15.
debug=1			    # Used by stage 15.

#makeTPLM=1		    # Used by stage 14.
#decode_for_adapt=1	# Used by stage 14.  Omit stage 15. 

startstage=14
endstage=15

7. If you generated the GTPLM lattices, then use the following settings to evalute 1-best 
or oracle error in stage 15:
a) 1-best error: Compute the edit distance between the 1-best path in GTPLM lattice and the native transcription
evaloracle=

a) Oracle error: Compute the edit distance between the GTPLM lattice and the native transcription
evaloracle=1

Note:
1. How to generate the bigram language model fst for a test language used in PTgen?
In particular, we wish to generate a language model bigram fst w/o any disambiguation 
symbols but retain the back-off state. This fst is reqd for to generate language model 
rescored PT lattices through PTgen (see $phonelm in the settings file)

E.g. Suppose test language is Dinka; 
Assume we already have a bigram lm for Dinka in ARPA format. We want to convert the
ARPA file to an FST w/o any disambi symbols. This is done as follows:

data=/ws/rz-cl-2/hasegawa/amitdas/corpus/ws15-pt-data/data
L=dinka
LC=DI
#bigram lm we need prior to generating the bigram fst.
lm=$data/text-phnlm/$LC/bigram.lm

cat $lm | egrep -v '<s> <s>|</s> <s>|</s> </s>' |  arpa2fst - | fstprint | utils/eps2disambig.pl |utils/s2eps.pl |
fstcompile --isymbols=$data/pt-gen/phonesets/univ.compact.txt --osymbols=$data/pt-gen/phonesets/univ.compact.txt  --keep_isymbols=false --keep_osymbols=false |fstrmepsilon|fstprint --isymbols=$data/pt-gen/phonesets/univ.compact.txt --osymbols=$data/pt-gen/phonesets/univ.compact.txt|awk '{ if ($3 == "#0") $3="<eps>"; print }' |  fstcompile --isymbols=$data/pt-gen/phonesets/univ.compact.txt --osymbols=$data/pt-gen/phonesets/univ.compact.txt  --keep_isymbols=false --keep_osymbols=false | fstarcsort --sort_type=ilabel > $data/pt-gen/langmodels/$L/bigram.nodisambig.fst


