#!/usr/bin/perl

# Print, as a string, a shortest-path FST's output labels (from "fstprint --osymbols").

@arcs = ();
binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
while(<STDIN>) {
  chomp;
  push(@arcs, $_);
}

# Accumulate output labels $l into $olabel_seq.
$olabel_seq = "";
for($a = 0; $a != -1; ($a==0? $a=$#arcs : ($a==1 ? $a=-1 : $a--))) {
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
       $olabel_seq = "$olabel_seq $l";
  }
}

$olabel_seq =~ s/^\s+//g;
print "$olabel_seq\n";
