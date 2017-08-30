#!/usr/bin/env ruby
# encoding: utf-8

# Report the lengths of the words in a set of transcriptions.

$in = "/home/camilleg/l/PTgen/native-scrips-il5/transcription.txt"
$in = "/home/camilleg/l/PTgen/Exp/oromo/hypotheses.txt.restitched.txt"
$in = "/home/camilleg/l/PTgen/Exp/tigrinya/hypotheses.txt.restitched.txt"

words = File.readlines($in).map {|l| l.chomp.strip.split(' ')[1..-1]} .flatten .sort

# Print the alphabet.
if false
  letters = words.join("").split(//).uniq
  p letters # .size == 139
  exit 0
end

# Print the 1-letter words.
if false
  words.select! {|w| w.size==1}
  words.uniq!
  p words.sort # .size == 40
  exit 0
end

words.map! {|w| w.size}
a = Array.new(words.max + 1){0}
words.each {|w| a[w] += 1} # Build histogram.
a.map! {|c| c.to_f/words.size * 100.0} # Convert counts to percentages.
puts "Length\t%"
a.each_with_index {|x,i|
  next if i==0
  puts "#{i}\t#{'%.2f' % x}"
}
