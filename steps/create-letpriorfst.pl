#!/usr/bin/perl

# Create a prior over letters, as an FST in OpenFST text format.
# It has one state.
# It has one (loopback) arc per letter, whose log weight indicates
# the letter's relative frequency in all the utterances in mergedir/*.txt.

use File::Basename;
my $name = basename($0);

if ($#ARGV != 1) {
	print "Usage: $name <merged transcripts dir> <uttids>\n";
	exit 1;
}

$mergedir = $ARGV[0];
$uttlist  = $ARGV[1]; # $trainids
open(UTT, $uttlist) or die "$name: failed to open list of utterances $uttlist\n";

%labelcount = ();
$total = 0;
while ($utt = <UTT>) {
	chomp($utt);
	$filename = "$mergedir/$utt".".txt";
	open(FILE, "$filename") or print STDERR "$name: failed to open $filename.\n";
	while ($line = <FILE>) {
		chomp;
		$line =~ s/\s+$//; $line =~ s/^\s+//;
		@labels = split(/\s+/, $line);		# e.g., 42 44 43 44
		$labelcount{$_}++ for @labels;		# Count 42 once, 43 once, 44 twice.
		$total += $#labels + 1;			# e.g., += 4+1
	}
	close(FILE);
}
close(UTT);

if ($total == 0) {
  print STDERR "$name read nothing, so it can't make L.fst.";
  exit 1;
  # Were we to continue, log(0) would fail.
}

# $total counts how many "letters" were in mergedir/*.txt.
# $labelcount{$letter} counts how many instances of each letter there were.
# Emit an arc for each letter.
$logtot = log($total);
foreach $letter (keys %labelcount) {
	$weight = log($labelcount{$letter}) - $logtot;
	print "0 0 $letter $letter $weight\n";
}

# The final state.
print "0\n";
