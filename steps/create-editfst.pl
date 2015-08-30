#!/usr/bin/perl

# Creating an edit distance FST that takes a vocab file 
# and creates sub/ins/del costs for each phone in it

if (-t STDIN) {
	print "Input: Phone vocab file";
	print "Output: Edit distance FST file (no disambiguation symbols on output)";
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
	print "0\t0\t$ind1\t0\t1\n"; #phn deletion
	print "0\t0\t0\t$ind1\t1\n"; #phn insertion
	foreach $k2 (keys %phonemap) {
		next if($k2 =~ /\#/);
		$ind2 = $phonemap{$k2};
		if($k1 ne $k2) { #add substitution cost of 1
			print "0\t0\t$ind1\t$ind2\t1\n";
		} else { #zero cost
			print "0\t0\t$ind1\t$ind1\t0\n";
		}
	}
}
print "0\n";
