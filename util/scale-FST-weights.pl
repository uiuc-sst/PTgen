#!/usr/bin/perl
#
# Scaling FST weights by a scale provided as an argument

die "Usage: scale-FST-weights.pl <scale>" if $#ARGV != 0;
$scale=$ARGV[0];

while(<STDIN>) {
	chomp;
	@fields = split(/\s+/);
	if($#fields == 4) { #arc with weight
		$scaledwt = $fields[4] * $scale;
		print "$fields[0]\t$fields[1]\t$fields[2]\t$fields[3]\t$scaledwt\n";
	} elsif($#fields == 1) { #weighted final state
		$scaledwt = $fields[1] * $scale;
		print "$fields[0]\t$scaledwt\n";
	} else {
		print "$_\n";
	}
}
