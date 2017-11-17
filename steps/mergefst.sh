#!/bin/bash
. $INIT_STEPS
set -e

[ ! -d $mergedir ] && >&2 echo "$0: no directory $mergedir. Aborting." && exit 1

mkdir -p $mergefstdir
showprogress init 200 "Merging transcript FSTs"
for ip in $(seq -f %02g $nparallel); do
  (
  # 2>/dev/null hides complaints of missing $splittestids and $splitadaptids, for prepare.rb.
  cat $splittrainids.$ip $splittestids.$ip $splitadaptids.$ip 2>/dev/null | shuf | while read uttid; do
    # If an utterance lacks speech (only music), skip it without complaining.
    [[ ! -s $mergedir/$uttid.txt ]] && continue
    showprogress go
    # If $engalphabet (data/let2phn/englets.vocab) contains mcasr symbols while $mcasr is false,
    # or vice versa, then fstcompile will fail: Symbol "1" is not mapped to any integer arc ilabel.
    convert-aligner-to-fst.pl $alignertofstopt < $mergedir/$uttid.txt |
      convert-prob-to-neglog.pl | tee $mergefstdir/$uttid.M.fst.txt |
      fstcompile --isymbols=$engalphabet --osymbols=$engalphabet |
      fstarcsort --sort_type=ilabel - > $mergefstdir/$uttid.M.fst
    # $uttid.M.fst should be an acyclic sausage, with one terminal state, that has zero cost.
    # No arc should have infinite cost.
    # Most arcs should have probability 1 (chain), or 0.5/0.5, 0.5/0.25/0.25, etc (sausage).
    # Even more strongly:
    # the set of arcs must be { (i,i+1) } for i from 0 to end-1,
    # with possible duplicates that echo different characters.
    # todo: Verify this.
    if [[ $(fstprint $mergefstdir/$uttid.M.fst) == "0" ]]; then
      >&2 echo -e -n "\n$(basename $0): made null FST from nonempty $mergedir/$uttid.txt."
    elif [[ $(fstprint --acceptor $mergefstdir/$uttid.M.fst | grep Infinity) ]]; then
      >&2 echo -e -n "\n$(basename $0): made FST with infinite-cost arcs from $mergedir/$uttid.txt."
    fi
    # todo: if fstprint | grep "# of connected components" is not 1, warn that it is disconnected.
    # todo: if fstprint | grep "# of strongly conn components" is not equal to "number of states", warn that it has a loop.
  done
  ) &
done
wait
showprogress end
if ! find $mergefstdir -mindepth 1 | read ; then
  >&2 echo -e "$0: created no FSTs in $mergefstdir. Check \$mergedir $mergedir."
  exit 1
fi
