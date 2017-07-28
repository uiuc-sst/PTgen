#!/usr/bin/perl

# Create a prior over letters and represent it as an FST.

if ($#ARGV != 1) {
	print "Usage: $0 <merged transcripts dir> <uttids>\n";
	exit 1;
}

$mergedir = $ARGV[0]; # $mergedir
$uttlist  = $ARGV[1]; # $trainids
open(UTT, $uttlist) or die "$0: failed to open list of utterances $uttlist\n";

%labelcount = ();
$total = 0;
while($utt = <UTT>) {
	chomp($utt);
	$filename = "$mergedir/$utt".".txt";
	open(FILE, "$filename") or print STDERR "$0 failed to open $filename.\n";
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

if ($total == 0) {
  print STDERR "$0 read nothing, so it can't make L.fst.";
  exit 1;
  # Were we to continue, we'd fail at log(0).
}
$logtot = log($total);
foreach $let (keys %labelcount) {
	$wt = log($labelcount{$let}) - $logtot;
	print "0 0 $let $let $wt\n";
}
print "0\n";
