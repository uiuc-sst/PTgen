#!/usr/bin/env ruby

# Reads transcriptions of clips as phones from mcasr.
# Simplifies the phone set, coalesces each clip's transcriptions,
# and rewrites those as phone index numbers.

# Usage: ./stage1.rb < xxx-clips.txt > stage1-$LANG_CODE.txt
#
# xxx-clips.txt comes from mcasr's outputs, with a command like:
#
# ifp-53:mcasr/s5c% /ws/ifp-53_1/hasegawa/tools/kaldi/kaldi/src/bin/ali-to-phones exp/Uzbek/mono/final.mdl ark:'gunzip -c exp/Uzbek/mono_ali/ali.*.gz|' ark,t:- | utils/int2sym.pl -f 2- data/Russian/lang/phones.txt - > uzb-clips.txt
#
# ifp-53:mcasr/s5c% /ws/ifp-53_1/hasegawa/tools/kaldi/kaldi/src/bin/ali-to-phones exp/Russian/tri4b/final.mdl ark:'gunzip -c exp/Russian/tri4b_ali/ali.*.gz|' ark,t:- | utils/int2sym.pl -f 2- data/Russian/lang/phones.txt - > /tmp/rus-clips.txt

# This script reformats xxx-clips.txt as one line per mp3 clip, with #-delimited transcriptions.
# Removes _B _E _I _S suffixes from phones, because word boundaries are meaningless for nonsense words.
#
# Does *not* trim off leading or trailing SIL silence and SPN speaker noise,
# because those help PTgen score and align transcriptions.
# Does *not* remove duplicate transcriptions of a clip, for the same reason,
# unless *all* transcriptions are identical.

if false
  # Report if a prondict has any consecutive duplicate phones.
  prondict = "prondicts/rus-prondict-july26.txt"
  prondict = "prondicts/Tigrinya/dictionary.txt"
  prondict = "prondicts/Tigrinya/prondict-from-amharic-phones.txt"
  prondict = "prondicts/Oromo/dictionary.txt"
  File.readlines(prondict) .map {|l| l.split(/\s+/)[1..-1]} .each {|l|
    f = false
    (l.size-1).times {|i| f |= l[i]==l[i+1]}
    p l.join(' ') if f
  }
  exit 0
end

clips = Hash.new {|h,k| h[k] = []} # Map each clip-name to an array of transcriptions.

ARGF.readlines .map {|l| l.split} .each {|l|
  name = l[0]
  # Possibilities:
  # IL5_EVAL_001_001_000000000_001238265_003 (MCASR)
  # IL5_EVAL_001_001-0-1238265 (Tigrinya alignments from Babel phone set)
  # IL5_EVAL_001_001-11144400-12382665-10 (Tigrinya ali, 10-best)
  # TGL_EVAL_082_014 (brno-phnrec from asr24)
  isShort = name.size <= 17
  hasSuffix = name =~ /_[0-9][0-9][0-9]$/
  hasSuffix10 = name =~ /\-[0-9]$/ || name =~ /\-[0-9][0-9]$/ 
  if isShort
    # name == TGL_EVAL_082_014; don't change it.
  elsif hasSuffix
    # name == IL5_EVAL_111_007_023498070_024734810_003
    name = name[0..-5]
    # name == IL5_EVAL_111_007_023498070_024734810
  elsif hasSuffix10
    # name == IL5_EVAL_001_001-11144400-12382665-6
    name = name.split('-')[0..2]
    name = name[0] + '_' + ('%09d' % name[1]) + '_' + ('%09d' % name[2])
    # name == IL5_EVAL_001_001-11144400-12382665
  else
    # name == IL5_EVAL_111_007-23498070-24734810
    name = name.split('-')
    name = name[0] + '_' + ('%09d' % name[1]) + '_' + ('%09d' % name[2])
    # name == IL5_EVAL_111_007_023498070_024734810
  end
  scrip = l[1..-1].map {|p| p.sub /_[BEIS]/, ''} \
    .chunk {|x| x}.map(&:first) # Remove consecutive duplicate phones.
  clips[name] << scrip

  if false
    # Report consecutive duplicate phones.
    f = false
    (scrip.size-1).times {|i| f |= scrip[i]==scrip[i+1]}
    puts "#{name} #{scrip}" if f
  end
}

class Array
  def pretty() u = self.uniq; u.size == 1 ? u : self.sort; end
end

# If a clip's scrips are identical, keep only one.
clips = clips.to_a.sort_by {|c| c[0]} .map {|name,ss| [name,ss.pretty]}

# Convert each phone to its index in phones.txt.
# As a string, not an int, for easier join()ing.
$phones = Hash[*File.read("phones.txt").split(/\s+/)]
$phones["NSN"] = $phones["SPN"] # Synonym for SPN, from Babel phone set.

def iFromPhone(ph)
  i = $phones[ph]
  if !i
    STDERR.puts "#$0: phone '#{ph}' not in phones.txt."
    return $phones["SPN"] # Map unrecognized phones to noise.
  end
  i
end

clips.map! {|name,ss| [name, ss.map {|ss| ss.map {|s| iFromPhone(s)} .join(" ")}]}

clips.each {|name,ss| puts "#{name}:#{ss.join ' # '}" if !ss.join(' # ').empty? }
# Omit empty transcriptions, so compute_turker_similarity doesn't see a transcriptionless utterance and abort.
# todo: if empty, better to put a "SIL"ence transcription.
