#!/usr/bin/perl
if (@ARGV == 0) {
	print "Usage: <script> <symbol> [<more symbols>]\n";
	print "Input: fst text file";
	exit 1;
}

# adding 0-weighted self-loops on every state of an fst with arguments as labels

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
