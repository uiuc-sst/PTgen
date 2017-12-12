#!/usr/bin/env perl

# Print, as a string, an FST's output labels (from "fstprint --osymbols").
# When processing the output of fstshortestpath, pass this the option --shortestpath.
# When processing the output of fstrandgen --select=log_prob, don't.

$shortestpath = 0;
while (@ARGV) {
  if ($ARGV[0] eq "--shortestpath") {
    $shortestpath = 1;
  } else {
    print STDERR "$0: ignoring unexpected argument: $ARGV[0]\n";
  }
  shift @ARGV;
}

@arcs = ();
binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
while(<STDIN>) {
  chomp;
  push(@arcs, $_);
}

# Append output labels $l into $olabel_seq.
$olabel_seq = "";

sub accumulate {
  @fields = split(/\s+/, $arcs[$a]);
  $l = "";
  if($#fields > 2) {
    $l = $fields[3];
  }
  if($l ne "-" &&
     $l ne "" &&
     $l ne "<eps>" &&
     $l ne "sil" &&
     $l ne "spn" &&
     $l !~ "#") {
       $olabel_seq .= " $l";
  }
}

if ($shortestpath) {
  # fstshortestpath's output's order is peculiar.
  for($a = 0; $a != -1; ($a==0? $a=$#arcs : ($a==1 ? $a=-1 : $a--))) { accumulate(); }
} else {
  # fstrandgen's output's order is unastonishing.
  for($a = 0; $a < $#arcs; $a++) { accumulate(); }
}

$olabel_seq =~ s/^\s+//g;
print "$olabel_seq\n";
