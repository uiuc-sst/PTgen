#!/usr/bin/perl

# Outputs an unweighted FST that limits the number of insertions and deletions.
# Reads a vocab file.
# Arguments are the delete and insert disambiguation symbols, and numdel and numins.

if (-t STDIN || $#ARGV != 3) {
	print "Usage: create-delinsfst.pl <del disambig symbol> <ins disambig symbol> <num del> <num ins>";
	print "Input: Phone vocab file";
	print "Output: delete-insert FST file";
	exit 1;
}

%phonemap = ();
while(<STDIN>) {
	chomp;
	($sym, $index) = split(/\s+/);
	next if $sym =~ /\#/ || $sym eq "sil" || $sym eq "spn" || $index == 0;
	$phonemap{$sym} = $index;
}

$delsymb = shift; # $disambigdel
$inssymb = shift; # $disambigins
$numdel = shift;  # $Tnumdel
$numins = shift;  # $Tnumins

foreach $k (keys %phonemap) {
	print "0 0 $k $k\n"; 
}

$firstdel = 1;
for ($i=0; $i < $numdel; $i++) {
	$begin = ($i==0 ? 0 : $firstdel + 2*$i -1);
	$mid = $firstdel+2*$i;
	$end = $firstdel+2*$i + 1;
	print "$begin $mid $delsymb $delsymb\n"; 
	foreach $k (keys %phonemap) {
		print "$mid $end $k $k\n"; 
		print "$end 0 $k $k\n"; 
	}
}

$firstins = $end + 1;
for ($i=0; $i < $numins; $i++) {
	$begin = ($i==0 ? 0 : $firstins + $i -1);
	$end = $firstins+$i;
	print "$begin $end $inssymb $inssymb\n"; 
	foreach $k (keys %phonemap) {
		print "$end 0 $k $k\n"; 
	}
}

$laststate = $end;
for ($i=0; $i <= $laststate; $i++) {
	print "$i\n";
}
