#!/usr/bin/perl
# 
# Creating a prior over letters and represent as an FST

if ($#ARGV != 1) {
	print "Usage: <script> <merged transcripts dir> <uttids to use>\n";
	exit 1;
}


$mergedir = $ARGV[0];
$uttlist = $ARGV[1];
open(UTT, $uttlist) or die "Cannot open list of utterances, $uttlist\n";

%labelcount = ();
$total = 0;
while($utt = <UTT>) {
	chomp($utt);
	$filename = "$mergedir/$utt".".txt";
	open(FILE, "$filename") or print STDERR "WARNING: Could not open $filename\n";
	while($line = <FILE>) {
		chomp;
		$line =~ s/\s+$//; $line =~ s/^\s+//;
		@labels = split(/\s+/,$line);
		$labelcount{$_}++ for @labels;
		$total += $#labels + 1;
	}
	close(FILE);
}
close(UTT);

$logtot = log($total);
foreach $let (keys %labelcount) {
	$wt = log($labelcount{$let}) - $logtot;
	print "0 0 $let $let $wt\n";
}
print "0\n";
