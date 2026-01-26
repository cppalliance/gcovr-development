#!/bin/bash

# This script will "rebuild" html files based on the templates.

set -xe

export REPONAME="json"
export ORGANIZATION="boostorg"
GCOVRFILTER=".*/$REPONAME/.*"

cd "$REPONAME"
BOOST_CI_SRC_FOLDER=$(pwd)

cd ../boost-root

outputlocation="$BOOST_CI_SRC_FOLDER/gcovr"
outputlocation="/mnt/c/output"
rm -rf $outputlocation || true

mkdir -p $outputlocation

gcovr --merge-mode-functions separate -p --html-nested --html-template-dir=..\templates --exclude-unreachable-branches --exclude-throw-branches --exclude '.*/test/.*' --exclude '.*/extra/.*' --filter "$GCOVRFILTER" --html --output "$outputlocation/index.html"
