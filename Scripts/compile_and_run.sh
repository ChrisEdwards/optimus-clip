#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1. Stop any running instances
"${ROOT_DIR}/Scripts/kill_optimusclip.sh" || true

# 2. Build (debug, fast)
swift build

# 3. Create minimal .app bundle
"${ROOT_DIR}/Scripts/package_app.sh" debug

# 4. Launch
open "${ROOT_DIR}/OptimusClip.app"

# 5. Verify it's running (wait up to 5 seconds)
for i in {1..10}; do
    if pgrep -x "OptimusClip" > /dev/null; then
        echo "✓ OptimusClip running"
        exit 0
    fi
    sleep 0.5
done
echo "⚠ OptimusClip may not have started"
