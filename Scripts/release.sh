#!/usr/bin/env bash
#
# release.sh - Master release orchestration script
#
# Automates the complete release workflow:
# 1. Pre-flight checks (clean repo, version bumped, env vars set)
# 2. Lint and test
# 3. Build, sign, and notarize (via sign-and-notarize.sh)
# 4. Generate Sparkle ed25519 signature
# 5. Update appcast.xml with new release item
# 6. Create GitHub release with assets
# 7. Verify release assets are accessible
# 8. Tag and push
#
# Usage:
#   ./Scripts/release.sh            # Full signed release (requires Apple Developer)
#   ./Scripts/release.sh --unsigned # Unsigned release (no Apple account needed)
#   ./Scripts/release.sh --dry-run  # Simulate without uploading
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="OptimusClip"
DRY_RUN=false
UNSIGNED=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            ;;
        --unsigned)
            UNSIGNED=true
            ;;
    esac
done

# Required environment variables (depends on mode)
if [[ "$UNSIGNED" == "true" ]]; then
    REQUIRED_ENV=(
        SPARKLE_PRIVATE_KEY_FILE
    )
else
    REQUIRED_ENV=(
        APP_STORE_CONNECT_KEY_ID
        APP_STORE_CONNECT_ISSUER_ID
        APP_STORE_CONNECT_API_KEY_P8
        DEVELOPER_ID_APP_IDENTITY
        SPARKLE_PRIVATE_KEY_FILE
    )
fi

# GitHub repo (extracted from git remote)
GITHUB_REPO="$(git -C "${ROOT_DIR}" remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/')"

log() {
    printf "\n\033[1;34m[release]\033[0m %s\n" "$1"
}

warn() {
    printf "\033[0;33mWARN:\033[0m %s\n" "$1"
}

fail() {
    printf "\033[0;31mERROR:\033[0m %s\n" "$1" >&2
    exit 1
}

success() {
    printf "\033[0;32m%s\033[0m\n" "$1"
}

# Load version metadata
source "${ROOT_DIR}/version.env"
MARKETING_VERSION="${MARKETING_VERSION:?}"
BUILD_NUMBER="${BUILD_NUMBER:?}"
VERSION_TAG="v${MARKETING_VERSION}"
DSYM_ZIP_NAME="${APP_NAME}-${MARKETING_VERSION}.dSYM.zip"

# Zip name depends on signing mode
if [[ "$UNSIGNED" == "true" ]]; then
    ZIP_NAME="${APP_NAME}-${MARKETING_VERSION}.zip"
else
    ZIP_NAME="${APP_NAME}-${MARKETING_VERSION}-notarized.zip"
fi

#
# Pre-flight checks
#
preflight_checks() {
    log "Running pre-flight checks"

    # Check for required commands
    for cmd in swift gh xmllint git codesign; do
        command -v "$cmd" >/dev/null 2>&1 || fail "Missing required command: $cmd"
    done

    # Check gh is authenticated
    gh auth status >/dev/null 2>&1 || fail "gh CLI not authenticated. Run: gh auth login"

    # Check for required environment variables
    for var in "${REQUIRED_ENV[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                warn "Missing env var: ${var} (ignored in dry-run)"
            else
                fail "Missing env var: ${var}"
            fi
        fi
    done

    # Check Sparkle private key file exists
    if [[ -n "${SPARKLE_PRIVATE_KEY_FILE:-}" ]] && [[ ! -f "${SPARKLE_PRIVATE_KEY_FILE}" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            warn "Sparkle private key not found: ${SPARKLE_PRIVATE_KEY_FILE} (ignored in dry-run)"
        else
            fail "Sparkle private key not found: ${SPARKLE_PRIVATE_KEY_FILE}"
        fi
    fi

    # Check for clean working directory
    if [[ -n "$(git -C "${ROOT_DIR}" status --porcelain)" ]]; then
        fail "Working directory not clean. Commit or stash changes first."
    fi

    # Check tag doesn't already exist
    if git -C "${ROOT_DIR}" rev-parse "${VERSION_TAG}" >/dev/null 2>&1; then
        fail "Tag ${VERSION_TAG} already exists. Bump version in version.env first."
    fi

    # Check GitHub release doesn't exist
    if gh release view "${VERSION_TAG}" --repo "${GITHUB_REPO}" >/dev/null 2>&1; then
        fail "GitHub release ${VERSION_TAG} already exists."
    fi

    success "Pre-flight checks passed"
}

#
# Lint and test
#
run_checks() {
    log "Running lint and tests"
    make -C "${ROOT_DIR}" check-test || fail "Lint or tests failed"
    success "Lint and tests passed"
}

#
# Build, sign, and notarize (or just build for unsigned)
#
build_and_sign() {
    if [[ "$UNSIGNED" == "true" ]]; then
        log "Building unsigned release"
    else
        log "Building, signing, and notarizing"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        warn "Dry-run: Skipping build"
        # Create placeholder files for dry-run
        touch "${ROOT_DIR}/${ZIP_NAME}"
        touch "${ROOT_DIR}/${DSYM_ZIP_NAME}"
        return
    fi

    if [[ "$UNSIGNED" == "true" ]]; then
        # Build and package without Apple signing
        "${ROOT_DIR}/Scripts/package_app.sh" release

        local app_bundle="${ROOT_DIR}/${APP_NAME}.app"
        [[ -d "${app_bundle}" ]] || fail "App bundle not found: ${app_bundle}"

        # Strip extended attributes
        xattr -cr "${app_bundle}" 2>/dev/null || true

        # Create zip with ditto (preserves signatures, no AppleDouble files)
        log "Creating distribution zip: ${ZIP_NAME}"
        ditto -c -k --keepParent --rsrc "${app_bundle}" "${ROOT_DIR}/${ZIP_NAME}"

        # Archive dSYM if present
        local dsym_dir="${ROOT_DIR}/.build/release/${APP_NAME}.dSYM"
        if [[ -d "${dsym_dir}" ]]; then
            log "Archiving dSYM: ${DSYM_ZIP_NAME}"
            ditto -c -k --keepParent "${dsym_dir}" "${ROOT_DIR}/${DSYM_ZIP_NAME}"
        else
            warn "No dSYM found; skipping dSYM archive"
            # Create empty placeholder so GitHub release doesn't fail
            touch "${ROOT_DIR}/${DSYM_ZIP_NAME}"
        fi

        success "Unsigned build complete"
        warn "Note: Users will see Gatekeeper warning (right-click > Open to bypass)"
    else
        # Full signed and notarized build
        "${ROOT_DIR}/Scripts/sign-and-notarize.sh"
        [[ -f "${ROOT_DIR}/${ZIP_NAME}" ]] || fail "Notarized zip not found: ${ZIP_NAME}"
        success "Build, sign, and notarize complete"
    fi
}

#
# Generate Sparkle ed25519 signature
#
generate_sparkle_signature() {
    log "Generating Sparkle ed25519 signature"

    local sign_update="${ROOT_DIR}/.build/artifacts/sparkle/Sparkle/bin/sign_update"
    if [[ ! -x "${sign_update}" ]]; then
        # Try to find it via swift package
        swift package --package-path "${ROOT_DIR}" resolve >/dev/null 2>&1 || true
        if [[ ! -x "${sign_update}" ]]; then
            fail "sign_update tool not found. Run: swift package resolve"
        fi
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        warn "Dry-run: Skipping signature generation"
        SPARKLE_SIGNATURE="DRY_RUN_SIGNATURE_PLACEHOLDER"
        return
    fi

    # Generate signature using the private key file
    SPARKLE_SIGNATURE="$("${sign_update}" "${ROOT_DIR}/${ZIP_NAME}" -f "${SPARKLE_PRIVATE_KEY_FILE}" 2>/dev/null | grep "sparkle:edSignature" | sed 's/.*"\([^"]*\)".*/\1/')"

    if [[ -z "${SPARKLE_SIGNATURE}" ]]; then
        fail "Failed to generate Sparkle signature"
    fi

    success "Sparkle signature generated"
}

#
# Update appcast.xml
#
update_appcast() {
    log "Updating appcast.xml"

    local appcast_file="${ROOT_DIR}/appcast.xml"
    local zip_path="${ROOT_DIR}/${ZIP_NAME}"
    local zip_size
    local pub_date
    local download_url

    if [[ "$DRY_RUN" == "true" ]]; then
        zip_size="12345678"
    else
        zip_size="$(stat -f%z "${zip_path}")"
    fi

    pub_date="$(date -u '+%a, %d %b %Y %H:%M:%S +0000')"
    download_url="https://github.com/${GITHUB_REPO}/releases/download/${VERSION_TAG}/${ZIP_NAME}"

    # Create new item XML
    local new_item
    new_item=$(cat <<EOF
        <item>
            <title>Version ${MARKETING_VERSION}</title>
            <link>https://github.com/${GITHUB_REPO}/releases/tag/${VERSION_TAG}</link>
            <sparkle:version>${BUILD_NUMBER}</sparkle:version>
            <sparkle:shortVersionString>${MARKETING_VERSION}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
            <pubDate>${pub_date}</pubDate>
            <enclosure
                url="${download_url}"
                length="${zip_size}"
                type="application/octet-stream"
                sparkle:edSignature="${SPARKLE_SIGNATURE}" />
            <description><![CDATA[
                <h2>What's New in ${MARKETING_VERSION}</h2>
                <p>See release notes on GitHub for details.</p>
            ]]></description>
        </item>
EOF
)

    # Insert new item after the comment in channel (before closing </channel>)
    # Using sed to insert after the comment line
    local temp_file
    temp_file="$(mktemp)"

    # Insert new item right after the automation comment
    sed "s|<!-- Release items are added by release automation (newest first). -->|<!-- Release items are added by release automation (newest first). -->\n${new_item}|" \
        "${appcast_file}" > "${temp_file}"

    # Validate XML
    if ! xmllint --noout "${temp_file}" 2>/dev/null; then
        rm -f "${temp_file}"
        fail "Generated appcast.xml is invalid XML"
    fi

    mv "${temp_file}" "${appcast_file}"
    success "appcast.xml updated with ${VERSION_TAG}"
}

#
# Create GitHub release
#
create_github_release() {
    log "Creating GitHub release ${VERSION_TAG}"

    local release_notes="Release ${MARKETING_VERSION}

See [CHANGELOG](https://github.com/${GITHUB_REPO}/blob/main/CHANGELOG.md) for details."

    if [[ "$DRY_RUN" == "true" ]]; then
        warn "Dry-run: Would create GitHub release ${VERSION_TAG}"
        warn "Dry-run: Would upload: ${ZIP_NAME}, ${DSYM_ZIP_NAME}"
        return
    fi

    # Create release and upload assets
    gh release create "${VERSION_TAG}" \
        --repo "${GITHUB_REPO}" \
        --title "${APP_NAME} ${MARKETING_VERSION}" \
        --notes "${release_notes}" \
        "${ROOT_DIR}/${ZIP_NAME}" \
        "${ROOT_DIR}/${DSYM_ZIP_NAME}"

    success "GitHub release created: ${VERSION_TAG}"
}

#
# Verify release assets
#
verify_release() {
    log "Verifying release assets"

    if [[ "$DRY_RUN" == "true" ]]; then
        warn "Dry-run: Skipping release verification"
        return
    fi

    # Check release exists
    gh release view "${VERSION_TAG}" --repo "${GITHUB_REPO}" >/dev/null || fail "Release not found"

    # Check assets are downloadable
    local download_url="https://github.com/${GITHUB_REPO}/releases/download/${VERSION_TAG}/${ZIP_NAME}"
    local http_code
    http_code="$(curl -sL -o /dev/null -w '%{http_code}' "${download_url}")"

    if [[ "${http_code}" != "200" ]] && [[ "${http_code}" != "302" ]]; then
        warn "Asset may not be accessible yet (HTTP ${http_code}). GitHub CDN propagation can take a few minutes."
    fi

    success "Release verification complete"
}

#
# Tag and push
#
tag_and_push() {
    log "Tagging and pushing"

    if [[ "$DRY_RUN" == "true" ]]; then
        warn "Dry-run: Would commit appcast.xml"
        warn "Dry-run: Would create tag ${VERSION_TAG}"
        warn "Dry-run: Would push to origin"
        return
    fi

    # Commit updated appcast.xml
    git -C "${ROOT_DIR}" add appcast.xml
    git -C "${ROOT_DIR}" commit -m "chore(release): update appcast for ${VERSION_TAG}"

    # Create annotated tag
    git -C "${ROOT_DIR}" tag -a "${VERSION_TAG}" -m "Release ${MARKETING_VERSION}"

    # Push commit and tag
    git -C "${ROOT_DIR}" push origin main
    git -C "${ROOT_DIR}" push origin "${VERSION_TAG}"

    success "Tagged ${VERSION_TAG} and pushed to origin"
}

#
# Main workflow
#
main() {
    echo ""
    echo "========================================"
    echo " ${APP_NAME} Release Script"
    echo " Version: ${MARKETING_VERSION} (build ${BUILD_NUMBER})"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo " Mode: DRY RUN (no uploads)"
    elif [[ "$UNSIGNED" == "true" ]]; then
        echo " Mode: UNSIGNED (no Apple Developer account)"
    else
        echo " Mode: SIGNED (full notarization)"
    fi
    echo "========================================"

    preflight_checks
    run_checks
    build_and_sign
    generate_sparkle_signature
    update_appcast
    create_github_release
    verify_release
    tag_and_push

    echo ""
    echo "========================================"
    success "Release ${VERSION_TAG} complete!"
    echo "========================================"
    echo ""
    if [[ "$UNSIGNED" == "true" ]]; then
        warn "UNSIGNED RELEASE - Users will see Gatekeeper warning"
        echo ""
        echo "To install, users must:"
        echo "  1. Download the zip"
        echo "  2. Extract the app"
        echo "  3. Right-click > Open (first time only)"
        echo "  4. Click 'Open' in the dialog"
        echo ""
        echo "Note: Sparkle auto-updates will NOT work (app not signed with Developer ID)"
        echo ""
    fi
    echo "Next steps:"
    echo "  1. Verify release at: https://github.com/${GITHUB_REPO}/releases/tag/${VERSION_TAG}"
    echo "  2. Check appcast: https://raw.githubusercontent.com/${GITHUB_REPO}/main/appcast.xml"
    echo "  3. Bump version in version.env for next release"
    echo ""

    # Cleanup dry-run placeholder files
    if [[ "$DRY_RUN" == "true" ]]; then
        rm -f "${ROOT_DIR}/${ZIP_NAME}" "${ROOT_DIR}/${DSYM_ZIP_NAME}"
    fi
}

main
