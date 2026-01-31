#!/bin/bash
#
# Docker entrypoint for gcovr-development
# Builds Boost.JSON with coverage and generates .info files
#
set -eux

cd /workspace

# Clone Boost if not already present
if [[ ! -d "boost-root" ]]; then
    echo "=== Cloning Boost ==="
    git clone --depth 1 https://github.com/boostorg/boost.git boost-root
    cd boost-root
    git submodule update --init --depth 1 \
        tools/boostdep \
        tools/build \
        tools/boost_install \
        libs/json \
        libs/headers

    # Get JSON dependencies
    python3 tools/boostdep/depinst/depinst.py -g "--depth 1" json

    # Bootstrap b2
    ./bootstrap.sh
    ./b2 headers
    cd ..
fi

export BOOST_ROOT=/workspace/boost-root
export BOOST_CI_SRC_FOLDER=/workspace/boost-root/libs/json

cd "$BOOST_ROOT"

echo "=== Building Boost.JSON with coverage ==="

# Coverage flags (from codecov.sh setup)
B2_VARIANT=debug
B2_CXXFLAGS="-fkeep-static-functions --coverage"
B2_LINKFLAGS="--coverage"

# Build and run tests
./b2 libs/json/test \
    toolset=gcc-13 \
    variant=debug \
    cxxstd=11 \
    cxxflags="$B2_CXXFLAGS" \
    linkflags="$B2_LINKFLAGS" \
    -j$(nproc)

echo "=== Collecting coverage data with lcov ==="

cd "$BOOST_CI_SRC_FOLDER"

# Capture coverage data
lcov $LCOV_OPTIONS --gcov-tool="$GCOV" --directory "$BOOST_ROOT" --capture --output-file all.info

# Show summary
lcov $LCOV_OPTIONS --list all.info

# Filter to just json headers
for f in $(for h in include/boost/*; do echo "$h"; done | cut -f2- -d/); do echo "*/$f*"; done > /tmp/interesting
echo "=== Headers that matter ==="
cat /tmp/interesting

xargs -L 999999 -a /tmp/interesting \
    lcov $LCOV_OPTIONS --extract all.info "*/libs/$SELF/*" --output-file coverage.info

# Filter out test files for cleaner report
lcov $LCOV_OPTIONS --remove coverage.info '*/test/*' --output-file coverage_filtered.info || cp coverage.info coverage_filtered.info

# Show filtered summary
echo "=== Coverage Summary ==="
lcov $LCOV_OPTIONS --list coverage_filtered.info

# Generate gcovr JSON format (preserves function/branch data)
echo "=== Generating gcovr JSON output ==="
cd "$BOOST_ROOT"
gcovr --json --output /output/coverage.json \
    --filter ".*/$SELF/.*" \
    --exclude '.*/test/.*' \
    --exclude '.*/extra/.*'

# Also generate a full JSON with all coverage (for more complete data)
gcovr --json --output /output/coverage_full.json \
    --filter ".*/$SELF/.*"

# Copy LCOV results too (for reference)
echo "=== Copying results to /output ==="
cp "$BOOST_CI_SRC_FOLDER/all.info" "$BOOST_CI_SRC_FOLDER/coverage.info" "$BOOST_CI_SRC_FOLDER/coverage_filtered.info" /output/

echo ""
echo "=== DONE ==="
echo "Coverage files generated:"
ls -la /output/*.info
echo ""
echo "To use these files locally, copy them to your json/ directory:"
echo "  cp output/*.info json/"
