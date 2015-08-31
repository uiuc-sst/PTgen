#!/bin/bash

set -e # exit if there is any error
scriptname=`basename "$0"`

if [[ $# -ne 1 ]]; then
	echo "Usage: $scriptname <settings file>";
	exit 1
fi
[ ! -f $1 ] && echo "settings file \"$1\" is missing" && exit 1;
. $1

mktmpdir() {
	if [[ -n $tmpdir ]]; then
		tmproot=$tmpdir
	else
		tmproot="/tmp"
	fi
	export tmpdir=$tmproot/$scriptname-$$.dir
	mkdir -p $tmpdir
	>&2 echo "Created tmpdir $tmpdir"
}

usingfile () {
	filename=$1
	if [[ ! -e $filename ]]; then
		>&2 echo "ERROR: \"$filename\" not found"
		exit 1
	else
		>&2 echo "USING: $2 \"$filename\""
	fi
}

showprogress () {
	local arg="$1"
	case $arg in
		init)
			__progress_counter__=1
			__progress_stepsize__=$2
			>&2 echo -n "$3"
			;;
		go)
			if [[ $((__progress_counter__ % __progress_stepsize__)) -eq 0 ]] ; then
				>&2 echo -n "."
			fi
			((__progress_counter__++))
			;;
		end)
			>&2 echo "$2"
			;;
	esac
}

