#!/usr/bin/env ruby
# encoding: utf-8

# Read stage 15's $hypfile.
# Write the single text file $jonmay,
# the dir of utterance-files jonmaydir,
# and an XML file to sftp to Jon May.

if ARGV.size != 5
  STDERR.puts "Usage: #$0 jonmay_dir three_letter_language_code date_USC EXPLOCAL versionNumber < hyp.txt > jonmay_hyp.txt"
  # date_USC is, e.g., for 2017 aug 17, "20170817".
  exit 1
end
$jonmaydir, $sourceLanguage, $date, $EXPLOCAL, $version = ARGV
$genre = "SP" # SPeech
$provenance = "000000" # Media outlet.  Unknown.
$langForJon = $sourceLanguage.downcase

`rm -rf #$jonmaydir; mkdir #$jonmaydir`
$stdin.set_encoding(Encoding::UTF_8).each_line {|l|
  uttid,scrip = l.split "\t"
  if !uttid
    STDERR.puts "#$0: expected uttid, tab, transcription in input line '#{l}'."
    next
  end
  begin
    indexID = uttid[8..-1].gsub /[_a-zA-Z]/, ""
  rescue
    STDERR.puts "#$0: expected uttid, tab, transcription in input line '#{l}'."
    next
  end
  name = "#{$sourceLanguage}_#{$genre}_#{$provenance}_#{$date}_#{indexID}"
  File.open("#$jonmaydir/#{name}.txt", "w") {|f| f.puts scrip}
}

$tojon = "#$EXPLOCAL/elisa.#{$langForJon}-eng.eval-asr-uiuc.y3r1.v#$version.xml"

# When run as usual from PTgen/test/apply-LANG/ as ../../apply.sh settings,
# force this to call PTgen's flat2elisa.py instead of ASR24's.
`../../steps/flat2elisa.py -i #$jonmaydir -l #$langForJon -o #$tojon`
`rm -rf #$tojon.gz #$jonmaydir; gzip --best #$tojon`
STDERR.puts "Please sftp to Jon the file #$tojon.gz."
