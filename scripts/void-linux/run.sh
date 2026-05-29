#!/bin/bash
# Run the Void Linux VM headlessly — no window, interact via SSH.
# Usage: ./run.sh [bundle-name]
#   bundle-name defaults to "Linux VM" (~/Linux VM.bundle)
#
# First run compiles the Swift CLI tool and caches the binary.
# Subsequent runs use the cached binary unless source changes.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$SCRIPT_DIR/.swiftvm-cli"
ENTITLEMENTS="$SCRIPT_DIR/SwiftVMCLI.entitlements"

if [ ! -f "$BIN" ] || [ "$SCRIPT_DIR/main.swift" -nt "$BIN" ]; then
    echo "Compiling CLI tool…"
    swiftc -framework Virtualization "$SCRIPT_DIR/main.swift" -o "$BIN"
    codesign --entitlements "$ENTITLEMENTS" -s - "$BIN"
    echo "Done."
fi

exec "$BIN" "$@"
