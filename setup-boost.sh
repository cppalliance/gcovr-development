#!/bin/bash
#
# Clone the Boost superproject with submodules.
# This creates boost-root/ which is git-ignored.
#
# Usage:
#   ./setup-boost.sh              # Clone all of Boost
#   ./setup-boost.sh json         # Clone only libs needed for json

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

BOOST_ROOT="$SCRIPT_DIR/boost-root"

if [[ -d "$BOOST_ROOT" ]]; then
    echo "boost-root already exists. To re-clone, remove it first:"
    echo "  rm -rf boost-root"
    exit 0
fi

echo "=== Cloning Boost superproject ==="
git clone --depth 1 https://github.com/boostorg/boost.git boost-root

cd boost-root

echo "=== Initializing submodules ==="
if [[ -n "${1:-}" ]]; then
    # Clone specific library and its dependencies
    LIB="$1"
    echo "Cloning libs/$LIB and dependencies..."
    git submodule update --init --depth 1 libs/$LIB
    git submodule update --init --depth 1 tools/boostdep
    python3 tools/boostdep/depinst/depinst.py --include example $LIB

    # Create boost/ symlink so coverage data paths work
    # (coverage references boost/json/ but source is at libs/json/include/boost/)
    if [[ -d "libs/$LIB/include/boost" && ! -e "boost" ]]; then
        echo "Creating boost/ symlink for coverage paths..."
        ln -s "libs/$LIB/include/boost" boost
    fi
else
    # Clone all submodules (slower but complete)
    echo "Cloning all submodules (this may take a while)..."
    git submodule update --init --recursive --depth 1
fi

echo ""
echo "=== Boost setup complete ==="
echo "boost-root is ready at: $BOOST_ROOT"
