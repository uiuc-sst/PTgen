#!/usr/bin/env ruby
# encoding: utf-8

# Input: ref_train_text, where each line is: uttid, tab, space-delimited phones.
# Output: uttid, tab, space-delimited phone-index.

# Convert each phone to its index in phones.txt.
# As a string, not an int, for easier join()ing.
phones = {}
File.readlines("../../mcasr/phones.txt") .map {|l| l.split} .each {|p,i| phones[p] = i}
# Brittle: ../../mcasr assumes an invocation: cd PTgen/test/something; ../../run.sh settings.

raw = ARGF.readlines.map {|l| l.split}

# Report phones in the input that lie outside mcasr/phones.txt.
if false
  unmapped = []
  raw.each {|l| l[1..-1].each {|ph| unmapped << ph if !phones[ph] }}
  unmapped.uniq.sort.each {|ph| puts ph}
  exit 0
end

# Restrict the set of phones, just like mcasr/phonelm/make-bigram-LM.rb.
$restrict = Hash[ 
  "aɪ", "a",
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
  "œ", "æ",
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

# Because some phones in $restrict map to more than one phone, we can't just extend phones[].
# Instead, convert each line (an array) back to a string, for actual string substitution.
raw.each {|l|
  m = l[0] + " "
  l[1..-1].each {|phIn|
    phOut = phones[phIn]
    if !phOut
      phOut = $restrict[phIn].split.map {|p| phones[p]} .join(" ")
      # STDERR.puts "#{phIn} -> #{$restrict[phIn]} -> #{phOut}"
    end
    if !phOut
      STDERR.puts "#$0: skipping unmapped phone #{phIn}, fyi #{phones[phIn]} #{phones[$restrict[phIn]]}\n\n"
      next
    end
    m += phOut + " " # phOut may itself have spaces, e.g. "ɛ ə"
  }
  puts m.strip.split.join(" ")
}
