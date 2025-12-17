#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="OptimusClip"
APP_BUNDLE="${ROOT_DIR}/${APP_NAME}.app"
BUILD_DIR="${ROOT_DIR}/.build/release"
DSYM_DIR="${BUILD_DIR}/${APP_NAME}.dSYM"
DIST_DIR="${ROOT_DIR}"

# Required environment variables (do not hardcode secrets)
REQUIRED_ENV=(
    APP_STORE_CONNECT_KEY_ID
    APP_STORE_CONNECT_ISSUER_ID
    APP_STORE_CONNECT_API_KEY_P8   # base64-encoded .p8 contents
    DEVELOPER_ID_APP_IDENTITY      # e.g., "Developer ID Application: Your Name (TEAMID)"
)

log() {
    printf "\n\033[1;34m[%s]\033[0m %s\n" "sign-and-notarize" "$1"
}

fail() {
    printf "\033[0;31mERROR:\033[0m %s\n" "$1" >&2
    exit 1
}

check_env() {
    for var in "${REQUIRED_ENV[@]}"; do
        [[ -n "${!var:-}" ]] || fail "Missing env var: ${var}"
    done
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

# Load version metadata
source "${ROOT_DIR}/version.env"
MARKETING_VERSION="${MARKETING_VERSION:?}"
BUILD_NUMBER="${BUILD_NUMBER:?}"

VERSION_TAG="${MARKETING_VERSION}"
ZIP_NAME="${APP_NAME}-${VERSION_TAG}.zip"
NOTARIZED_ZIP_NAME="${APP_NAME}-${VERSION_TAG}-notarized.zip"
DSYM_ZIP_NAME="${APP_NAME}-${VERSION_TAG}.dSYM.zip"

check_env
require_cmd swift
require_cmd xcrun
require_cmd codesign
require_cmd ditto
require_cmd stat

cleanup() {
    [[ -f "${TMP_KEY_FILE:-}" ]] && rm -f "${TMP_KEY_FILE}"
}
trap cleanup EXIT

# Step 1: Build + package (release)
log "Building and packaging app (release)"
"${ROOT_DIR}/Scripts/package_app.sh" release

[[ -d "${APP_BUNDLE}" ]] || fail "App bundle not found at ${APP_BUNDLE}"

# Step 2: Hardened runtime signing with Developer ID Application
log "Signing app with hardened runtime"
codesign --force --deep --options runtime --timestamp --sign "${DEVELOPER_ID_APP_IDENTITY}" "${APP_BUNDLE}"
codesign --verify --deep --strict "${APP_BUNDLE}" || fail "codesign verification failed"

# Step 3: Strip extended attributes that can break signatures/zips
log "Stripping extended attributes"
if command -v xattr >/dev/null 2>&1; then
    xattr -cr "${APP_BUNDLE}" || true
fi

# Step 4: Create distribution zip (pre-notarization)
log "Creating distribution zip (pre-notarization): ${ZIP_NAME}"
ditto -c -k --keepParent --rsrc "${APP_BUNDLE}" "${DIST_DIR}/${ZIP_NAME}"

# Step 5: Submit for notarization (wait for completion)
log "Submitting for notarization (this can take several minutes)"
TMP_KEY_FILE="$(mktemp "${TMPDIR:-/tmp}/asc-key.XXXXXX")"
echo "${APP_STORE_CONNECT_API_KEY_P8}" | base64 -d > "${TMP_KEY_FILE}"

NOTARY_OUTPUT="$(
    xcrun notarytool submit "${DIST_DIR}/${ZIP_NAME}" \
        --key-id "${APP_STORE_CONNECT_KEY_ID}" \
        --issuer "${APP_STORE_CONNECT_ISSUER_ID}" \
        --key "${TMP_KEY_FILE}" \
        --wait
)"
echo "${NOTARY_OUTPUT}"

if ! grep -q "status: Accepted" <<< "${NOTARY_OUTPUT}"; then
    fail "Notarization did not report Accepted. See output above."
fi

# Step 6: Staple ticket
log "Stapling notarization ticket"
xcrun stapler staple "${APP_BUNDLE}"
xcrun stapler validate "${APP_BUNDLE}"

# Step 7: Gatekeeper check
log "Running Gatekeeper verification (spctl)"
spctl -a -t exec -vv "${APP_BUNDLE}"

# Step 8: Create notarized zip
log "Creating notarized distribution zip: ${NOTARIZED_ZIP_NAME}"
ditto -c -k --keepParent --rsrc "${APP_BUNDLE}" "${DIST_DIR}/${NOTARIZED_ZIP_NAME}"

# Step 9: Archive dSYM if present
if [[ -d "${DSYM_DIR}" ]]; then
    log "Archiving dSYM: ${DSYM_ZIP_NAME}"
    ditto -c -k --keepParent "${DSYM_DIR}" "${DIST_DIR}/${DSYM_ZIP_NAME}"
else
    log "No dSYM found at ${DSYM_DIR}; skipping dSYM archive"
fi

log "Success. Outputs:"
printf "  - %s/%s (pre-notarization)\n" "${DIST_DIR}" "${ZIP_NAME}"
printf "  - %s/%s (notarized)\n" "${DIST_DIR}" "${NOTARIZED_ZIP_NAME}"
[[ -d "${DSYM_DIR}" ]] && printf "  - %s/%s (dSYM)\n" "${DIST_DIR}" "${DSYM_ZIP_NAME}"
