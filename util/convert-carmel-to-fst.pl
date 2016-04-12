#!/usr/bin/perl

# Convert an FST from Carmel style to OpenFST style.

$final_state = "";
%state_names = ();
$state_num = 1;
$start_flag = 1;

while(<STDIN>) {
	chomp;
	@fields = split(/\s+/);
	if($#fields > 1) {
		# arc
		$start_state = $fields[0];
		$start_state =~ s/\(//g;
		$end_state = $fields[1];
		$end_state =~ s/\(//g;
		if($start_flag == 1) {
			$state_names{$start_state} = 0;
			$start_flag = 0;
		} elsif(!exists $state_names{$start_state}) {
			# start state is the first field
			$state_names{$start_state} = $state_num;
			$state_num++;
		}
		if(!exists $state_names{$end_state}) {
			$state_names{$end_state} = $state_num;
			$state_num++;
		}
		$ilabel = $fields[2]; $ilabel =~ s/\"//g;
		if($ilabel eq "*e*") {
			# epsilon
			$ilabel = "<eps>";
		}
		$olabel = $fields[3]; $olabel =~ s/\"//g; $olabel =~ s/\)//g;
		if($olabel eq "*e*") {
			# epsilon
			$olabel = "-";
		}
		print "$state_names{$start_state}\t$state_names{$end_state}\t$ilabel\t$olabel";
		if($#fields > 3) {
			# weighted
			$wt = $fields[4]; $wt =~ s/\)//g; $wt =~ s/!//g; # unclamp
			print "\t$wt";
		}
		print "\n";
	} else {
		$final_state = $_;
		$state_names{$final_state} = $state_num;
		$state_num++;
	}
}
print "$state_names{$final_state}\n";
