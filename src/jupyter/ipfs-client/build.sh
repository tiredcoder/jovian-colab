#!/usr/bin/sh
SCRIPT_DIR=$(dirname "$0")

echo ' *** Building... *** '
rm -rf "$SCRIPT_DIR/dist"
python3 -m pip install build
python3 -m build "$SCRIPT_DIR"

#python3 -m pip install "$SCRIPT_DIR"/dist/*.whl
