#!/bin/bash
#
# Build and run the Docker container to generate production coverage data
#
# Usage:
#   ./docker-build.sh          # Build and generate coverage
#   ./docker-build.sh shell    # Start interactive shell for debugging
#
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Create output directory
mkdir -p output

if [[ "${1:-}" == "shell" ]]; then
    echo "Starting interactive shell..."
    docker build -t gcovr-dev .
    docker run -it --rm \
        -v "$(pwd)/output:/output" \
        --entrypoint /bin/bash \
        gcovr-dev
else
    echo "=== Building Docker image ==="
    docker build -t gcovr-dev .

    echo "=== Running coverage build ==="
    docker run --rm \
        -v "$(pwd)/output:/output" \
        gcovr-dev

    echo ""
    echo "=== Coverage files ready ==="
    ls -la output/*.info

    echo ""
    echo "To use these files:"
    echo "  1. Copy to json/: cp output/*.info json/"
    echo "  2. Run build.sh to generate HTML report"
    echo ""

    # Optionally auto-copy
    if [[ -d "json" ]]; then
        read -p "Copy .info files to json/ directory? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cp output/*.info json/
            echo "Files copied. Run ./build.sh to generate the HTML report."
        fi
    fi
fi
