#!/bin/bash
set -eu                # Always put this in Bourne shell scripts
IFS=$(printf '\n\t')  # Always put this in Bourne shell scripts

sudo apt-get install libregexp-grammars-perl

#Do an initial download of sigmet data from aviationweather.gov
./freshenlocaldata.sh .

