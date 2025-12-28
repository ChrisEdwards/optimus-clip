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
FRAMEWORKS="${CONTENTS}/Frameworks"

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
mkdir -p "${MACOS}" "${RESOURCES}" "${FRAMEWORKS}"

# Copy binary
cp "${BINARY}" "${MACOS}/${APP_NAME}"

# Add rpath for embedded frameworks
# This allows the binary to find Sparkle.framework in Contents/Frameworks
install_name_tool -add_rpath "@executable_path/../Frameworks" "${MACOS}/${APP_NAME}" 2>/dev/null || true

# Copy Sparkle.framework
# Use the framework from the build directory (matches the build configuration)
if [[ "$MODE" == "release" ]]; then
    SPARKLE_SRC="${ROOT_DIR}/.build/arm64-apple-macosx/release/Sparkle.framework"
else
    SPARKLE_SRC="${ROOT_DIR}/.build/arm64-apple-macosx/debug/Sparkle.framework"
fi

# Fallback to xcframework if build-specific framework not found
if [[ ! -d "${SPARKLE_SRC}" ]]; then
    SPARKLE_SRC="${ROOT_DIR}/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
fi

if [[ -d "${SPARKLE_SRC}" ]]; then
    cp -R "${SPARKLE_SRC}" "${FRAMEWORKS}/"
    echo "✓ Bundled Sparkle.framework"
else
    echo "⚠️  Warning: Sparkle.framework not found, app may not launch"
fi

# Generate Info.plist with version substitution
sed -e "s/\$(MARKETING_VERSION)/${MARKETING_VERSION}/g" \
    -e "s/\$(BUILD_NUMBER)/${BUILD_NUMBER}/g" \
    -e "s/\$(BUNDLE_ID)/${BUNDLE_ID}/g" \
    "${INFO_PLIST}" > "${CONTENTS}/Info.plist"

# Copy icon if exists
[[ -f "${ROOT_DIR}/Icon.icns" ]] && cp "${ROOT_DIR}/Icon.icns" "${RESOURCES}/AppIcon.icns"

# Code sign the app
# Debug builds use "OptimusClip Dev" certificate if available (preserves accessibility permissions)
# Release builds use ad-hoc signing (will be properly signed for distribution later)
DEV_CERT="OptimusClip Dev"
if [[ "$MODE" != "release" ]] && security find-identity -v -p codesigning 2>/dev/null | grep -q "${DEV_CERT}"; then
    codesign --force --deep --sign "${DEV_CERT}" "${APP_BUNDLE}" 2>/dev/null
    SIGN_INFO="signed with ${DEV_CERT}"
else
    codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || true
    SIGN_INFO="ad-hoc signed"
fi

echo "✓ Packaged ${APP_BUNDLE} (${MODE}, v${MARKETING_VERSION} build ${BUILD_NUMBER}, ${SIGN_INFO})"
