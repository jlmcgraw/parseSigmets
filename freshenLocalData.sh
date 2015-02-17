#!/bin/bash
set -eu                # Always put this in Bourne shell scripts
IFS="`printf '\n\t'`"  # Always put this in Bourne shell scripts

if [ "$#" -ne 1 ] ; then
  echo "Usage: $0 ROOT_DIR" >&2
  exit 1
fi

#Get command line parameters
ROOT_DIR="$1"

if [ ! -d $ROOT_DIR ]; then
    echo "$ROOT_DIR doesn't exist"
    exit 1
fi

cd $ROOT_DIR

#Get all of the latest charts
set +e
wget -r -l1 -H -N -np -A.txt -erobots=off http://aviationweather.gov/data/iffdp/
set -e

