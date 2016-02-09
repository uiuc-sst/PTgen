#!/bin/bash

set -e # exit if there is any error

scriptname=`basename "$0"`

if [[ $# -ne 1 ]]; then
	echo "Usage: $scriptname settings_file.";
	exit 1
fi
[ ! -f $1 ] && echo "$scriptname ERROR: no settings file \"$1\"." && exit 1;
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
	if [[ ! -e $1 ]]; then
		>&2 echo "$scriptname ERROR: no file \"$1\"."
		exit 1
	fi
	>&2 echo "USING: $2 \"$1\""
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
