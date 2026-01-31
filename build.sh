#!/bin/bash

# This script will "rebuild" html files based on the templates.
#
# Usage:
#   ./build.sh          # Full build (slow)
#   ./build.sh --quick  # Quick build with sample data for template testing

set -xe

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Parse arguments
USE_QUICK=false
if [[ "${1:-}" == "--quick" || "${1:-}" == "-q" ]]; then
    USE_QUICK=true
fi

# Auto-activate venv if it exists
if [[ -f "$SCRIPT_DIR/.venv/bin/activate" ]]; then
    source "$SCRIPT_DIR/.venv/bin/activate"
fi

export REPONAME="json"
export ORGANIZATION="boostorg"
GCOVRFILTER=".*/$REPONAME/.*"

cd "$SCRIPT_DIR/$REPONAME"
BOOST_CI_SRC_FOLDER=$(pwd)

outputlocation="$BOOST_CI_SRC_FOLDER/gcovr"
rm -rf $outputlocation || true
mkdir -p $outputlocation

# Determine which coverage file to use
COVERAGE_FILE="$BOOST_CI_SRC_FOLDER/coverage.json"
if [[ "$USE_QUICK" == true ]]; then
    SAMPLE_FILE="$BOOST_CI_SRC_FOLDER/coverage_sample.json"

    # Create sample file if it doesn't exist
    if [[ ! -f "$SAMPLE_FILE" && -f "$COVERAGE_FILE" ]]; then
        echo "Creating sample coverage file for template testing..."
        python3 -c "
import json
with open('$COVERAGE_FILE') as f:
    data = json.load(f)
files = data.get('files', [])
# Sort by line count and pick a mix: 20 small, 15 medium, 5 larger
by_size = sorted(files, key=lambda f: len(f.get('lines', [])))
small = [f for f in by_size if len(f.get('lines', [])) < 500][:20]
medium = [f for f in by_size if 500 <= len(f.get('lines', [])) < 2000][:15]
larger = [f for f in by_size if len(f.get('lines', [])) >= 2000][:5]
sample = small + medium + larger
data['files'] = sample
with open('$SAMPLE_FILE', 'w') as f:
    json.dump(data, f)
print(f'Created sample with {len(sample)} files ({len(small)} small, {len(medium)} medium, {len(larger)} larger)')
"
    fi

    if [[ -f "$SAMPLE_FILE" ]]; then
        COVERAGE_FILE="$SAMPLE_FILE"
        echo "Using sample coverage file for quick build"
    else
        echo "WARNING: Sample file not found, using full coverage"
    fi
fi

if [[ -f "$COVERAGE_FILE" ]]; then
    # Local/macOS: Use gcovr JSON tracefile (preserves function/branch data)
    # The JSON uses relative paths from the boost-root directory,
    # so we set --root to point to boost-root.

    "$SCRIPT_DIR/scripts/gcovr_wrapper.py" \
        --json-add-tracefile "$COVERAGE_FILE" \
        --root "$SCRIPT_DIR/boost-root" \
        --merge-lines \
        --html-nested \
        --html-template-dir "$SCRIPT_DIR/templates/html" \
        --output "$outputlocation/index.html"

    # Generate tree.json for sidebar navigation
    python3 "$SCRIPT_DIR/scripts/build_tree.py" "$outputlocation"

elif [[ -f "$BOOST_CI_SRC_FOLDER/coverage_filtered.info" ]]; then
    # Fallback: Use LCOV -> Cobertura conversion (loses function/branch data)
    echo "WARNING: Using LCOV fallback - function/branch data may be missing"
    echo "Run docker-build.sh to generate coverage.json with full data"

    ORIGINAL_PATH=$(grep -m1 "^SF:" "$BOOST_CI_SRC_FOLDER/coverage_filtered.info" | sed 's|^SF:||' | sed 's|/boost-root/.*||')
    TEMP_COVERAGE="/tmp/coverage_local.info"
    TEMP_XML="/tmp/coverage.xml"

    sed "s|$ORIGINAL_PATH|$SCRIPT_DIR|g" "$BOOST_CI_SRC_FOLDER/coverage_filtered.info" > "$TEMP_COVERAGE"
    lcov_cobertura "$TEMP_COVERAGE" -o "$TEMP_XML"
    sed -i.bak "s|filename=\"\.\./boost-root/|filename=\"$SCRIPT_DIR/boost-root/|g" "$TEMP_XML"

    "$SCRIPT_DIR/scripts/gcovr_wrapper.py" \
        --cobertura-add-tracefile "$TEMP_XML" \
        --root "$SCRIPT_DIR" \
        --merge-lines \
        --html-nested \
        --html-template-dir "$SCRIPT_DIR/templates/html" \
        --output "$outputlocation/index.html"

    # Generate tree.json for sidebar navigation
    python3 "$SCRIPT_DIR/scripts/build_tree.py" "$outputlocation"
else
    # CI/Linux: gcovr reads coverage data directly
    cd ../boost-root
    gcovr --merge-mode-functions separate -p \
        --merge-lines \
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
