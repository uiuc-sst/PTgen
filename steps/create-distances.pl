#!/usr/bin/perl
use strict;

my $disttodel = 0.6;
my @letters = ("a","b","B","c","C","d","D","e","E","f","g","G","h","i","j","J","k","K","l","m","n","o","O","p","q","r","s","S","t","T","u","U","v","w","x","y","Y","z","Z"); 

my @classes = (
	[0.5,"a","e","i","o","u","A","E","I","O","U","Y"],
	[0.5, "k","K","g","G","q"],
	[0.5,"C","J","j"],
	[0.5,"t","T","d","D"],
	[0.5,"p","b","B"],
	[0.5,"s","S","z","Z"],
	[0.5,"v","w"],
	[0.5,"m","n"],
	[0.7,"c","k"],
	[0.7,"c","s"]
);

for my $class (@classes) {
	my @classx =  @$class;
	my $dist = shift @classx;
	for my $j (@classx) {
		for my $k (@classx) {
			print "$j $k $dist\n" if ($j ne $k);
		}
	}
}

foreach my $i (@letters) {
	print "- $i $disttodel\n$i - $disttodel\n";
}
