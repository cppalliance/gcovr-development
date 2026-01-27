#!/bin/bash

# This script will "rebuild" html files based on the templates.

set -xe

export REPONAME="json"
export ORGANIZATION="boostorg"
GCOVRFILTER=".*/$REPONAME/.*"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/$REPONAME"
BOOST_CI_SRC_FOLDER=$(pwd)

outputlocation="$BOOST_CI_SRC_FOLDER/gcovr"
rm -rf $outputlocation || true
mkdir -p $outputlocation

if [[ -f "$BOOST_CI_SRC_FOLDER/coverage_filtered.info" ]]; then
    # Local/macOS workaround: gcovr cannot read .gcda coverage files directly on macOS,
    # so we convert the .info file (from lcov) to Cobertura XML format instead.
    # The .info file contains absolute paths from the original build environment,
    # which we auto-detect and rewrite to match the local machine's paths.
    # Use 'boost-root' as anchor since it's consistently named across all builds
    ORIGINAL_PATH=$(grep -m1 "^SF:" "$BOOST_CI_SRC_FOLDER/coverage_filtered.info" | sed 's|^SF:||' | sed 's|/boost-root/.*||')
    TEMP_COVERAGE="/tmp/coverage_local.info"
    TEMP_XML="/tmp/coverage.xml"

    sed "s|$ORIGINAL_PATH|$SCRIPT_DIR|g" "$BOOST_CI_SRC_FOLDER/coverage_filtered.info" > "$TEMP_COVERAGE"
    lcov_cobertura "$TEMP_COVERAGE" -o "$TEMP_XML"
    sed -i.bak "s|filename=\"\.\./boost-root/|filename=\"$SCRIPT_DIR/boost-root/|g" "$TEMP_XML"

    "$SCRIPT_DIR/scripts/gcovr_wrapper.py" \
        --cobertura-add-tracefile "$TEMP_XML" \
        --root "$SCRIPT_DIR" \
        --html-nested \
        --html-template-dir "$SCRIPT_DIR/templates/html" \
        --output "$outputlocation/index.html"

    # Generate tree.json for sidebar navigation
    python3 "$SCRIPT_DIR/scripts/build_tree.py" "$outputlocation"
else
    # CI/Linux: gcovr reads coverage data directly
    cd ../boost-root
    gcovr --merge-mode-functions separate -p \
        --html-nested \
        --html-template-dir=../templates/html \
        --exclude-unreachable-branches \
        --exclude-throw-branches \
        --exclude '.*/test/.*' \
        --exclude '.*/extra/.*' \
        --filter "$GCOVRFILTER" \
        --html \
        --output "$outputlocation/index.html"

    # Generate tree.json for sidebar navigation
    python3 "../scripts/build_tree.py" "$outputlocation"
fi
