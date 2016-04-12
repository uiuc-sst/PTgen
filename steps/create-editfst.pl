#!/usr/bin/perl

# On stdin, expects a phone vocab file.
#
# To stdout, writes an edit distance FST with sub/ins/del costs
# for each phone, without disambiguation symbols.

if (-t STDIN) {
	print "Input: Phone vocab file";
	print "Output: Edit distance FST file";
	exit 1;
}

%phonemap = ();
while(<STDIN>) {
	chomp;
	($sym, $index) = split(/\s+/);
	$phonemap{$sym} = $index if($index != 0);
}

foreach $k1 (keys %phonemap) {
	$ind1 = $phonemap{$k1};
	if($k1 =~ /\#/) {
		print "0\t0\t$ind1\t0\t0\n";
		next;
	}
	print "0\t0\t$ind1\t0\t1\n"; # phone deletion
	print "0\t0\t0\t$ind1\t1\n"; # phone insertion
	foreach $k2 (keys %phonemap) {
		next if($k2 =~ /\#/);
		$ind2 = $phonemap{$k2};
		if($k1 ne $k2) {
			# add substitution cost of 1
			print "0\t0\t$ind1\t$ind2\t1\n";
		} else {
			# zero cost
			print "0\t0\t$ind1\t$ind1\t0\n";
		}
	}
}
print "0\n";
