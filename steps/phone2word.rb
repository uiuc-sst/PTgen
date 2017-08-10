#!/usr/bin/env ruby
# encoding: utf-8

# Convert phone strings to word strings using a trie.
# Very fast, but unlikely to be optimal.

# Word, tab, space-delimited phones.
Prondict = "/r/lorelei/mcasr/phonelm/prondict_uzbek-from-wenda.txt"
$phoneFile="/r/lorelei/PTgen/mcasr/phones.txt"

require "trie" # gem install fast-trie
trie = Trie.new
h =  Hash.new {|h,k| h[k] = []} # A hash mapping each pronunciation to an array of homonym words.
i = 0
STDERR.puts "#$0: reading pronlex..."
begin
  pd = File.readlines(Prondict).map {|l| l.chomp.strip.split("\t") }
  # Cull words with 5 or more in a row of the same letter or letter-pair ("hahahahaaaaaaa").
  # https://regex101.com/r/pJ3hJ9/1
  pd.select! {|w,p| w !~ /(.)\1{4,}/ }
  pd.select! {|w,p| w !~ /(..)\1{4,}/ }

  # Like mcasr/phonelm/make-bigram-LM.rb and mcasr/stage1.rb.
  pd.select! {|w,p| p !~ / ABORT$/}
  Restrict = Hash[ "d̪","d", "q","k", "t̪","t", "ɒ","a", "ɨː","iː", "ɸ","f", "ʁ","r", "χ","h" ]
  pd.map! {|w,p| [w, p.split(" ").map {|ph| r=Restrict[ph]; r ? r : ph}]}
  $phones = {};
  $phonesRev = {};
  File.readlines($phoneFile) .map {|l| l.split} .each {|p,i| $phones[p] = i; $phonesRev[i] = p}

  # Convert each pronunciation's entries from a phone to the phone's index in the symbol table.
  # Convert each phone, then join the array back into a string, for the trie.
  pd.map! {|w,pron| [w, pron.map {|ph| $phones[ph]} .join(" ")] }

  pd.each {|w,p| trie.add p; i += 1 }
  pd.each {|w,p| h[p] << w }
end
STDERR.puts "#$0: loaded #{i} pronunciations from pronlex.  Converting utterance transcriptions from phones to words..."
# Now trie has all the pronunciations, and h has all the homonyms.

# Parse and convert hypotheses.txt from STDIN, one line at a time.
# Each line is uttid, tab, space-delimited phone-numbers.
while l = gets
  uttid,phones = l.chomp.split("\t")
  print uttid + "\t"
  phones = phones.split(" ")
  prefix = ""
  prefixPrev = ""
  i = 0
  iStart = 0
  while i < phones.size
    prefixPrev = prefix.rstrip
    prefix += phones[i] + " "
    if trie.has_children?(prefix.rstrip)
      # Extend prefix.
      i += 1
      next
    end
    if trie.has_key? prefixPrev
      iStart = i
      words = h[prefixPrev]
      word = words[rand(words.size)] # Choose a homonym at random.
      print word + " "
    else
      # Word search failed.  Skip this phone.  Resume searching, one phone past the previous attempt.
#     puts "\nSKIPPED " + phones[iStart] + " " + $phonesRev[phones[iStart]]
      iStart = i = iStart+1
    end
    prefix = ""
  end
  puts
end
STDERR.puts "#$0: done."
