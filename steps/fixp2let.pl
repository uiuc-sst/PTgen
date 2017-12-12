#!/usr/bin/perl

# This filter modifies an openfst-text-format FST, a phone-2-letter model,
# by adding disambiguation symbols to handle phone deletions and letter insertions.

if ($#ARGV != 3) {
  print STDERR "Usage: $0 disambig_del_symbol disambig_ins_symbol phn_eps_symbol let_eps_symbol\n";
  exit 1;
}
$disambig_del = $ARGV[0];
$disambig_ins = $ARGV[1];
$phneps = $ARGV[2];
$leteps = $ARGV[3];

# Accumulate lines of STDIN into @lines.
$maxstate = 0;
@lines = ();
while ($line = <STDIN>) {
  chomp $line;
  $line =~ s/\s+/\t/g;
  @fields = split /\s+/, $line;
  if ($#fields > 2) {
    # This line represents an arc.
    # Use the arc's states to update $maxstate.
    $maxstate = $fields[0] if $fields[0] > $maxstate;
    $maxstate = $fields[1] if $fields[1] > $maxstate;
  }
  push @lines, $line;
}

%delstates = ();

foreach $line (@lines) {
  @fields = split /\s+/, $line;
  if($#fields <= 2) {
    # This line isn't an arc, so echo it unchanged.
    print "$line\n";
  } else {
    # This line represents an arc.
    if ($fields[2] eq $phneps && $fields[3] ne $leteps) {
      # Insertion.  This arc goes from NO phone to a letter.
      # Change phneps to disambig_ins.
      print "$fields[0]\t$fields[1]\t$disambig_ins\t$fields[3]";
      print "\t$fields[4]" if $#fields > 3;
      print "\n";
    } elsif ($fields[2] ne $phneps && $fields[3] eq $leteps) {
      # Deletion.  This arc goes from a phone to NO letter.
      if (!exists $delstates{$fields[0]}) {
	$maxstate++;
	$delstates{$fields[0]} = $maxstate;
	print "$fields[0]\t$maxstate\t$disambig_del\t$leteps\n";
      }
      print "$maxstate\t$fields[1]\t$fields[2]\t$leteps";
      print "\t$fields[4]" if $#fields > 3;
      print "\n";
    } else {
      # This arc goes from a phone to a letter.
      print "$line\n";
    }
  }
}
