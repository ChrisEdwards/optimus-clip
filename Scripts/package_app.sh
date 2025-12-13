#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-debug}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source version info
source "${ROOT_DIR}/version.env"

APP_NAME="OptimusClip"
APP_BUNDLE="${ROOT_DIR}/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

# Select Info.plist based on build mode
# Debug builds use a separate bundle ID for isolated accessibility permissions
if [[ "$MODE" == "release" ]]; then
    INFO_PLIST="${ROOT_DIR}/Info.plist"
else
    INFO_PLIST="${ROOT_DIR}/Info.debug.plist"
fi

# Build
if [[ "$MODE" == "release" ]]; then
    swift build -c release
    BINARY="${ROOT_DIR}/.build/release/${APP_NAME}"
else
    swift build
    BINARY="${ROOT_DIR}/.build/debug/${APP_NAME}"
fi

# Create bundle structure
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS}" "${RESOURCES}"

# Copy binary
cp "${BINARY}" "${MACOS}/${APP_NAME}"

# Generate Info.plist with version substitution
sed -e "s/\$(MARKETING_VERSION)/${MARKETING_VERSION}/g" \
    -e "s/\$(BUILD_NUMBER)/${BUILD_NUMBER}/g" \
    -e "s/\$(BUNDLE_ID)/${BUNDLE_ID}/g" \
    "${INFO_PLIST}" > "${CONTENTS}/Info.plist"

# Copy icon if exists
[[ -f "${ROOT_DIR}/Icon.icns" ]] && cp "${ROOT_DIR}/Icon.icns" "${RESOURCES}/AppIcon.icns"

# Ad-hoc sign the app for consistent identity (prevents accessibility permission reset on rebuild)
codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || true

echo "✓ Packaged ${APP_BUNDLE} (${MODE}, v${MARKETING_VERSION} build ${BUILD_NUMBER})"
