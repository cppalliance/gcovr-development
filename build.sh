#!/bin/bash

# This script generates gcovr HTML reports from coverage data.
#
# Usage:
#   ./build.sh          # Full build
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

# Output goes to top-level gcovr-output/
OUTPUT_DIR="$SCRIPT_DIR/gcovr-output"
rm -rf "$OUTPUT_DIR" || true
mkdir -p "$OUTPUT_DIR"

# Coverage data location
COVERAGE_FILE="$SCRIPT_DIR/coverage.json"

if [[ "$USE_QUICK" == true ]]; then
    SAMPLE_FILE="$SCRIPT_DIR/coverage_sample.json"

    # Create sample file if it doesn't exist
    if [[ ! -f "$SAMPLE_FILE" && -f "$COVERAGE_FILE" ]]; then
        echo "Creating sample coverage file for template testing..."
        python3 -c "
import json
with open('$COVERAGE_FILE') as f:
    data = json.load(f)
files = data.get('files', [])
# Pick 50 small files (<500 lines) for fast template iteration
small = [f for f in files if len(f.get('lines', [])) < 500][:50]
data['files'] = small
with open('$SAMPLE_FILE', 'w') as f:
    json.dump(data, f)
print(f'Created sample with {len(small)} small files')
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
    # Use gcovr JSON tracefile (preserves function/branch data)
    "$SCRIPT_DIR/scripts/gcovr_wrapper.py" \
        --json-add-tracefile "$COVERAGE_FILE" \
        --root "$SCRIPT_DIR/boost-root" \
        --merge-lines \
        --html-nested \
        --html-template-dir "$SCRIPT_DIR/templates/html" \
        --output "$OUTPUT_DIR/index.html"

    # Generate tree.json for sidebar navigation
    python3 "$SCRIPT_DIR/scripts/build_tree.py" "$OUTPUT_DIR"

else
    echo "ERROR: No coverage.json found at $COVERAGE_FILE"
    echo ""
    echo "To generate coverage data:"
    echo "  1. Run ./setup-boost.sh to clone Boost"
    echo "  2. Run ./docker-build.sh to build with coverage"
    echo "  3. Copy output/coverage.json to this directory"
    exit 1
fi

echo ""
echo "Output generated at: $OUTPUT_DIR/index.html"
