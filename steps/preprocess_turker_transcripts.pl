#!/usr/bin/perl
#
# Preprocess English text obtained from crowd workers.
# Valid English words are looked for in an English dictionary 
# (CMUDict) and replaced with their pronunciations, if found.

use Text::CSV_XS;
$argerr = 0;
$multiletter = 0;

while ((@ARGV) && ($argerr == 0)) {
	if($ARGV[0] eq "--multiletter") {
		shift @ARGV;
		$multiletter = 1;
	} elsif ($dictfile eq "") {
		$dictfile = shift @ARGV;
	} else {
		print STDERR "Unknown argument:  $ARGV[0]\n";
		$argerr = 1;
	}
}

if($argerr != 0) {
	print "usage: script <arg1: dictionary>\nInput: Batch turker csv\nOutput:Filtered to a # separated set of strings\n";
	exit(0);
}

$csvworkeridindex = 15;
$csvassgnstatus = 16;
@omitstrings = ("empty","none","blank","nothing","null","nil","music");
$dictonlylimit = 2; # words longer than $dictonlylimit will be restricted to the dictionary pronunciation only,

%digits2wrds = (
	"0" => "zero", "1" => "one","2" => "two","3" => "three","4" => "four","5" => "five","6" => "six","7" => "seven","8" => "eight","9" => "nine",
);

%lets2wrds = (
	"a" => "a", "b" => "bee", "c" => "see", "d" => "dee", "e" => "ee", "f" => "ef", "g" => "gee", "h" => "ech", "i" => "ai", "j" => "je", "k" => "ke", "l" => "el", "m" => "em", "n" => "en", "o" => "o", "p" => "pee", "q" => "kyoo", "r" => "ar", "s" => "es", "t" => "tee", "u" => "yoo", "v" => "vee", "w" => "dabalyoo", "x" => "eks", "y" => "wai", "z" => "zee", 
);

%eng_phonemes2letters = (
	"aa" => "a",
	"ae" => "a",
	"ah" => "a",
	"ao" => "oa",
	"aw" => "aw",
	"ax" => "a",
	"ay" => "ai",
	"b" => "b",
	"ch" => "ch",
	"d" => "d",
	"dh" => "d",
	"eh" => "e",
	"el" => "el",
	"en" => "en",
	"er" => "er",
	"ey" => "ey",
	"f" => "f",
	"g" => "g",
	"hh" => "h",
	"ih" => "i",
	"iy" => "ee",
	"jh" => "j",
	"k" => "k",
	"l" => "l",
	"m" => "m",
	"n" => "n",
	"ng" => "ng",
	"ow" => "o",
	"oy" => "oy",
	"p" => "p",
	"r" => "r",
	"s" => "s",
	"sh" => "sh",
	"t" => "t",
	"th" => "th",
	"uh" => "u",
	"uw" => "uw",
	"v" => "v",
	"w" => "w",
	"y" => "y",
	"z" => "z",
	"zh" => "s",
);

binmode STDIN, ':utf8';

open(DICT, $dictfile);

%dict_entries = ();

while(<DICT>) {
	chomp;
	($wrd, $prn) = split(/\:/);
	$prn =~ s/^\s+//g; $prn =~ s/\s+$//g;
	if(!exists $dict_entries{$wrd}) {
		$dict_entries{$wrd} = $prn;
	}
}
close(DICT);

$csv = Text::CSV_XS->new ({
      binary    => 1, # Allow special character. Always set this
      auto_diag => 1, # Report irregularities immediately
      });

# Determining the number of clips in each HIT
$numclipscheckfield = 37; 
$ignore = $csv->getline (STDIN);
@csvmturkmp3indices = ();
@csvmturktxtindices = ();
if($ignore->[$numclipscheckfield] =~ /audio/) {
	@csvmturkmp3indices = (27,29,31,33,35,37,39,41);
	@csvmturktxtindices = (45,46,47,48,49,50,51,52);
} else {
	@csvmturkmp3indices = (27,29,31,33);
	@csvmturktxtindices = (37,38,39,40);
}

%turker_transcripts = ();
while (my $fields = $csv->getline (STDIN)) {
	$assgnstatus = $fields->[$csvassgnstatus];
	for($i = 0; $i <= $#csvmturktxtindices; $i++) {
		$string = "";
		$filename = $fields->[$csvmturkmp3indices[$i]];
		$filename =~ s:(.*)\/(part-.*\/[^\/]*)\.mp3:\2:g;
		last if($filename =~ /^\s*$/);
		$filename =~ s:\/:-:g;

		$mturkstring = $fields->[$csvmturktxtindices[$i]];
		$mturkstring =~ s/^\s+//g; $mturkstring =~ s/\s+$//g;
		$mturkstring =~ s/[\?\!\,\:\;\.\-]/ /g; # remove question marks, exclamation, etc
		$mturkstring =~ s/voice [0-9]//g; #naming voices 
		$mturkstring =~ s/\"\<\>\*//g; #remove quotes, angular brackets
		$mturkstring =~ s/\s+/ /g; #replacing multiple spaces with a single space
		$omit = 0;
		# Move to the next clip if text is one of the omitstrings
		foreach $ostr (@omitstrings) {
			$lostr = lc($ostr);
			$omit = 1 if($mturkstring =~ /^\s*$ostr\s*$/ || $mturkstring =~ /^\s*$lostr\s*$/);
		}
		next if($omit == 1);
		$numwrds = () = split /\s+/, $mturkstring;
		$mturkstring =~ s/[\[\]]//g if($mturkstring =~ /^\s*(\[.*\])*\s*$/ && $numwrds > 0); #removing [,], if all the words enclosed within it
		$mturkstring =~ s/\[.*\]//g;  #removing everything else enclosed within [], e.g. [uh],[um] disfluencies
		$mturkstring =~ s/\{.*\}//g;
		$mturkstring =~ s/\(.*\)//g;
		$mturkstring =~ s/^\s+//g; $mturkstring =~ s/\s+$//g;
		$mturkstring = lc($mturkstring);

		if($mturkstring ne "" && $assgnstatus eq "Approved") {
			@words = split(/\s+/,$mturkstring);
			for($w = 0; $w <= $#words; $w++) {
				if($words[$w] =~ /^\s*[0-9]+\s*$/) {
					$digwrds = digit2wrd($words[$w]);
					$mturkstring =~ s/$words[$w]/$digwrds/g;
				}
			}
			@words = split(/\s+/,$mturkstring);
			for($w = 0; $w <= $#words; $w++) {
				if($words[$w] !~ /\[.*\]/) { #omit laugh, uh, umm
					$words[$w] =~ s/[^a-zA-Z]/ /g;
					@letters = split(//,$words[$w]);
					# if $dictonlylimit is non-negative, then words of length
					# $dictonlylimit or more are replaced by their first
					# pronounciation from the dictionary.
					if($dictonlylimit > 0 && $#letters >= $dictonlylimit && exists $dict_entries{$words[$w]}) {
						$prn = $dict_entries{$words[$w]};
						@phonemes = split(/\s+/, $prn);
						$prnx="";
						foreach $phm (@phonemes) {
							$prnx = $prnx."$eng_phonemes2letters{$phm}";
						}
						$words[$w] = $prnx;
					}

					$words[$w] = $lets2wrds{$words[$w]} if($words[$w] =~ /^\s*[A-Z]\s*$/);
					$words[$w] = multiletterfilter($words[$w]) if ($multiletter == 1);

					$words[$w] =~ s/(.)/\1 /g; #separating each letter by a space
					$string .= $words[$w];
				}
			}
			$string =~ s/\s+$//g; $string =~ s/^\s+//g;
			$string =~ s/\s+/ /g;
			$turker_transcripts{$filename}.="#$string";
		}
	}
}


foreach $key (sort keys %turker_transcripts) {
	$trans = $turker_transcripts{$key};
	$trans =~ s/^#//g;
	print "$key:$trans\n";
}

sub multiletterfilter {
	($word) = @_;	
	$word =~ s/bh/B/g;
	$word =~ s/ch/C/g;
	$word =~ s/dh/D/g;
	$word =~ s/gh/G/g;
	$word =~ s/jh/J/g;
	$word =~ s/kh/K/g;
	$word =~ s/ph/f/g;
	$word =~ s/sh/S/g;
	$word =~ s/th/T/g;
	$word =~ s/wh/w/g;
	$word =~ s/zh/Z/g;

	$word =~ s/oo/U/g;
	$word =~ s/ee/E/g;
	$word =~ s/ay/Y/g;
	$word =~ s/ai/Y/g;
	$word =~ s/aw/O/g;

	$word =~ s/ck/k/g;

	return $word;
}

sub digit2wrd {
	my $num = shift;
	my $text = "";
	$num =~ s/\s+//g;
	@digs = split(//,$num);
	foreach $d (@digs) {
		$text .= $digits2wrds{$d}." ";
	}
	$text =~ s/\s*$//g;
	return $text;
}
