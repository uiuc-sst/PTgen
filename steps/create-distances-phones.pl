#!/usr/bin/perl
use strict;

# Called by PTgen stage 4 mergetxt.sh.

# Instead of letters, use the index of each phone in PTgen/mcasr/phones.txt.

my $disttodel = 0.6;
my @phones = (
  1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
  11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
  21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
  31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
  44, 42, 43, 44, 45, 46, 47, 48, 49, 50,
  51, 52, 53, 54, 55, 56, 57, 58, 59, 60,
  61, 62, 63, 64, 65, 66, 67, 68, 69, 70,
  71, 72, 73, 74, 75, 76, 77, 78, 79, 80,
  81, 82, 83, 84);

my @classes = (
	# SIL SPN X silence,noise,wildcard
	[0.7, 0, 1, 2],
	# a aʊ aː e ei i iː o oʊ u uː w y æ ø ɐ ɑ ɑɪ ɔ ɔi ə ɚ ɛ ɝ ɨ ɪ ɯ ɵ ʉ ʊ ʌ vowel
	[0.5, 4, 5, 6, 12, 16, 17, 23, 24, 30, 31, 33, 35, 37, 39, 41, 42, 43, 44, 45, 48, 49, 50, 51, 55, 56, 57, 60, 65, 66, 67],
	# c g k ɖ ɟ ɡ plosive (retroflex, palatal, velar)
	[0.5, 8, 14, 19, 47, 52, 53],
	# dʒ tʃ sh-like
	[0.5, 10, 29],
	# d t
	[0.5, 9, 28],
	# b p bilabial
	[0.5, 7, 25],
	# f h s v x z ð ɕ ɣ ʂ ʃ ʒ θ fricative
	[0.5, 13, 15, 27, 32, 34, 36, 38, 46, 54, 63, 64, 68, 70],
	# l m n ŋ ɱ ɲ nasal
	[0.5, 20, 21, 22, 40, 58, 59],
	# j r ɹ ɾ flap,trill
	[0.5, 18, 26, 61, 62],
	# ʔ glottalstop (only one phone means the code below skips it)
	[0.5, 69],
	# #71 #72 #73 #75 #77 #79 #82 #83 #84
	[0.5, 71,72,73,74,75,76,77,78,79,80,81,82,83,84]
);

# For each row, the distance between any two phones therein
# is the number at the start of the row.
for my $class (@classes) {
	my @classx =  @$class;
	my $dist = shift @classx;
	for my $j (@classx) {
		for my $k (@classx) {
			print "$j $k $dist\n" if ($j ne $k);
		}
	}
}

foreach my $i (@phones) {
	print "- $i $disttodel\n$i - $disttodel\n";
}
