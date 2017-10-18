#!/usr/bin/env ruby

# Reads sbs-phone-transcriptions.txt, from mcasr/sbs-get-transcriptions.rb.
# Reformats it like PTgen stage 1's Exp/uzbek/transcripts.txt.

$scrips = "sbs-phone-transcriptions.txt"
Clipnames = `cut -f 1 -d ' ' < #$scrips | sed 's/....$//' | uniq` .split("\n")
# e.g., part-2-hungarian_141004_365048-11

# Convert each phone to its index in phones.txt.
# As a string, not an int, for easier join()ing.
Phones = Hash[*File.read("phones.txt").split(/\s+/)]

# This takes 4.5 minutes.  Inefficient because n greps is a quadratic algorithm,
# but faster to code than a single-pass parse of $scrips, which is better for
# a script that runs only once.
Clipnames.each {|n|
  scrips = `grep #{n} #$scrips | sed -e 's/[^ ]* //' -e 's/_[BEIS]//g'` .split("\n")
  # scrips[9] = e.g., oʊ v ɑ t u m i SIL ʌ SIL
  nNew = n.sub '-0', '-'
  scrips.map! {|s| s.split(" ") .map {|phone| Phones[phone]} .join(" ")}
  puts "#{nNew}:#{scrips.join " # "}"
}
