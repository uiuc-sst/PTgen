#!/usr/bin/env ruby
# encoding: utf-8

# Report the lengths of the words in a set of transcriptions.

words = File.readlines("/tmp/Exp/tigrinya/hypotheses.txt.restitched.txt").map {|l| l.chomp.strip.split(' ')[1..-1]} .flatten .sort
words.map! {|w| w.size}
a = Array.new(words.max + 1){0}
words.each {|w| a[w] += 1} # Build histogram.
a.map! {|c| c.to_f/words.size * 100.0} # Convert counts to percentages.
puts "Length\t%"
a.each_with_index {|x,i|
  next if i==0
  puts "#{i}\t#{'%.2f' % x}"
}
