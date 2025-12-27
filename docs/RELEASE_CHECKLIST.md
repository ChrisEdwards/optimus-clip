# Phase 7 Release Verification Checklist

Complete this checklist before the first production release to ensure all release infrastructure is functional.

## Prerequisites

- [ ] Apple Developer Program membership active ($99/year)
- [ ] Developer ID Application certificate installed in Keychain
- [ ] App Store Connect API key created and .p8 file saved
- [ ] Sparkle ed25519 key pair generated (public key in Info.plist)
- [ ] All environment variables configured (see RELEASE_PREREQUISITES.md)

## Code Signature Verification

```bash
# Run these commands on the signed .app bundle
```

- [ ] `codesign --verify --deep --strict OptimusClip.app` exits with code 0
- [ ] `codesign -dvvv OptimusClip.app` shows:
  - [ ] `Authority=Developer ID Application: Your Name (TEAMID)`
  - [ ] `Signature=adhoc` is NOT present
  - [ ] `flags=...runtime` (hardened runtime enabled)
  - [ ] `TeamIdentifier` matches expected value
- [ ] No unsigned frameworks: `codesign --verify --deep` succeeds for all embedded code

## Gatekeeper Verification

- [ ] `spctl -a -t exec -vv OptimusClip.app` exits with code 0
- [ ] spctl output shows `source=Notarized Developer ID`
- [ ] spctl output shows `origin=Developer ID Application: Your Name`
- [ ] App opens on clean Mac (no development tools) without warnings
- [ ] No "unidentified developer" dialog on first launch

## Notarization Verification

- [ ] `xcrun stapler validate OptimusClip.app` exits with code 0
- [ ] stapler output shows "The validate action worked"
- [ ] `xcrun notarytool history` shows successful submissions
- [ ] Offline verification works (test with network disabled)

## Sparkle Integration

- [ ] "Check for Updates" menu item appears in signed production builds
- [ ] No Sparkle dialogs in development builds (`swift run`)
- [ ] Console shows `[UpdaterWrapper] Updates disabled` for unsigned builds
- [ ] Console shows `[UpdaterWrapper] Updates enabled` for signed builds
- [ ] SPUStandardUpdaterController initializes without errors
- [ ] No crashes related to Sparkle framework

## Appcast Verification

- [ ] `xmllint --noout appcast.xml` exits with code 0
- [ ] `curl -I https://raw.githubusercontent.com/.../appcast.xml` returns HTTP 200
- [ ] Latest version item has `sparkle:edSignature` attribute
- [ ] Enclosure URL returns HTTP 200
- [ ] Enclosure `length` matches actual file size: `stat -f%z OptimusClip.zip`
- [ ] Sparkle namespace declared correctly: `xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"`
- [ ] Items ordered newest first

## GitHub Release Verification

- [ ] `gh release view vVERSION` succeeds
- [ ] `.zip` asset present and downloadable
- [ ] `.dSYM.zip` asset present (for crash symbolication)
- [ ] Release notes match CHANGELOG.md entry
- [ ] `./Scripts/check-release-assets.sh vVERSION` passes all checks

## Update Flow Verification

Test the complete update flow:

1. [ ] Install previous version (e.g., v1.0.0)
2. [ ] Run app, open "Check for Updates"
3. [ ] Verify Sparkle shows new version available
4. [ ] Verify release notes displayed correctly
5. [ ] Click "Install Update"
6. [ ] Verify download completes without errors
7. [ ] Verify app restarts with new version
8. [ ] Verify app functions correctly after update

## Script Verification

- [ ] `./Scripts/release.sh --dry-run` completes without errors
- [ ] Pre-flight checks detect dirty working directory
- [ ] Pre-flight checks detect existing tag
- [ ] `./Scripts/check-release-assets.sh vVERSION` reports correct status
- [ ] `./Scripts/sign-and-notarize.sh` completes successfully

## Environment Variables

Verify all required variables are set:

```bash
# Check each variable is non-empty
echo "APP_STORE_CONNECT_KEY_ID: ${APP_STORE_CONNECT_KEY_ID:-(not set)}"
echo "APP_STORE_CONNECT_ISSUER_ID: ${APP_STORE_CONNECT_ISSUER_ID:-(not set)}"
echo "APP_STORE_CONNECT_API_KEY_P8: ${APP_STORE_CONNECT_API_KEY_P8:+set}"
echo "DEVELOPER_ID_APP_IDENTITY: ${DEVELOPER_ID_APP_IDENTITY:-(not set)}"
echo "SPARKLE_PRIVATE_KEY_FILE: ${SPARKLE_PRIVATE_KEY_FILE:-(not set)}"
```

- [ ] All variables are set and valid
- [ ] API key file exists at `SPARKLE_PRIVATE_KEY_FILE` path
- [ ] Certificate identity found: `security find-identity -v -p codesigning | grep "$DEVELOPER_ID_APP_IDENTITY"`

## Documentation

- [ ] RELEASE_PREREQUISITES.md is accurate and complete
- [ ] RELEASE_PROCESS.md matches actual release steps
- [ ] RELEASE_GOTCHAS.md covers known issues
- [ ] Environment variable documentation is current

## Sign-off

| Verification | Date | Verified By |
|--------------|------|-------------|
| Prerequisites complete | | |
| Code signature valid | | |
| Gatekeeper accepts | | |
| Notarization working | | |
| Sparkle integration working | | |
| Appcast valid | | |
| GitHub releases working | | |
| Update flow tested | | |
| Scripts working | | |
| Environment configured | | |

**Phase 7 Release Infrastructure: READY FOR PRODUCTION**

Date: ____________

Verified by: ____________
