#!/usr/bin/env bash
# find new bars subjects, convert eyd to something parsable

cd $(dirname $0)

../barsEYD2dataAndCodes.pl all >  scannerbarsEYDToCSV.log

git diff scannerbarsEYDToCSV.log

# if is a difference, git diff returns false
if ! git diff --exit-code scannerbarsEYDToCSV.log ; then
 git add scannerbarsEYDToCSV.log
 git commit -m "auto update log"
fi

