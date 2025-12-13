#!/usr/bin/env bash
# Automated Phase 1 verification script
# Runs before marking phase complete

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "Phase 1 Verification Starting..."
echo ""

# 1. Build and Test
echo "[1/6] Running build and tests..."
npm run build || { echo "Build failed"; exit 1; }
npm run test || { echo "Tests failed"; exit 1; }
npm run check || { echo "Format/lint failed"; exit 1; }
echo "Build, test, and lint passed"
echo ""

# 2. Package app
echo "[2/6] Packaging app..."
npm run package || { echo "Packaging failed"; exit 1; }

APP_BUNDLE="${ROOT_DIR}/dist/OptimusClip.app"
if [[ ! -d "${APP_BUNDLE}" ]]; then
    # Try alternative location
    APP_BUNDLE="${ROOT_DIR}/OptimusClip.app"
fi
if [[ ! -d "${APP_BUNDLE}" ]]; then
    echo "App bundle not created at expected locations"
    exit 1
fi
echo "App bundle created at: ${APP_BUNDLE}"
echo ""

# 3. Verify Info.plist settings
echo "[3/6] Verifying Info.plist..."
INFO_PLIST="${APP_BUNDLE}/Contents/Info.plist"

if [[ ! -f "${INFO_PLIST}" ]]; then
    echo "Info.plist not found at ${INFO_PLIST}"
    exit 1
fi

LSUIElement=$(/usr/libexec/PlistBuddy -c "Print :LSUIElement" "${INFO_PLIST}" 2>/dev/null || echo "missing")
if [[ "$LSUIElement" != "true" && "$LSUIElement" != "1" ]]; then
    echo "LSUIElement not set correctly (got: $LSUIElement)"
    exit 1
fi
echo "  LSUIElement: $LSUIElement"

LSMultiple=$(/usr/libexec/PlistBuddy -c "Print :LSMultipleInstancesProhibited" "${INFO_PLIST}" 2>/dev/null || echo "missing")
if [[ "$LSMultiple" != "true" && "$LSMultiple" != "1" ]]; then
    echo "LSMultipleInstancesProhibited not set correctly (got: $LSMultiple)"
    exit 1
fi
echo "  LSMultipleInstancesProhibited: $LSMultiple"

MinVersion=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "${INFO_PLIST}" 2>/dev/null || echo "missing")
if [[ "$MinVersion" != "15.0" ]]; then
    echo "LSMinimumSystemVersion not set correctly (got: $MinVersion)"
    exit 1
fi
echo "  LSMinimumSystemVersion: $MinVersion"
echo ""

# 4. Kill existing instances
echo "[4/6] Cleaning up existing instances..."
npm run stop 2>/dev/null || true
sleep 1
echo ""

# 5. Launch app
echo "[5/6] Launching app..."
open -a "${APP_BUNDLE}"

# Wait for launch (needs longer on cold start)
sleep 5

# 6. Verify app is running
echo "[6/6] Verifying app is running..."
PROCESS_COUNT=$(pgrep OptimusClip | wc -l | tr -d ' ')
if [[ "$PROCESS_COUNT" != "1" ]]; then
    echo "App not running as single instance (found: $PROCESS_COUNT processes)"
    exit 1
fi
echo "  Single instance running"

# Memory check
PID=$(pgrep OptimusClip | head -1)
MEMORY_KB=$(ps -o rss= -p "$PID" 2>/dev/null || echo "0")
MEMORY_MB=$((MEMORY_KB / 1024))
echo "  Memory usage: ${MEMORY_MB} MB"
if [[ "$MEMORY_MB" -gt 100 ]]; then
    echo "Warning: Memory usage high (${MEMORY_MB} MB)"
fi
echo ""

echo "============================================"
echo "Automated checks passed!"
echo "============================================"
echo ""
echo "Manual verification required:"
echo "  1. Check menu bar icon visible"
echo "  2. Test icon states (debugger or UI)"
echo "  3. Test keyboard shortcuts (Cmd+, and Cmd+Q)"
echo "  4. Test dark mode compatibility"
echo "  5. Complete checklist in Tests/Manual/Phase1Checklist.md"
echo ""
echo "When all items pass, mark Phase 1 complete."
