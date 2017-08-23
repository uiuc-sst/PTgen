#!/usr/bin/env ruby
# encoding: utf-8

# Read stage 15's $hypfile.
# Write the single text file $jonmay,
# and the dir of utterance-files jonmaydir to send to Jon's flat2elisa.py.

if ARGV.size != 4
  STDERR.puts "Usage: #$0 jonmay_dir three_letter_language_code date_USC EXPLOCAL < hyp.txt > jonmay_hyp.txt"
  exit 1
end
$jonmaydir = ARGV[0]
$EXPLOCAL = ARGV[3]

$sourceLanguage = ARGV[1]
$genre = "SP" # "SP"eech
$provenance = "000000" # Media outlet.  Unknown.
$date = ARGV[2] # "20170817"
$langForJon = $sourceLanguage.downcase

`rm -rf #$jonmaydir; mkdir #$jonmaydir`
$stdin.each_line {|l|
  uttid,scrip = l.split "\t"
  indexID = uttid[8..-1].gsub /[_a-zA-Z]/, ""
  name = "#{$sourceLanguage}_#{$genre}_#{$provenance}_#{$date}_#{indexID}"
  File.open("#$jonmaydir/#{name}.txt", "w") {|f| f.puts scrip}
}

$version = "2" # Increment this for each sftp.
$tojon = "#$EXPLOCAL/elisa.#{$langForJon}-eng.eval-asr-uiuc.y2r1.v#$version.xml"

`/ws/ifp-53_1/hasegawa/data/lorelei/PTgen/test/mcasr-rus/flat2elisa/flat2elisa.py -i #$jonmaydir -l #$langForJon -o #$tojon`
`rm -rf #$tojon.gz; gzip --best #$tojon` # Also rm #$jonmaydir
STDERR.puts "Please sftp to Jon the file #$tojon.gz." # See aug/a.txt.
