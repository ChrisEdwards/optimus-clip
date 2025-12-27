#!/usr/bin/env bash
#
# check-release-assets.sh - Verify GitHub release has all required assets
#
# Validates that a GitHub release was created successfully with all
# required assets accessible and downloadable.
#
# Usage:
#   ./Scripts/check-release-assets.sh v1.0.0
#   ./Scripts/check-release-assets.sh v1.0.0 --skip-dsym
#
set -euo pipefail

# Configuration
MAX_RETRIES=3
RETRY_DELAY=30

# Parse arguments
TAG=""
SKIP_DSYM=false

for arg in "$@"; do
    case $arg in
        --skip-dsym)
            SKIP_DSYM=true
            ;;
        v*)
            TAG="$arg"
            ;;
        *)
            if [[ -z "$TAG" ]]; then
                TAG="$arg"
            fi
            ;;
    esac
done

if [[ -z "$TAG" ]]; then
    echo "Usage: check-release-assets.sh <tag> [--skip-dsym]"
    echo "  tag: Release tag (e.g., v1.0.0)"
    echo "  --skip-dsym: Skip dSYM verification"
    exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Parse version from tag (strip 'v' prefix if present)
VERSION="${TAG#v}"

# Expected assets (using notarized zip name from sign-and-notarize.sh)
APP_ZIP="OptimusClip-${VERSION}-notarized.zip"
DSYM_ZIP="OptimusClip-${VERSION}.dSYM.zip"

# GitHub repository (from environment or git remote)
if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
    REPO="${GITHUB_REPOSITORY}"
else
    REPO="$(git -C "${ROOT_DIR}" remote get-url origin | sed -e 's/.*github.com[:/]\(.*\)\.git/\1/')"
fi

log() {
    printf "\033[1;34m[check-assets]\033[0m %s\n" "$1"
}

warn() {
    printf "\033[0;33mWARN:\033[0m %s\n" "$1"
}

fail() {
    printf "\033[0;31mERROR:\033[0m %s\n" "$1" >&2
    exit "${2:-1}"
}

success() {
    printf "\033[0;32m✓\033[0m %s\n" "$1"
}

# Check required commands
command -v gh >/dev/null 2>&1 || fail "Missing required command: gh" 1
command -v curl >/dev/null 2>&1 || fail "Missing required command: curl" 1
command -v jq >/dev/null 2>&1 || fail "Missing required command: jq" 1

# Check gh is authenticated
gh auth status >/dev/null 2>&1 || fail "gh CLI not authenticated. Run: gh auth login" 1

echo ""
log "Checking release assets for ${TAG} in ${REPO}"
echo ""

#
# 1. Check release exists
#
log "Checking release exists..."
if ! gh api "repos/${REPO}/releases/tags/${TAG}" >/dev/null 2>&1; then
    fail "Release ${TAG} not found in ${REPO}" 1
fi
success "Release ${TAG} exists"

#
# 2. Get release assets
#
log "Checking required assets..."
ASSETS=$(gh api "repos/${REPO}/releases/tags/${TAG}" --jq '.assets[].name')

if ! echo "${ASSETS}" | grep -q "^${APP_ZIP}\$"; then
    # Also check for non-notarized name (backwards compatibility)
    ALT_ZIP="OptimusClip-${VERSION}.zip"
    if echo "${ASSETS}" | grep -q "^${ALT_ZIP}\$"; then
        APP_ZIP="${ALT_ZIP}"
        warn "Using non-notarized zip name: ${APP_ZIP}"
    else
        echo "Available assets:"
        echo "${ASSETS}" | sed 's/^/  - /'
        fail "${APP_ZIP} not found in release assets" 2
    fi
fi
success "${APP_ZIP} present"

if [[ "$SKIP_DSYM" == "false" ]]; then
    if ! echo "${ASSETS}" | grep -q "^${DSYM_ZIP}\$"; then
        warn "${DSYM_ZIP} not found in release assets (crash symbolication will not work)"
    else
        success "${DSYM_ZIP} present"
    fi
fi

#
# 3. Get download URL
#
APP_URL=$(gh api "repos/${REPO}/releases/tags/${TAG}" --jq ".assets[] | select(.name == \"${APP_ZIP}\") | .browser_download_url")

if [[ -z "${APP_URL}" ]]; then
    fail "Could not get download URL for ${APP_ZIP}" 2
fi

#
# 4. Check URL accessibility (with retry for CDN propagation)
#
log "Checking asset accessibility..."

check_url() {
    local url="$1"
    local name="$2"
    local http_code

    for i in $(seq 1 $MAX_RETRIES); do
        http_code=$(curl -s -o /dev/null -w "%{http_code}" -L "${url}")

        if [[ "${http_code}" == "200" ]] || [[ "${http_code}" == "302" ]]; then
            return 0
        fi

        if [[ $i -lt $MAX_RETRIES ]]; then
            warn "Attempt $i/$MAX_RETRIES: ${name} returned HTTP ${http_code}"
            log "Waiting ${RETRY_DELAY}s for CDN propagation..."
            sleep $RETRY_DELAY
        fi
    done

    echo "ERROR: ${name} returned HTTP ${http_code} after ${MAX_RETRIES} retries"
    return 1
}

if ! check_url "${APP_URL}" "${APP_ZIP}"; then
    fail "${APP_URL} not accessible" 3
fi
success "${APP_ZIP} accessible (HTTP 200)"

#
# 5. Check Content-Type
#
CONTENT_TYPE=$(curl -sI -L "${APP_URL}" | grep -i "^content-type:" | head -1 | awk '{print $2}' | tr -d '\r')

case "${CONTENT_TYPE}" in
    application/zip*|application/octet-stream*|application/x-zip*|binary/octet-stream*)
        success "Content-Type: ${CONTENT_TYPE}"
        ;;
    *)
        warn "Unexpected Content-Type: ${CONTENT_TYPE} (expected application/zip or application/octet-stream)"
        ;;
esac

#
# 6. Check file size
#
REMOTE_SIZE=$(curl -sI -L "${APP_URL}" | grep -i "^content-length:" | tail -1 | awk '{print $2}' | tr -d '\r')

if [[ -n "${REMOTE_SIZE}" ]] && [[ "${REMOTE_SIZE}" -gt 0 ]]; then
    # Convert to MB for readability
    SIZE_MB=$(echo "scale=2; ${REMOTE_SIZE} / 1048576" | bc)
    success "File size: ${SIZE_MB} MB (${REMOTE_SIZE} bytes)"

    # Check against local file if exists
    if [[ -f "${ROOT_DIR}/${APP_ZIP}" ]]; then
        LOCAL_SIZE=$(stat -f%z "${ROOT_DIR}/${APP_ZIP}" 2>/dev/null || echo "0")
        if [[ "${REMOTE_SIZE}" != "${LOCAL_SIZE}" ]]; then
            warn "Size mismatch: remote=${REMOTE_SIZE}, local=${LOCAL_SIZE}"
        fi
    fi
else
    warn "Could not determine remote file size"
fi

#
# 7. Test download
#
log "Testing download..."
if ! curl -fsSL -o /dev/null "${APP_URL}"; then
    fail "Download test failed" 4
fi
success "Download successful"

#
# Summary
#
echo ""
echo "========================================"
printf "\033[0;32m✅ All checks passed for ${TAG}\033[0m\n"
echo "========================================"
echo ""
echo "Release URL: https://github.com/${REPO}/releases/tag/${TAG}"
echo "Download: ${APP_URL}"
echo ""
