#!/usr/bin/perl

# Text filter that adds zero-weighted self-loops to each state of an FST, with arguments as labels.

die "Usage: $0 <symbol> [...] < in.fst.fxt > out.fst.txt\n" if @ARGV == 0;

# Implement a set with a hash.  A perl idiom.
%states=();

while($line=<STDIN>) {
	chomp;
	@fields = split(/\s+/, $line);
	if ($#fields > 2) {
		# Accumulate the FST's states into $states.
		$s1 = $fields[0];
		$s2 = $fields[1];
		$states{$s1} = 1;
		$states{$s2} = 1;
	}
	# Copy everything from the original FST.
	print "$line";
}

# Append the zero-weighted self-loops.
foreach $s (keys %states) {
	foreach $sym (@ARGV) {
		print "$s $s $sym $sym 0\n";
	}
}
