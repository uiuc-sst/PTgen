#!/usr/bin/env ruby

# Reads phones-b-e-i-s.txt.
# Collapses any [x_B, x_E, x_I, x_S] into just x.

beis = File.readlines("phones-b-e-i-s.txt") .map {|l| l.split}

prefixes = beis.map {|l| l[0].sub /_[BEIS]/, ''} .sort.uniq
prefixes.each {|x| puts x}
=begin
This prints the following candidates for phones.
But 0..9 and #0..#80 and NSN never appear in actual transcriptions.
So just handcode the remainder as a reduced phones.txt.
It's almost a subset of PTgen/test/2016-08-24/data/phonesets/univ.compact.txt,
but it has a few extras.

#0
#1
...
#79
#80
0
1
2
3
4
5
6
7
8
9
<eps>
NSN
SIL
SPN
X
a
aʊ
aː
b
c
d
dʒ
e
ei
f
g
h
i
iː
j
k
l
m
n
o
oʊ
p
r
s
t
tʃ
u
uː
v
w
x
y
z
æ
ð
ø
ŋ
ɐ
ɑ
ɑɪ
ɔ
ɔi
ɕ
ɖ
ə
ɚ
ɛ
ɝ
ɟ
ɡ
ɣ
ɨ
ɪ
ɯ
ɱ
ɲ
ɵ
ɹ
ɾ
ʂ
ʃ
ʉ
ʊ
ʌ
ʒ
ʔ
θ
=end
