#!/usr/bin/env ruby
# encoding: utf-8

# Filter for openfst text format FSA's built by steps/decode_PTs.sh.
# For each pair of states with a set of arcs from the first to the second,
# if the non-#3 arcs are mostly (actually only) consonants,
# delete the #3 arcs.
# This discourages steps/eval from skipping consonants,
# because it's rarer for a turker to insert a spurious consonant
# than a spurious phone (between two ground-truth consonants).
# A mix of vowels and consonants is rare in practice,
# so just do the all-consonants case.

if ARGV.size != 1
  STDERR.puts "Usage: #$0 univ.compact.txt"
  exit 1
end

$lookup = Hash.new
File.read(ARGV[0], :encoding => 'utf-8').split(/\s+/).each_slice(2) {|phone,i| $lookup[phone] = i.to_i }
Three = $lookup["#3"] # Likely 88.

# Fewer vowels than consonants.
Nonconsonants = [
  "<eps>", "sil", "spn", "a", "aɪ", "aʊ", "aː", 
  "eɪ", "eː",
  "i", "iː",
  "o", "oʊ",
  "u", "uː",
  "y",
  "æ", "œ", "ɑ", "ɑɻ", "ɒ", "ɔ", "ɔɪ", "ə", "ɛ", "ɛə", "ɪ", "ʊ", "ʌ",
  "#0", "#1", "#2", "#3"
].map {|phone| $lookup[phone]}

# Read the input all at once, because it's not even a MB.
lines = STDIN.readlines .map(&:split)

# Split lines into state-pairs (first 2 columns).
pairs = Hash.new {|k,v| k[v] = []}
finalstate = nil
lines.each {|l|
  case l.size
    when 1 then finalstate = l[0]
    when 4..5 then pairs[l[0..1]] << l[2..-1]
    else STDERR.puts "#$0: ignoring unexpected line '#{l}'."
  end
}
pairs.each {|states,symsFull|
  # states	["6", "7"]
  # symsFull	["88", "88"], ["65", "65"], ["58", "58"]; maybe with weights too
  syms = symsFull.map {|a| a[0].to_i}
  skip3 = false
  if syms.include? Three
    syms -= [Three]
    # Skip the #3 arc if syms had only consonants (but wasn't empty).
    skip3 = !syms.empty? && (syms & Nonconsonants).empty?
  end
  symsFull.each {|a|
    next if skip3 && a[0].to_i == Three
    puts "#{states[0]}\t#{states[1]}\t#{a.join(' ')}"
  }
}
puts finalstate
