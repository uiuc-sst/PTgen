#!/usr/bin/env ruby

# Reads monophonic /tmp/a.wav.
# Creates /tmp/turkAudio.tar, which contains .mp3 and .ogg clips.

# Remove silent intervals.  http://digitalcardboard.com/blog/2009/08/25/the-sox-of-silence/
#
# To discover *which* intervals were removed, which you'd need to recreate the timing relationship
# between the short clips *.mp3 and the source files which were concatenated into /tmp/a.wav,
# you need a doctored version of sox that reports those intervals.  Ask Camille for this.
`sox /tmp/a.wav /tmp/b.wav silence 1 0.05 2% -1 1.0 2%`

# Duration in seconds.
$dur = `sfinfo /tmp/b.wav | grep Duration`.split[1].to_f

$slice = 1.25 # seconds

puts "Splitting #$dur seconds into slices each #$slice s long."

# For clips this short, prefer sox to ffmpeg, because ffmpeg has a bug,
# sometimes making clips too long:  -t 1.25 may act like -t 1.30.
# (When converting .wav to .mp3, even sox may append 30 ms of silence,
# but turkers can't notice that.)

Dir.mkdir '/tmp/a'
Dir.chdir '/tmp/a'
i=0
(0.0 .. $dur).step($slice) {|x| `sox /tmp/b.wav #{"%05d" % i}.wav trim #{x} #$slice`; i+=1}

puts "Converting #{i} slices to .mp3 and .ogg."
$ffmpeg = 'ffmpeg -nostats -loglevel 0' # As quiet as 2&>1 > /dev/null.  -hide_banner isn't recognized.
# Encode each slice as .mp3 and as .ogg.
# For e.g. 128 kbps, instead do:   -b:a 128k
`for f in *.wav; do #$ffmpeg -y -i "$f" -b:a 160k "${f%.wav}.mp3"; done`
`for f in *.wav; do #$ffmpeg -y -i "$f" -b:a 160k "${f%.wav}.ogg"; done`
# Instead of ffmpeg, one could: `... sox "$f" -C 160.2 "${f%.wav}.mp3" ...`

# Tarball the slices.
`tar cf /tmp/turkAudio.tar *.mp3 *.ogg`
puts "Please copy /tmp/turkAudio.tar to ifp-serv-03 and extract it into /workspace/speech_web/mc/myTest."
