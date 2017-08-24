#!/usr/bin/env ruby
# encoding: utf-8

# Build a Bash-4 associative array from a text file, efficiently.
# Sourcing the output takes a few MB per second.
# Input lines are: key, comma or colon, rest of line.
# The array's keys are those keys lowercased; its values are the full lines.
# So after sourcing the output with . out.sh,
# do lookups with ${name_of_assoc_array[key]}.
# That's much faster than repeatedly doing grep -i key in.txt.
#
# Called by steps/mergetxt.sh.

if ARGV.size != 1
  STDERR.puts "Bash 4 usage: #$0 name_of_assoc_array < in.txt > out.sh; . out.sh"
  exit 1
end
$name = ARGV[0]

puts "declare -A #$name=( \\"
$stdin.each_line {|l|
  l.chomp!
  key = l.sub(/[,\:].*/, "").downcase # uzb_001_001_000000_001107
  puts "[\"#{key}\"]=\"#{l}\" \\"
}
puts ")"

__END__
This Bash 4 code would work too, but building the array dynamically,
instead of all at once, is almost as slow as repeated greps.

    declare -A scrips
    while IFS='' read -r line || [[ -n "$line" ]]; do
      key=`sed "s/\:.*//" <<<"$line"`
      key="${key,,}"                  # downcase
      scrips[$key]=$line
    done < in.txt
