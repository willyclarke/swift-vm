#!/bin/bash
# Writes SwiftVM/BuildInfo.swift with the current git commit hash.
# Run automatically as an Xcode build phase and via `make build`.
HASH=$(git -C "$(dirname "$0")/.." rev-parse --short HEAD 2>/dev/null || echo "dev")
cat > "$(dirname "$0")/../SwiftVM/BuildInfo.swift" << EOF
// Auto-generated — do not edit. Run scripts/update-build-info.sh to refresh.
enum BuildInfo {
    static let gitHash = "$HASH"
}
EOF
