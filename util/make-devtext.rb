#!/usr/bin/env ruby
# encoding: utf-8

# Make data/nativetranscripts/uzbek/dev_text = $evalreffile
# from Shukhrat's transcriptions,
# not split into short mp3 clips,
# as words rather than phones.

Dir.glob("/r/lorelei/dry/train-and-test/shukhrat/*domain/UZB*.txt") {|u|
  # Strip invalid byte sequences from UTF-8 with the valid_encoding? stanza.
  # Strip [foo] and punctuation.
  # Strip spaces from numbers like 7 000 000.  Only 000, not more generally.
  # Coalesce whitespace.
  scrip = File.readlines(u) .map(&:chomp) .join(" ") \
    .chars.select{|i| i.valid_encoding?}.join \
    .downcase .gsub(/\[[^\]]+\]/, '') .gsub(/[,?!"\.]/, '') .gsub(" - ", " ") \
    .gsub(/(?<=[0-9]) (?=000)/, '') \
    .gsub(/[\s]+/, ' ') .strip
  puts "#{File.basename u, '.txt'} #{scrip}"
}
