#!/usr/bin/perl
#
# Modifies phone-2-letter model by adding appropriate
# disambiguation symbols handling phone deletions and letter
# insertions

if ($#ARGV != 3) {
	print "Usage: <script> <disambig_del_symbol> <disambig_ins_symbol> <phn_eps_symbol> <let_eps_symbol>\n";
	exit 1;
}


$disambig_del = $ARGV[0];
$disambig_ins = $ARGV[1];
$phneps = $ARGV[2];
$leteps = $ARGV[3];

$maxstate = 0;
@lines = ();
while($line = <STDIN>) {
	chomp $line;
	$line =~ s/\s+/\t/g;
	@fields = split /\s+/,$line;
	if($#fields > 2) { #arc
		$maxstate = $fields[0] if $fields[0] > $maxstate;
		$maxstate = $fields[1] if $fields[1] > $maxstate;
	}
	push @lines, $line;
}

%delstates = ();

foreach $line (@lines) {
	@fields = split /\s+/, $line;
	if($#fields > 2) { #arc
		if($fields[2] eq $phneps && $fields[3] ne $leteps) { #insertion
			print "$fields[0]\t$fields[1]\t$disambig_ins\t$fields[3]";
			print "\t$fields[4]" if($#fields > 3);
			print "\n";
		} elsif ($fields[3] eq $leteps && $fields[2] ne $phneps) { #deletion
			if (!exists $delstates{$fields[0]}) {
				$maxstate++;
				$delstates{$fields[0]} = $maxstate;
				print "$fields[0]\t$maxstate\t$disambig_del\t$leteps\n";
			}
			print "$maxstate\t$fields[1]\t$fields[2]\t$leteps";
			print "\t$fields[4]" if($#fields > 3);
			print "\n";
		} else {
			print "$line\n";
		}
	} else {
		print "$line\n";
	}
}
