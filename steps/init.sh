#!/bin/bash

# Parse settings_file ($1) into a bunch of $variables.
# Define some utility functions.

# Exit if there is any error.
set -e

scriptname=`basename "$0"`

nparallel=`nproc | sed "s/$/-1/" | bc`	# One fewer than the number of CPU cores.

if [[ $# -ne 1 ]]; then
	echo "Usage: $scriptname settings_file."; exit 1
fi
[ ! -f $1 ] && echo "$scriptname: no settings file \"$1\". Aborting." && exit 1
. $1

# Make a temporary directory for the caller.
# (Change /tmp to something else, for servers with harsh quotas on /tmp.)
mktmpdir() {
	export tmpdir=/tmp/$scriptname-$$.dir
	mkdir -p $tmpdir
	>&2 echo "Using tmpdir $tmpdir."
}

# Verify that a previously created file exists, and report that.
usingfile() {
	if [[ ! -e $1 ]]; then
		>&2 echo "$scriptname: no file \"$1\" for $2. Aborting."
		exit 1
	fi
	>&2 echo "Using $2 $1."
}

# Print a row of dots.
# showprogress init x "Creating widgets":	print first line, and set frequency of dots.
# showprogress go:				possibly print another dot.
# showprogress end:				print "Done."
#
# Unfortunately, any error message will start mid-line (after the most recent dot),
# instead of at the start of a line where it would be more noticeable.
showprogress() {
	local arg="$1"
	case $arg in
		init)
			__progress_counter__=1
			__progress_stepsize__=$2
			>&2 echo -n "$3..."
			;;
		go)
			if [[ $((__progress_counter__ % __progress_stepsize__)) -eq 0 ]] ; then
				>&2 echo -n "."
			fi
			((__progress_counter__++))
			;;
		end)
			>&2 echo " Done."
			;;
	esac
}
