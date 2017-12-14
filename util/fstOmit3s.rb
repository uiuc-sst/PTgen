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

$phones = []
$lookup = Hash.new
File.read(ARGV[0]).split(/\s+/).each_slice(2).to_a .map {|phone,i| [i.to_i, phone]} .each {|i,phone|
  $phones[i] = phone
  $lookup[phone] = i
}
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
  # syms	["88", "88"], ["65", "65"], ["58", "58"]
  syms = symsFull.map {|a| a[0].to_i}
  skip3 = false
  if !syms.include? Three
    # Three-free, so echo all arcs.
  else
    syms -= [Three]
    if syms.empty?
      # Empty, so echo all arcs.
    else
      # Non-#3 phones.
      numVowels = (syms & Nonconsonants).size
      # numConsonants = syms.size-numVowels
      # puts "#{numVowels} vowels and #{numConsonants} consonants in #{syms.map{|i| $phones[i]}}."
      if numVowels == 0
	#puts "Suppress #3 because all-consonant #{syms.map{|i| $phones[i]}}."
	skip3 = true
      else
	#puts "Vowels in #{syms.map{|i| $phones[i]}}, so echo all arcs."
      end
    end
  end
  symsFull.each {|a|
#   puts "dude #{a} #{a[0].to_i}" if skip3
    next if skip3 && a[0].to_i == Three
    puts "#{states[0]}\t#{states[1]}\t#{a.join(' ')}"
  }
}
puts finalstate
