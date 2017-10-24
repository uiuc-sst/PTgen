#!/usr/bin/perl

# Scale the weights of an FST in OpenFST text format.

die "Usage: $0 scaleValue < in.fst.txt > out.fst.txt" if $#ARGV != 0;
$scale=$ARGV[0];

while(<STDIN>) {
  chomp;
  @fields = split(/\s+/);
  if($#fields == 4) {
    # weighted arc
    $scaledwt = $fields[4] * $scale;
    print "$fields[0]\t$fields[1]\t$fields[2]\t$fields[3]\t$scaledwt\n";
  } elsif($#fields == 1) {
    # weighted final state
    $scaledwt = $fields[1] * $scale;
    print "$fields[0]\t$scaledwt\n";
  } else {
    print "$_\n";
  }
}
