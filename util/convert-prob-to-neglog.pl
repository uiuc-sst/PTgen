#!/usr/bin/perl
#

while(<STDIN>) {
	chomp;
	@fields = split(/\s+/);
	if($#fields == 4) { #arc
		$wt = $fields[4];
		if($wt > 0) {
			print "$fields[0]\t$fields[1]\t$fields[2]\t$fields[3]\t",-log($wt),"\n";
		} else {
			print STDERR "WARNING: Invalid probability $wt -- arc ignored.\n"
		}
	} else {
		print "$_\n";
	}
}
