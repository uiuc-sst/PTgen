#!/usr/bin/env ruby

# Create a .csv file listing audio clips in randomly shuffled order.
#
# Change "myTest" below to your actual directory.
# Send the output of this script to foo.csv, and then to Mechanical Turk's "Publish Batch".

N = ARGV[0].to_i # e.g., 2701 for 00000.mp3 .. 02700.mp3
URL = "http://isle.illinois.edu/mc/myTest/"

puts "audio1,oggaudio1,audio2,oggaudio2,audio3,oggaudio3,audio4,oggaudio4,audio5,oggaudio5,audio6,oggaudio6,audio7,oggaudio7,audio8,oggaudio8"

ClipNumbers = N.times .map {|i| "%05d" % i} .shuffle

# Partition into 8-tuples, excluding any remainder.
ClipNumbers[0 ... (N/8) * 8] .each_slice(8) {|octuple|
  octuple.each_with_index {|i,j|
    comma = j<7 ? "," : ""
    print "#{URL}#{i}.mp3,#{URL}#{i}.ogg#{comma}"
  }
  puts ""
}

# Don't duplicate ClipNumbers in this script.
# Instead, in mturk: Edit Project, Setting up your HIT,
# Number of assignments per HIT, type in a number between 5 and 10.
#
# Mturk may even ensure that each HIT goes to n *different* turkers.
# Bigger numbers reduce noise, but obviously cost proportionally more.
