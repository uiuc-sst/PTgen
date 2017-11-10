#!/usr/bin/env ruby
# encoding: utf-8

# Input: ref_train_text, where each line is: uttid, tab, space-delimited phones.
# Output: uttid, tab, space-delimited phone-index.

# Convert each phone to its index in phones.txt.
# As a string, not an int, for easier join()ing.
Phones = Hash[File.read("../../mcasr/phones.txt").split(/\s+/)]
# Brittle: ../../mcasr assumes an invocation: cd PTgen/test/something; ../../run.sh settings.

raw = ARGF.readlines.map {|l| l.split}

# Restrict the set of phones, just like mcasr/phonelm/make-bigram-LM.rb.
$restrict = Hash[ 
  "aɪ", "ɑɪ",
  "bː", "b",
  "dː", "d",
  "eɪ", "ei",
  "eː", "e",
  "fː", "f",
  "hː", "h",
  "jː", "j",
  "kʰ", "k",
  "kː", "k",
  "lː", "l",
  "mː", "m",
  "nː", "n",
  "pʰ", "p",
  "q", "k",
  "rː", "r",
  "sː", "s",
  "ts", "t s",
  "tʃʰ", "tʃ",
  "tʰ", "t",
  "tː", "t",
  "zː", "z",
  "œ", "ɚ",
  "ɑɻ", "ɑ",
  "ɒ", "ɑ",
  "ɔɪ", "ɔi",
  "ɛə", "ɛ ə",
  "ɟʝ", "ɟ j",
  "ɦ", "h",
  "ɫ", "ɨ",
  "ɻ", "ɟ",
  "ʃː", "ʃ",
  "ʕ", " " # A space, not the empty string, to distinguish it from an unmapped phone.
]

# Because some phones in $restrict map to more than one phone, we can't just extend Phones[].
# Instead, convert each line (an array) back to a string, for actual string substitution.
raw.each {|l|
  m = l[0] + " "
  l[1..-1].each {|phIn|
    phOut = Phones[phIn]
    if !phOut
      phNew = $restrict[phIn]
      if !phNew
	STDERR.puts "#$0: internal error mapping phone '#{phIn}'. Aborting."
	STDERR.puts "Add these phones, missing from mcasr/phones.txt, to #$0's \$restrict:\n\
	  #{raw.map {|l| l[1..-1].select {|ph| !Phones[ph] && !$restrict[ph]}} .flatten.uniq.sort.join(' ')}"
	exit 1
      end
      phOut = phNew.split.map {|p| Phones[p]} .join(" ")
      # STDERR.puts "#{phIn} -> #{phNew} -> #{phOut}"
    end
    if !phOut
      STDERR.puts "#$0: skipping unmapped phone '#{phIn}'."
      next
    end
    m += phOut + " " # phOut may itself have spaces, e.g. "ɛ ə"
  }
  puts m.strip.split.join(" ")
}
