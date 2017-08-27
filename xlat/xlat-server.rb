#!/usr/bin/env ruby
# encoding: utf-8

# Translate Oromo or Tigrinya to English translator, using unigram words from Angli.
# Reads other language L2, and writes English, on TCP port 4444, multithreaded.

if ARGV.size != 1
  STDERR.puts "Usage: #$0 orm|tir;  then, socat - TCP:localhost:4444 < orm.txt > eng.txt"
  exit 1
end
L2 = ARGV[0]
case L2
when 'tir'
  Pickle = "/run/shm/tir2eng"
  Wordlist = "il5.lex.e2f"
when 'orm'
  Pickle = "/run/shm/orm2eng"
  Wordlist = "il6.lex.e2f"
else
  STDERR.puts "#$0: expected orm or tir, not '#{L2}'."
  exit 1
end

if !File.exists? Pickle
  STDERR.puts "Making pickle."
  $dict = {}
  class String
    def tidy() downcase .sub(/^--/, '') .sub(/--$/, '') .gsub('--', '-') end
  end
  begin
    t = File.readlines(Wordlist) .map {|l| a = l.split; [a[0].tidy, a[1].tidy, a[2].to_f] }
    # t has triplets [wordL2, wordEng, probability].
    # Cull bogus lines.
    t.select! {|a| !(a[0]=="null" || a[1] == "null")}
    t.select! {|a| a[0] != a[1]} # Idempotent.
    t.select! {|a| a[0] =~ /\p{Ethiopic}/ }  if L2 == 'tir' # At least one other-script letter.
    t.select! {|a| a[0].count("a-z") > 0 } if L2 == 'orm' # At least one eng letter.  Not just punctuation or digits.
    t.select! {|a| a[1].count("a-z") > 0 } # At least one eng letter.  Not just punctuation or digits.
    t.select! {|a| !(a[0][0] == '&' && a[0][-1] == ';')} # "&quot;"
    t.select! {|a| !(a[1][0] == '&' && a[1][-1] == ';')} # "&quot;"
    t.select! {|a| a[2] > 0.0} # Fortunately has no effect, but prevents later DBZ.
    t.select! {|a| p=a[0].size; q=a[1].size; !(p<=2 && q>=8 || q<=2 && p>=8 || p==1 && q>=4 || q==1 && p>=4)} # Lengths mismatch.
    if t.empty?
      STDERR.puts "#$0: nothing left in dictionary."
      exit 1
    end
    # Traverse t, collecting keys, building a hash table.
    h = Hash.new {|k,v| k[v] = []}
    t.each {|l2,eng,p|
      h[l2] << [eng, p]
      # This simplification hardly matters.
      # It slightly shortens arrays, but doesn't affect this program's output.
      if false
	# Avoid putting duplicate eng's in the array.
	old = h[l2]
	if old == []
	  puts "adding #{eng}."
	  h[l2] << [eng, p]
	else
	  puts "old is #{old}."
	  # Add probability p to the prob of the element of the array h[l2] whose first member is old[0].
	  # To do so, rebuild the entire array.  Ick.
	  h[l2] = [old[0], old[1]+p]
	end
      end
    }
    # In h, a key is a l2; a value is an array of [eng,p].
    # Build a new hash where each value's p's sum to 1.
    h.each {|l2,arr|
      # Normalize the p's to sum to 1, for a PDF.
      # BTW, nonpositive p's were already culled, so this can't divide by zero.
      sum = 0.0; arr.each {|eng,p| sum += p }
      arr.map! {|eng,p| [eng, p/sum] }
      # Accumulate the p's, to convert the PDF to a CDF.
      acc = 0.0; arr.map! {|eng,p| [eng, acc+=p] }
      arr[-1][1] = 1.0 # Avoid roundoff error.
      $dict[l2] = arr
    }
  end
  File.open(Pickle, "w") {|f| Marshal.dump $dict, f }
end

# Fast startup.
STDERR.puts "Server reading pickle."
$dict = File.open(Pickle, "r") {|f| Marshal.load f }
STDERR.puts "Server ready to translate #{L2} to English."
STDERR.puts "Dict has size #{$dict.size}."
$dict.freeze

def lookup arr
  return nil if !arr
  r = rand
  arr[arr.index{|eng,p| p>=r}][0]
end

def other2eng line
  ret = ""
  line.force_encoding("UTF-8").split.each {|w|
    x = lookup $dict[w]
    next if !x && w !~ /[0-9]/ # Hide not-found L2 words, to spot English easier.  Don't hide IL6_EVAL_001_001.
    ret += x ? "#{x} " : "#{w} "
  }
  ret + "\n"
end

# Multithreaded TCP server.
require 'socket'
server = TCPServer.new 'localhost', 4444

# This is slower than Thread.fork, but at least it doesn't produce dozens of empty files 999_999_xlat.txt.
while session=server.accept
# STDERR.puts "awaiting client"
  # True multicore.
  # But it leaves one defunct Ruby process per completed client, i.e. 881 per run.
  # So I shouldn't just leave the server running?  Is that bad?
  fork do
    fClientClosed = false
    c = 0
    fEmptyReply = true
    until session.closed?
#     STDERR.puts ".. " # "awaiting command"
      cmd = session.gets
      if !cmd || cmd.empty? || session.closed?
#	STDERR.puts "Done." # "client closed session"
	fClientClosed = true
	session.close
      else
	# Just keep reading until client calls session.close().
	# No need for a sentinel like "" or "__END_TRANSLATION__".
#	STDERR.puts "cli sent #{cmd.size} bytes."
	reply = other2eng(cmd)
#	STDERR.puts "replying #{reply.size} bytes."
	begin
	  session.puts reply
	  fEmptyReply = false if !reply.empty?
	  c += 1
	rescue
#	  STDERR.puts "Done." # cli probably ctrl-C'd session
	  fClientClosed = true
	  session.close
	end
      end
    end
    if !fClientClosed
      STDERR.puts "server closing session"
      session.close
    end
    STDERR.puts "server fEmptyReply, #{c} replies." if fEmptyReply
  end
end
STDERR.puts "server exiting." # This never happens.
exit 0

=begin
# Thread.fork rather than System.fork.  Uses only one CPU,
# but twice as fast when System.fork must copy 260 MB of $dict's,
# and it doesn't leave thousands of zombie processes.
loop {
  Thread.fork(server.accept) {|session|
    fClientClosed = false
    until session.closed?
#     STDERR.puts ".. " # "awaiting command"
      cmd = session.gets
      #STDERR.puts "got line"
      if !cmd || cmd.empty? || session.closed?
#	STDERR.puts "Done." # "client closed session"
	fClientClosed = true
	session.close
      else
	# Just keep reading until client calls session.close().
	# No need for a sentinel like "" or "__END_TRANSLATION__".
#	STDERR.puts "cli sent #{cmd.size} bytes."
	reply = other2eng(cmd)
#	STDERR.puts "replying #{reply.size} bytes."
	session.puts reply
      end
    end
    if !fClientClosed
#     STDERR.puts "server closing session"
      session.close
    end
  }
}
STDERR.puts "server exiting." # This never happens.
exit 0
=end
