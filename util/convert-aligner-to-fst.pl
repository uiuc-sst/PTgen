#!/usr/bin/perl

# Parse the aligner's output to create a probabilistic automaton for turker transcripts.

$switchpenalty = 1;
$epssymbol = "-";
$argerr = 0;
while ((@ARGV) && ($argerr == 0)) {
	if ($ARGV[0] eq "--switchpenalty") {
		shift @ARGV;
		$switchpenalty = shift @ARGV;
	} elsif ($ARGV[0] eq "--epsilon") {
		shift @ARGV;
		$epssymbol = shift @ARGV;
	} else {
		print STDERR "Unknown argument: $ARGV[0]\n";
		$argerr = 1;
		break;
	}
}

if($argerr == 1) {
	print "Usage: $0 [--switchpenalty <penalty>] [--delimiter <symbol>] [--epsilon <symbol>]\n";
	print "Reads aligner's output.  Outputs an fst in OpenFST text format.\n";
	exit(1);
}
	
if ($switchpenalty == 1) {
	# March through states one at a time, printing one or more arcs to the next state.
	$state = 0;
	while(<STDIN>) {
		chomp;
		$line = $_;
		$line =~ s/\s+$//; $line =~ s/^\s+//;
		if($line eq "") {
			# Don't let an empty input line increment $state without printing an arc,
			# because that would leave a gap in the chain-like FST.
			next;
		}
		@labels = split(/\s+/,$line);
		%labelcount = ();
		$labelcount{$_}++ for @labels;
		$sum = $#labels + 1;
		foreach $k (keys %labelcount) {
			print "$state ", $state+1, " $k $k ", $labelcount{$k}/$sum, "\n";
		}
		$state++;
	}
	print "$state\n";
	exit(0);
}

$strands = -1;

$link = 0;
while(<STDIN>) {
	chomp;
	$line = $_;
	$line =~ s/\s$//; $line =~ s/^\s//;
	@labels = split(/\s/,$line);
	%labelcount = ();
	$labelcount{$_}++ for @labels;
	$sum = $#labels + 1;
	if ($link == 0) {
		$strands = $#labels + 1;
		for ($i=1; $i <= $strands; $i++) {
			print "0 $i - - 1\n";
		}
	}
	die "$0: invalid alignment" if $strands != $#labels + 1;
	for ($i=1; $i <= $strands; $i++) {
		$begin = $link*$strands + $i;
		$let = $labels[$i-1];
		$w = $labelcount{$let}/$sum;
		for ($j=1; $j <= $strands; $j++) {
			$end = ($link+1)*$strands + $j;
			$wt = $w / ($i == $j ? 1: $switchpenalty);
			print "$begin $end $let $let $wt\n";
		}
	}
	$link++;
}

$final = ($link+1) * $strands + 1;
for ($i=1; $i <= $strands; $i++) {
	$begin = $link*$strands + $i;
	print "$begin $final $epssymbol $epssymbol 1\n";
}
print "$final\n";
