#!/bin/bash
#
# Set up local Python venv with gcovr 8.3 for template development
#
# Usage:
#   ./setup-local-venv.sh
#   source .venv/bin/activate
#   ./build.sh
#
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Setting up Python venv with gcovr 8.4 ==="

# Create venv
python3 -m venv .venv

# Activate and install
source .venv/bin/activate

pip install --upgrade pip
pip install gcovr==8.4 lcov_cobertura

echo ""
echo "=== Setup complete ==="
echo ""
echo "To use:"
echo "  source .venv/bin/activate"
echo "  ./build.sh"
echo ""
echo "Your gcovr version:"
gcovr --version
