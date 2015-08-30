#!/usr/bin/perl
#
# Read output labels of a shortest path FST and print as a string

@arcs = ();

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

while(<STDIN>) {
	chomp;
	push(@arcs, $_);
}


$olabel_seq = "";
for($a = 0; $a != -1; ($a==0? $a=$#arcs : ($a==1 ? $a=-1 : $a--) )) {
	$arc = $arcs[$a];
	@fields = split(/\s+/,$arc);
	$olabel = "";
	if($#fields > 2) { #arc
		$olabel = $fields[3];
	}
	if($olabel ne "-" && $olabel ne "" && $olabel ne "<eps>" && $olabel ne "sil" && $olabel ne "spn" && $olabel !~ "#") {
		$olabel_seq = "$olabel_seq $olabel";
	}
}

$olabel_seq =~ s/^\s+//g;

print "$olabel_seq\n";
