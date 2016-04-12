#!/usr/bin/perl

# Add zero-weighted self-loops to every state of an FST, with arguments as labels.

if (@ARGV == 0) {
	print "Usage: addloop.pl <symbol> [...]\n";
	print "Input: FST text file";
	exit 1;
}

%states=();
while($line=<STDIN>) {
	chomp;
	@fields = split(/\s+/,$line);
	if ($#fields > 2) {
		$s1 = $fields[0];
		$s2 = $fields[1];
		$states{$s1} = 1;
		$states{$s2} = 1;
	}
	print "$line";
}

foreach $s (keys %states) {
	foreach $sym (@ARGV) {
		print "$s $s $sym $sym 0\n";
	}
}
