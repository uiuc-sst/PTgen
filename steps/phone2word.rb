#!/usr/bin/env ruby
# encoding: utf-8

# Convert phone strings to word strings using a trie.
# Very fast, but unlikely to be optimal.

if ARGV.size > 2
  STDERR.puts "Usage: #$0 prondict.txt [mtvocab.txt] < hypotheses-as-phones.txt > hypotheses-as-words.txt"
  # STDIN must be sorted, for prepending SIL to noncontiguous clips.
  # todo: check that it's sorted.
  exit 1
end

$phoneFile="../../mcasr/phones.txt"
if !File.file? $phoneFile
  STDERR.puts "#$0: missing list of phones #$phoneFile."
  exit 1
end

# Word, tab (or space), space-delimited phones.
Prondict = ARGV[0]
if !File.file? Prondict
  STDERR.puts "#$0: missing prondict #{Prondict}."
  exit 1
end

$vocab = nil
if ARGV.size == 2
  $vocab = ARGV[1]
  if !File.file? $vocab
    STDERR.puts "#$0: no such MT in-vocab list #$vocab.  Proceeding without vocab."
    # $vocab is words recognized by ISI's machine translation.  One word per line.
  end
end

# Read all of $stdin into RAM, because it's not even a few megabytes.
Lines = $stdin.readlines.map {|l| l.split /\s/}

if Lines[0][0].size < 20
  # Don't restitch.  Build $scrips directly from each l.  l[0] == "uzbek_019_006"
  $scrips = Lines.map {|l| [l[0], l[1..-1].join(' ')]}
else
  # First, concatenate clips' phone-transcriptions into phone-transcriptions of full utterances.
  # Each line is uttid, tab, space-delimited phones from $phnalphabet aka $DATA/phonesets/univ.compact.txt.
  # (These transcriptions were made by steps/evaluate_PTs.sh calling # fstprint --osymbols=$phnalphabet.)
  # (But test/mcasr-uzb/data/phonesets/univ.compact.txt was phone-indices, while test/apply-uzb/...univ.compact.txt is IPA??)
  $scrips = Hash.new {|h,k| h[k] = []} # Map each uttid to an array of transcriptions.
  $endtimePrev = -1
  $uttidPrev = uttid = "bogus"
  Lines.each {|l|
    s = l[1..-1].join(" ")				# иисусу хоста иаа
    next if s.empty?
    if false						# todo: find the penultimate _ and split there.
      $uttidPrev = uttid
      uttid = l[0][0..15]				# IL5_EVAL_019_012
      starttime = l[0][17..-1].sub(/_.*/, '').to_i	# 101824705
      $endtimePrev = l[0][27..-1].to_i
    elsif false
      uttid = l[0][0..10]				# RUS_134_004
      starttime = l[0][12..-1].sub(/_.*/, '').to_i	# 101824705
    else
      # PTgen/test/apply-uzb
      uttid = l[0][0..10]				# UZB_001_001
      starttime = l[0][12..-1].sub(/_.*/, '').to_i	# 003320_004427 -> 003320
      $endtimePrev = l[0][12..-1].sub(/[^_]*_/, '').to_i # 004427
    end

    # Prepend SIL if this clip wasn't immediately after the previous one.
#   s = "1 " + s if $endtimePrev >= 0 && $endtimePrev+1 < starttime	# for mcasr?
    s = "SIL " + s if $endtimePrev >= 0 && $endtimePrev+1 < starttime	# for non-mcasr?

    $scrips[uttid] << [starttime, s]
    $endtimePrev = -1 if uttid != $uttidPrev
  }
  $scrips = $scrips.to_a.sort_by {|uttid,ss| uttid}
  $scrips.map! {|uttid,ss| [uttid, ss.sort_by {|t,s| t}]}      # Within each uttid, sort the $scrips by time.
  $scrips.map! {|uttid,ss| [uttid, ss.transpose[1].join(' ')]} # Within each uttid, concat its $scrips.
  #$scrips.each {|uttid,ss| puts "#{uttid} #{ss}"} # e.g., IL6_EVAL_024_013 53 42 15 56 22 42 44 28 30 19 ...
end

begin
  require "trie" # gem install fast-trie
rescue LoadError
  require "/home/camilleg/gems/fast_trie-0.5.1/ext/trie.so" # ifp-53
end
trie = Trie.new
h =  Hash.new {|h,k| h[k] = []} # A hash mapping each pronunciation to an array of homonym words.
i = 0

STDERR.puts "#{File.basename $0}: reading prondict #{Prondict}..."
begin
  pd = File.readlines(Prondict) .map {|l| l.chomp.strip }
  # If the prondict's lines are [word SPACE spacedelimited-phones], change them to [word TAB spacedelimited-phones].
  pd.map! {|l| l =~ /\t/ ? l : l.sub(" ", "\t")}
  pd.map! {|l| l.split("\t") }
  if false
    require 'set'
    Shukhrat = Set.new( File.readlines("/home/camilleg/l/PTgen/test/apply-uzb/shukhrat-words-cleaned.txt") \
      .map {|l| l.chomp})
    pd.select! {|w,p| Shukhrat.include? w }
    STDERR.puts "#{File.basename $0} (#{pd.size}): keeping only Shukhrat's #{Shukhrat.size} words."
  end
  STDERR.puts "#{File.basename $0} warning: prondict has only #{pd.size} words." if pd.size < 10
  STDERR.puts "#{File.basename $0} (#{pd.size}): culling 4-in-a-rows..."
  # Cull words with 4 or more in a row of the same letter or letter-pair ("hahahahaaaaaaa").
  # https://regex101.com/r/pJ3hJ9/1
  pd.select! {|w,p| w !~ /(.)\1{3,}/ && w !~ /(..)\1{3,}/ }

  STDERR.puts "#{File.basename $0} (#{pd.size}): shrinking 3-in-a-rows..."
  # Compress tripled-or-more letters "aaa" to doubled letters "aa".
  # (Tripled letters are in *some* valid words,
  # https://linguistics.stackexchange.com/q/9713/17197,
  # but they are much rarer than what shows up in Prondict (e.g. Oromo),
  # so optimize for the common case.)
  pd.map! {|w,p| [w.gsub(/(.)\1{2,}/, '\1\1'), p]}
  STDERR.puts "#{File.basename $0} (#{pd.size}): sorting..."
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

  STDERR.puts "#{File.basename $0} (#{pd.size}): de-duplicating phones..."
  pd.map! {|w,p| [w, p.split(" ") .chunk {|x| x} .map(&:first) .join(" ")]} # Remove consecutive duplicate phones.

  STDERR.puts "#{File.basename $0} (#{pd.size}): restricting phones..."
  # Like mcasr/phonelm/make-bigram-LM.rb and mcasr/stage1.rb.
  pd.select! {|w,p| p !~ / ABORT$/}
  Restrict = Hash[ "d̪","d", "q","k", "t̪","t", "ɒ","a", "ɨː","iː", "ɸ","f", "ʁ","r", "χ","h",
  	"ʷa","a", "[section]","eps", "[clause]","eps", "[phrase]","eps", "[semicolon]","eps", "[colon]","eps", "[preface_colon]","eps", "[question]","eps", "[paragraph]","eps",
  	]
  pd.map! {|w,p| [w, p.split(" ").map {|ph| r=Restrict[ph]; r ? r : ph}]}
  STDERR.puts "#{File.basename $0} warning: prondict has only #{pd.size} words." if pd.size < 10
  Phones = Hash[*File.read($phoneFile).split(/\s+/)]

  if true
    # Soft match, like https://en.wikipedia.org/wiki/Soundex.
    # Remap phone indices to a smaller set of phone classes.
    $remap = Hash[
      # Relaxed: front/central vowels separate from back vowels.
      4,100, 5,100, 6,100, 11,100, 12,100, 16,100, 17,100, 35,100, # aeiy aʊ aː ei iː
      37,100, 39,100, 41,100, 43,100, 48,100, 49,100, 50,100, 51,100, 55,100, 56,100, 60,100, 65,100, # æ ɐ ɑɪ ø ɑ ɚ ɝ ɨ ɪ ʉ ə ɛ ɵ

      23,107, 24,107, 30,107, 31,107, 57,105, 44,107, 45,107, 42,107, 67,107, 54,107, # o oʊ u uː ɯ  ɔ ɔi ɑ ʌ ɣ

      15,101, 33,101, # hw
      38,101, 70,101, 68,101, # ð θ ʒ 
      7,102,         25,102,         # bp
             13,107,         32,107, # fv
      8,103, 10,103, 14,103, 18,103, 19,103, 27,103, 34,103, 36,103, # c dʒ gjksxz
      9,104, 28,104, 29,104, 63,104, 64,104, # dt tʃ ʂ ʃ 
      # l
      21,105, 22,105, # mn
      40,105, 52,105, 53,105, 58,105, 59,105, # ŋ ɟ ɡ  ɱ  ɲ 
      26,106, 61,106, 62,106, # r ɹ ɾ 
    ]
    def soft(ph)
      r = $remap[ph.to_i]
#     puts "#{ph} -> #{r}"
      r ? r.to_s : ph
    end
  else
    def soft(ph) ph end
  end

  STDERR.puts "#{File.basename $0} (#{pd.size}): soft match and indexifying..."
  # Convert each pronunciation's entries from a phone to the phone's index in the symbol table.
  # Convert each phone, then join the array back into a string, for the trie.
  pd.map! {|w,pron| [w, pron.map {|ph| soft(Phones[ph])} .join(" ") .gsub(/\s+/, ' ') .strip] }
  STDERR.puts "#{File.basename $0}: re-deduplicating phones..."
  pd.map! {|w,pron| [w, pron.split(" ").chunk{|x|x}.map(&:first) .join(" ")]}
  STDERR.puts "#{File.basename $0} warning: prondict has only #{pd.size} words." if pd.size < 10

  STDERR.puts "#{File.basename $0} (#{pd.size}): stuffing trie..."
  pd.each {|w,p| trie.add p; i += 1 }
  STDERR.puts "#{File.basename $0}: collecting homonyms..."
  pd.each {|w,p| h[p] << w }
  STDERR.puts "#{File.basename $0}: loaded #{i} pronunciations from prondict."
end

# Read in-vocab words.  Discard invalid UTF-8.  .toset, so .include? takes O(1) not O(n).
require 'set'
if !$vocab
  $wordsVocab = Set.new
else
  STDERR.puts "#$0: preferring words that are in-vocab for MT."
  $wordsVocab = File.readlines($vocab) .map(&:chomp) .map {|l| l.chars.select{|i| i.valid_encoding?}.join } .to_set
  # If a set of homonyms includes both in-vocab and oov words, keep only the in-vocab ones.
end
hNew = Hash.new
h.each {|pron,words|
  has_oov = false
  has_v = false
  words.each {|w|
    oov = !$wordsVocab.include?(w)
    has_oov |=  oov
    has_v   |= !oov
    if has_v && has_oov
      #prev = words.size
      # Set .include? is much faster than words &= $wordsVocab.
      words.select! {|w| $wordsVocab.include? w}
      #STDERR.puts "Reduced #{prev} in-v and oov words to #{words.size} in-v words, e.g. #{words[0]}."
      break
    end
  }
  hNew[pron] = words
}
h = hNew
# Now trie has all the pronunciations, and h has all the homonyms.

File.open("/tmp/prondict-reconstituted-uzb.txt", "w") {|f| h.each {|pron,words| f.puts "#{pron}\t\t#{words.join(' ')}"} }

STDERR.puts "#{File.basename $0}: Converting utterance transcriptions from phones to words..."
# Output the restitched and phone2word'ed transcriptions.
$scrips.each {|uttid,phones|
  print uttid + "\t"
  if !phones
    # Empty pronunciation.
    puts
    next
  end
  STDERR.puts "\nWordify #{phones}"
  phones = phones.split ' '
  STDERR.puts "\nWordify #{phones.map{|ph| soft(Phones[ph])}.join(' ') .gsub(/\s+/, ' ') .strip}"
  prefix = ""
  prefixPrev = ""
  i = 0
  iStart = 0
=begin
  debug = phones.map{|ph| soft(Phones[ph])}.join(' ') .gsub(/\s+/, ' ') .strip == "101 105" # Tigrinya example.
  if debug
    STDERR.puts "Try: #{phones.join(' ')}"
    STDERR.puts "Try: #{phones.map{|ph| soft(Phones[ph])}.join(' ') .gsub(/\s+/, ' ') .strip}"
  end
=end
  while i < phones.size
    foo = phones[i]
    bar = Phones[foo]
    if !bar
      # Remap unusual phones from Tigrinya MCASR transcriptions.
      # todo: improve this remapping, and reimplement it like Restrict[] above.
      case foo
	when 'aɪ' then foo = 'a'
	when 'bː' then foo = 'b'
	when 'dː' then foo = 'd'
	when 'ɛə' then foo = 'ɛ'
	when 'eː' then foo = 'e'
	when 'eɪ' then foo = 'e'
	when 'fː' then foo = 'f'
	when 'hː' then foo = 'h'
	when 'jː' then foo = 'j'
	when 'kː' then foo = 'k'
	when 'kʰ' then foo = 'k'
	when 'lː' then foo = 'l'
	when 'mː' then foo = 'm'
	when 'nː' then foo = 'n'
	when 'œ' then foo = 'æ'
	when 'ɔɪ' then foo = 'i'
	when 'pʰ' then foo = 'p'
	when 'q' then foo = 'k'
	when 'rː' then foo = 'r'
	when 'sː' then foo = 's'
	when 'ʕ' then foo = 'ʔ'
	when 'ʃː' then foo = 'ʃ'
	when 'ɒ' then foo = 'a'
	when 'ɦ' then foo = 'h'
	when 'ɫ' then foo = 'l'
	when 'ɫː' then foo = 'l'
	when 'ɟʝ' then foo = 'l'
	when 'ɻ' then foo = 'r'
	when 'ɑɻ' then foo = 'r'
	when 'ts' then foo = 's'
	when 'tʃʰ' then foo = 'ʃ'
	when 'tː' then foo = 't'
	when 'tʰ' then foo = 'θ'
	when 'zː' then foo = 'z'
      end
      bar = Phones[foo]
      if !bar
	STDERR.puts "#$0: missing Phones[#{foo}]. Replacing with 'a'."
	bar = Phones['a']
      end
    end
    zip = soft(bar)
    STDERR.puts "#$0: failed to soft(#{bar}). Crash imminent." if !zip
    prefixPrev = prefix.rstrip
    prefix += zip + " "
    STDERR.puts "\t\t\tFound #{foo} = #{zip}."
    if trie.has_children?(prefix.rstrip)
=begin
      # HACK to choose more words with just 2 to 4 phones (for Tigrinya):
      rrr = prefix.rstrip
      words = h[rrr]
      n = rrr.split(" ").size
      # rand-threshold, and % freq of 2,3,4 phone words, reported by wordlengths.rb:
      # 0.0: 2.6 4.1 8.2
      # 0.3: 6.0 10.3 14.5
      # 0.4: 6.5 11.1 15.4
      # 0.6: 7.2 12.2 16.5
      # 963: 9.8 14.7 16.5
      # 95,7,1: 10.3 16.0 16.6
      # 98,8,4: 9.3 14.9 17.1
      # 99,9,7: 8.4 14 17.6
      #
      # 18.4 23.3 26 is the target.
      if words && !words.empty? && 2 <= n && n <= 4 && rand < [1,1, 0.98,0.9,0.7][n]
	# Copied from "if trie.has_key? prefixPrev".
	i = iStart = i+1
	word = words[rand(words.size)]
	print word + " "
	next
      end
=end

      # Extend prefix.
      i += 1
      next
    else
      STDERR.puts "Reached #{prefix.rstrip}."
    end
    #STDERR.puts "prev-trying '#{prefixPrev}', trie? #{trie.has_key?(prefixPrev) ? 'waar.' : 'vals.'}"
    if trie.has_key? prefixPrev
      i = iStart = i+1
      words = h[prefixPrev]
      STDERR.puts "\t\t\t\t\t\tPick: #{words.join(' ')}."
      word = words[rand(words.size)] # Choose a homonym at random.
      # Todo: instead of uniformly random, follow how frequent those words actually are in some (which?) text.
      #print word + " "
      print "   " + word + "   "
    else

      #   elsif trie.has_key?(prefixPrev with its last element stripped), use h[THAT],
      #   elsif... until prefixPrev is empty.
      #   ;;;; Change this chain of if's into a loop.
      c = prefixPrev.split(' ').size
      if c > 1
	prefixAgain = prefixPrev.split(' ')[0..-2].join(' ')
	STDERR.puts "Re-reached #{prefixPrev}."
	if trie.has_key? prefixAgain
	  i = iStart = i+1 -2 # -2 == length of prefixAgain.  Backtrack the proper amount.
	  words = h[prefixAgain]
	  STDERR.puts "\t\t\t\t\tPick: #{words.join(' ')}. ***"
	  word = words[rand(words.size)]
	  print "   " + word + "   "
	  prefix = ""
	  next
	end
      end

      # Trie has no word starting with prefixPrev.  Skip this phone.
      # Resume searching, one phone past that skipped phone.
      STDERR.puts "Skipped #{phones[iStart]}."
      print "#{phones[iStart]}_ " # debug
      iStart = i = iStart+1
    end
    prefix = ""
  end
  puts
}
STDERR.puts "#{File.basename $0}: done."
