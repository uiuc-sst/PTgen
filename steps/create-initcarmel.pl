#!/usr/bin/perl

# Initialize the phone-2-letter model (P)

$mode = "simple";
if($#ARGV > 2) {
	$mode = shift;
	$mode =~ s/^--//;
}

$startfile = "";
if($#ARGV > 2) {
	$startfile = shift;
	$startfile =~ s/.*=//;
}

if($#ARGV != 2) {
	print "Usage: create-initcarmel.pl [--<mode>] [--startwith=<file>] <phn alphabet> <eng alphabet> <delimiter symbol>\n";
	print "<mode> is one of simple (default), letctxt, phnletctxt";
	exit(1);
}

$delim = $ARGV[2]; # $delimsymbol

%phone_vocab = ();
open(PHN, $ARGV[0]); # $phnalphabet
@phns = ();
while(<PHN>) {
	chomp;
	($p, $p_ind) = split(/\s+/);
	next if($p =~ /\#/ || $p =~ /sil/ || $p =~ /spn/);
	$phone_vocab{$p} = $p_ind;
	$phns[$p_ind] = $p;
}
close(PHN);

open(LET, $ARGV[1]); # $engalphabet
%let_vocab = ();
@lets = ();
while(<LET>) {
	chomp;
	($l, $l_ind) = split(/\s+/);
	next if($l eq $delim);
	$let_vocab{$l} = $l_ind;
	$lets[$l_ind] = $l;
}
close(LET);

%startvals = ();
if ($startfile ne "") {
	open(STRT, $startfile) or die "Cannot open $startfile\n";
	while(<STRT>) {
		chomp;
		@fields = split(/\s+/);
		next if($#fields < 4);
		$phn = $fields[2]; $let = $fields[3];
		$key = "$phn $let";
		$val = $fields[4]; $val =~ s/\)//g;
		print STDERR "WARNING: $key repeated in $startfile (not a simple model?)\n" if exists $startvals{$key};
		$startvals{$key} = $val;
	}
	close(STRT);
}


if ($mode eq "simple") {
	&simple(\%phone_vocab,\%let_vocab,\@phns,\@lets,$delim,\%startvals);
}
elsif ($mode eq "letctxt") {
	&letctxt(\%phone_vocab,\%let_vocab,\@phns,\@lets,$delim,\%startvals);
}
elsif ($mode eq "phnletctxt") {
	&phnletctxt(\%phone_vocab,\%let_vocab,\@phns,\@lets,$delim,\%startvals);
}
else {
	die "Unknown mode $mode"
}

exit(0);


sub simple {

my ($phone_vocab,$let_vocab,$phns,$lets,$delim,$startvals)= @_;

#### CONSTANTS ####
	$prob_insert = 0.01;
	$prob_delete = 0.1;
	$prob_noinsert = (1 - $prob_insert);
	$prob_nodelete = (1 - $prob_delete);

	$numlets = scalar (keys %$let_vocab) - 1; # not counting 0 
	$wt = ($prob_noinsert * $prob_nodelete)/$numlets;
	print "0\n"; #final state
	# print phone to every letter, skipping index 0
	for($i = 1; $i <= $#{$phns}; $i++) {
		$phone = ${$phns}[$i];
		next if (! exists $phone_vocab->{$phone} );
		for($j = 1; $j <= $#{$lets}; $j++) {
			$letter = ${$lets}[$j];
			next if (! exists $let_vocab->{$letter} );
			$phn = "\"$phone\""; $let = "\"$letter\"";
			$key = "$phn $let";
			$weight = (%$startvals ? ($startvals->{$key}) : $wt);
			print "(0 (0 $phn $let $weight))\n";
		}
	}

	# add deletions/insertions
	$wt = $prob_delete * $prob_noinsert;
	for($i = 1; $i <= $#{$phns}; $i++) {
		$phone = ${$phns}[$i];
		next if (! exists $phone_vocab->{$phone} );
		$key = "\"$phone\" *e*";
		$weight = (%$startvals ? ($startvals->{$key}) : $wt);
		print "(0 (0 \"$phone\" *e* $weight))\n";
	}

	$wt = $prob_insert/$numlets;
	for($k = 1; $k <= $#{$lets}; $k++) {
		$letter = ${$lets}[$k]; 
		next if (! exists $let_vocab->{$letter} );
		$w = ($letter =~ /\_/ ? "$wt" : "$wt!"); 
		$key = "*e* \"$letter\"";
		$weight = (%$startvals ? ($startvals->{$key}) : $w);
		print "(0 (0 *e* \"$letter\" $weight))\n";
	}

	# add insertion of delimiter
	$key = "*e* \"$delim\"";
	$weight = (%$startvals ? ($startvals->{$key}) : 1);
	print "(0 (0 *e* \"$delim\" $weight))\n";
}


sub letctxt {

my ($phone_vocab,$let_vocab,$phns,$lets,$delim,$startvals)= @_;
	$prob_delim = 0.01;

	$numlets = scalar (keys %$let_vocab); # counting 0 
	$wt = (1-$prob_delim)/$numlets;
# states are named S_$i_, where $j is letter index (or 0 for $DELIM_SYMBOL)
# S_0 is the start state and final state.
	$start = "S_0";
	print "$start\n"; #final state
	for($j = 0; $j <= $#{$lets}; $j++) {
		next if (! exists $let_vocab->{${$lets}[$j]} );
		$begin = "S_${j}";
		for($ii = 0; $ii <= $#{$phns}; $ii++) {
			$phone = ${$phns}[$ii];
			next if (! exists $phone_vocab->{$phone} );
			$phn = "\"$phone\"";
			$phn = "*e*" if ($phone_vocab->{$phone} == 0);
			for($jj = 0; $jj <= $#{$lets}; $jj++) {
				$letter = ${$lets}[$jj];
				next if (! exists $let_vocab->{$letter} );
				$let = "\"$letter\"";
				$let = "*e*" if ($let_vocab->{$letter} == 0);
				$end = "S_${jj}";
				next if $phn eq "*e*" && $let eq "*e*";
				$end = "S_${j}" if $let eq "*e*";
				$key = "$phn $let";
				$weight = (%$startvals ? ($startvals->{$key}) : $wt);
				print "($begin ($end $phn $let $weight))\n";
			}
		}
		$key = "*e* \"$delim\"";
		$weight = (%$startvals ? ($startvals->{$key}) : $prob_delim);
		print "($begin ($start *e* \"$delim\" $weight))\n";
	}
}

sub phnletctxt {

my ($phone_vocab,$let_vocab,$phns,$lets,$delim,$startvals)= @_;
	$prob_delim = 0.01;
	$wt = (1-$prob_delim)/($#{$lets}+1);
	# states are named S_$i_$j, where $i is phone index and $j is letter index (or 0 for $DELIM_SYMBOL)
	# S_0_0 is the start state and final state.
	$start = "S_0_0";
	print "$start\n"; #final state
	for($i = 0; $i <= $#{$phns}; $i++) {
		next if (! exists $phone_vocab->{${$phns}[$i]} );
		for($j = 0; $j <= $#{$lets}; $j++) {
			next if (! exists $let_vocab->{${$lets}[$j]} );
			$begin = "S_${i}_${j}";
			for($ii = 0; $ii <= $#{$phns}; $ii++) {
				next if (! exists $phone_vocab->{${$phns}[$ii]} );
				$phone = ${$phns}[$ii];
				$phn = "\"$phone\"";
				$phn = "*e*" if ($phone_vocab->{$phone} == 0);
				for($jj = 0; $jj <= $#{$lets}; $jj++) {
					next if (! exists $let_vocab->{${$lets}[$jj]} );
					$letter = ${$lets}[$jj];
					$let = "\"$letter\"";
					$let = "*e*" if ($let_vocab->{$letter} == 0);
					$end = "S_${ii}_${jj}";
					next if $phn eq "*e*" && $let eq "*e*";
					$end = "S_${i}_${jj}" if $phn eq "*e*";
					$end = "S_${ii}_${j}" if $let eq "*e*";
					$weight = (%$startvals ? ($startvals->{$key}) : $wt);
					print "($begin ($end $phn $let $weight))\n";
				}
			}
			$key = "*e* \"$delim\"";
			$weight = (%$startvals ? ($startvals->{$key}) : $prob_delim);
			print "($begin ($start *e* \"$delim\" $weight))\n";
		}
	}
}
