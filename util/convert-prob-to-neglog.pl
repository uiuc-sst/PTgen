#!/usr/bin/perl

# Replace the fourth field of each line with that value's negative log.

while(<STDIN>) {
	chomp;
	@fields = split(/\s+/);
	if($#fields == 4) { #arc
		$wt = $fields[4];
		if($wt > 0) {
			print "$fields[0]\t$fields[1]\t$fields[2]\t$fields[3]\t",-log($wt),"\n";
		} else {
			print STDERR "convert-prob-to-neglog.pl WARNING: Invalid probability $wt.  Arc ignored.\n"
		}
	} else {
		print "$_\n";
	}
}
