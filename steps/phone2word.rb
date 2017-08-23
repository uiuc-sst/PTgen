#!/usr/bin/env ruby
# encoding: utf-8

# Convert phone strings to word strings using a trie.
# Very fast, but unlikely to be optimal.

if ARGV.size != 1
  STDERR.puts "Usage: #$0 pronlex.txt < hypotheses-as-phones.txt > hypotheses-as-words.txt"
  exit 1
end
# Word, tab (or space), space-delimited phones.
Prondict = ARGV[0]
if !File.file? Prondict
  STDERR.puts "#$0: missing pronlex #{Prondict}."
  exit 1
end

$phoneFile="../../mcasr/phones.txt"
if !File.file? $phoneFile
  STDERR.puts "#$0: missing list of phones #$phoneFile."
  exit 1
end

begin
  require "trie" # gem install fast-trie
rescue LoadError
  require "/home/camilleg/gems/fast_trie-0.5.1/ext/trie.so" # ifp-53
end
trie = Trie.new
h =  Hash.new {|h,k| h[k] = []} # A hash mapping each pronunciation to an array of homonym words.
i = 0

STDERR.puts "#{File.basename $0}: reading pronlex #{Prondict}..."
begin
  pd = File.readlines(Prondict) .map {|l| l.chomp.strip }
  # If the prondict's lines are [word SPACE spacedelimited-phones], change them to [word TAB spacedelimited-phones].
  pd.map! {|l| l =~ /\t/ ? l : l.sub(" ", "\t")}
  pd.map! {|l| l.split("\t") }
  # Cull words with 4 or more in a row of the same letter or letter-pair ("hahahahaaaaaaa").
  # https://regex101.com/r/pJ3hJ9/1
  pd.select! {|w,p| w !~ /(.)\1{3,}/ && w !~ /(..)\1{3,}/ }

  # Compress tripled-or-more letters "aaa" to doubled letters "aa".
  # (Tripled letters are in *some* valid words,
  # https://linguistics.stackexchange.com/q/9713/17197,
  # but they are much rarer than what shows up in Prondict (e.g. Oromo),
  # so optimize for the common case.)
  pd.map! {|w,p| [w.gsub(/(.)\1{2,}/, '\1\1'), p]}
  pd.sort!
  if false
    # Report any duplicated word with different pronunciations.  Rare, in practice.
    (pd.size-1).times {|i|
      if pd[i][0] == pd[i+1][0] && pd[i][1] != pd[i+1][1]
	STDERR.puts pd[i]; STDERR.puts pd[i+1]
      end
    }
  end
  pd.uniq!

  if Prondict.downcase =~ /rus/
    # For Russian, cull any word with a digit, or with 3+ consecutive latin letters.
    # todo: somehow handle [ and ], they're pretty rare.  And (usually trailing) "…".
    pd.select! {|w,p| w !~ /[0-9]/ && w !~ /[a-z]{3,}/ }
  end

  pd.map! {|w,p| [w, p.split(" ") .chunk {|x| x} .map(&:first) .join(" ")]} # Remove consecutive duplicate phones.

  # Like mcasr/phonelm/make-bigram-LM.rb and mcasr/stage1.rb.
  pd.select! {|w,p| p !~ / ABORT$/}
  Restrict = Hash[ "d̪","d", "q","k", "t̪","t", "ɒ","a", "ɨː","iː", "ɸ","f", "ʁ","r", "χ","h" ]
  pd.map! {|w,p| [w, p.split(" ").map {|ph| r=Restrict[ph]; r ? r : ph}]}
  $phones = {};
  $phonesRev = {};
  File.readlines($phoneFile) .map {|l| l.split} .each {|p,i| $phones[p] = i; $phonesRev[i] = p}

  # Convert each pronunciation's entries from a phone to the phone's index in the symbol table.
  # Convert each phone, then join the array back into a string, for the trie.
  pd.map! {|w,pron| [w, pron.map {|ph| $phones[ph]} .join(" ") .gsub(/\s+/, ' ') .strip] }

  pd.each {|w,p| trie.add p; i += 1 }
  pd.each {|w,p| h[p] << w }
end
# File.open("/tmp/prondict-reconstituted.txt", "w") {|f| h.each {|pron,words| f.puts "#{pron}\t\t#{words.join(' ')}"} }
STDERR.puts "#{File.basename $0}: loaded #{i} pronunciations from pronlex.  Converting utterance transcriptions from phones to words..."
# Now trie has all the pronunciations, and h has all the homonyms.


# Parse and convert hypotheses.txt from STDIN, one line at a time.
# Each line is uttid, tab, space-delimited phone-numbers.
$stdin.each_line {|l|
  uttid,phones = l.chomp.split("\t")
  print uttid + "\t"
  if !phones
    # Empty pronunciation.
    puts
    next
  end
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
      i = iStart = i+1
      words = h[prefixPrev]
#     puts "\nPick one of: #{words.join(' ')}";
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
}
STDERR.puts "#{File.basename $0}: done."
