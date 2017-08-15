#!/usr/bin/env ruby
# encoding: utf-8

# Read stage 15's $hypfile.
# Write the single text file $jonmay,
# and the dir of utterance-files jonmaydir for Jon's flat2elisa.py.

if ARGV.size != 1
  STDERR.puts "Usage: #$0 jonmay_dir < hyp.txt > jonmay_hyp.txt"
  exit 1
end
$jonmaydir = ARGV[0]

scrips = Hash.new {|h,k| h[k] = []} # Map each uttid to an array of transcriptions.

$stdin.each_line {|l|
  l = l.split
  s = l[1..-1].join(" ")			# иисусу хоста иаа
  next if s.empty?
  uttid = l[0][0..10]				# RUS_134_004
  starttime = l[0][12..-1].sub(/_.*/, '').to_i	# 101824705
  scrips[uttid] << [starttime, s]
}
scrips = scrips.to_a.sort_by {|uttid,ss| uttid}
scrips.map! {|uttid,ss| [uttid, ss.sort_by {|t,s| t}]}      # Within each uttid, sort the scrips by time.
scrips.map! {|uttid,ss| [uttid, ss.transpose[1].join(' ')]} # Within each uttid, concat its scrips.
scrips.each {|uttid,ss| puts "#{uttid} #{ss}"}

`rm -rf #$jonmaydir; mkdir #$jonmaydir`
scrips.each {|uttid,ss| File.open("#$jonmaydir/#{uttid}.txt", "w") {|f| f.puts ss}}

$tojon = "il5.eval-asr-uiuc.xml"
`/ws/ifp-53_1/hasegawa/data/lorelei/PTgen/test/mcasr-rus/flat2elisa/flat2elisa.py -i #$jonmaydir -l rus -o #$tojon`
`gzip --best #$tojon`

STDERR.puts "todo: sftp the file #$tojon.gz to Jon." # See aug/a.txt.
