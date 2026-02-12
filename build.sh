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

    # Pass 1: Collect raw coverage as JSON
    "$SCRIPT_DIR/scripts/gcovr_wrapper.py" \
        --cobertura-add-tracefile "$TEMP_XML" \
        --root "$SCRIPT_DIR" \
        --merge-lines \
        --json "$outputlocation/coverage-raw.json"

    # Fix paths in JSON
    python3 "$SCRIPT_DIR/scripts/fix_paths.py" \
        "$outputlocation/coverage-raw.json" \
        "$outputlocation/coverage-fixed.json" \
        --repo "$REPONAME"

    # Pass 2: Generate HTML from fixed JSON
    "$SCRIPT_DIR/scripts/gcovr_wrapper.py" \
        -a "$outputlocation/coverage-fixed.json" \
        --html-nested \
        --html-template-dir "$SCRIPT_DIR/templates/html" \
        --html-title "$REPONAME" \
        --output "$outputlocation/index.html" \
        --json-summary-pretty \
        --json-summary "$outputlocation/summary.json"

    # Generate tree.json for sidebar navigation
    python3 "$SCRIPT_DIR/scripts/build_tree.py" "$outputlocation"

    # Generate coverage badges
    python3 "$SCRIPT_DIR/scripts/generate_badges.py" "$outputlocation" --json "$outputlocation/summary.json"
else
    # CI/Linux: gcovr reads coverage data directly
    cd ../boost-root

    # Pass 1: Collect raw coverage as JSON
    gcovr --merge-mode-functions separate -p \
        --merge-lines \
        --exclude-unreachable-branches \
        --exclude-throw-branches \
        --exclude '.*/test/.*' \
        --exclude '.*/extra/.*' \
        --filter "$GCOVRFILTER" \
        --json "$outputlocation/coverage-raw.json"

    # Fix paths in JSON
    python3 "../scripts/fix_paths.py" \
        "$outputlocation/coverage-raw.json" \
        "$outputlocation/coverage-fixed.json" \
        --repo "$REPONAME"

    # Create symlinks so gcovr can find source files at repo-relative paths
    ln -sfn "$BOOST_CI_SRC_FOLDER/include" "$(pwd)/include" 2>/dev/null || true
    ln -sfn "$BOOST_CI_SRC_FOLDER/src" "$(pwd)/src" 2>/dev/null || true

    # Pass 2: Generate HTML from fixed JSON
    gcovr -a "$outputlocation/coverage-fixed.json" \
        --html-nested \
        --html-template-dir=../templates/html \
        --html-title "$REPONAME" \
        --html \
        --output "$outputlocation/index.html" \
        --json-summary-pretty \
        --json-summary "$outputlocation/summary.json"

    # Generate tree.json for sidebar navigation
    python3 "../scripts/build_tree.py" "$outputlocation"

    # Generate coverage badges
    python3 "../scripts/generate_badges.py" "$outputlocation" --json "$outputlocation/summary.json"
fi
