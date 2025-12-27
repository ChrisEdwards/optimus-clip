# Release Gotchas and Solutions

Common issues encountered during the release process and how to fix them.

## 1. Sparkle Key Format Error

**Issue:** `sign_update` fails with "invalid key format" or "could not parse key"

**Cause:** Private key has PEM headers, comments, or line breaks

**Solution:**
```bash
# Convert to clean single-line format
cat sparkle_private_key.pem | grep -v "BEGIN\|END\|PRIVATE KEY" | tr -d '\n' > sparkle_key_clean.txt

# Verify single line
wc -l sparkle_key_clean.txt  # Should output "0"
```

## 2. Bundle Identifier Mismatch

**Issue:** Notarization fails with "bundle ID does not match certificate"

**Cause:** `Info.plist` CFBundleIdentifier differs from certificate

**Solution:**
```bash
# Check current bundle ID
codesign -d -r- OptimusClip.app | grep identifier

# Verify Info.plist
defaults read OptimusClip.app/Contents/Info.plist CFBundleIdentifier

# Fix: Update Info.plist to match certificate, or regenerate certificate
```

## 3. AppleDouble Files Break Signatures

**Issue:** "App is damaged and cannot be opened" on user's Mac

**Cause:** `zip` command creates `._` metadata files that corrupt signatures

**Solution:**
```bash
# WRONG - creates AppleDouble files
zip -r App.zip App.app

# CORRECT - use ditto
ditto -c -k --keepParent App.app App.zip

# Cleanup before signing
xattr -cr App.app
find App.app -name "._*" -delete
```

## 4. Signature Verification Fails

**Issue:** `codesign --verify` fails with "invalid signature"

**Cause:** App modified after signing, missing framework signatures

**Solution:**
```bash
# Verify with detailed output
codesign --verify --deep --strict --verbose=4 App.app

# Re-sign with deep flag
codesign --force --deep --options runtime --timestamp --sign "Developer ID Application: ..." App.app
```

**Important:** Never modify the app (including Info.plist) after signing.

## 5. Build Number Not Increasing

**Issue:** Sparkle doesn't offer update to users

**Cause:** `CFBundleVersion` (BUILD_NUMBER) not strictly greater than previous

**Solution:**
```bash
# Check previous release build number
defaults read OptimusClip.app/Contents/Info.plist CFBundleVersion

# Ensure new BUILD_NUMBER in version.env is higher
# Example: 5 → 6 (not 5 → 5)
```

**Rule:** Sparkle compares `CFBundleVersion` as integer, ignores `CFBundleShortVersionString`.

## 6. Gatekeeper Rejection

**Issue:** "Cannot be opened because developer cannot be verified"

**Cause:** Not notarized, ticket not stapled, or signature invalid

**Solution:**
```bash
# Check notarization status
spctl -a -t exec -vv App.app
# Should show: "source=Notarized Developer ID"

# If not notarized, submit:
xcrun notarytool submit App.zip --key-id ... --issuer ... --key ... --wait

# Staple the ticket:
xcrun stapler staple App.app
xcrun stapler validate App.app
```

## 7. Hardened Runtime Crashes

**Issue:** App crashes on launch after signing

**Cause:** Hardened runtime blocks certain APIs without entitlements

**Solution:**
```bash
# Check crash log for "code signature invalid" or "Library not loaded"

# Create entitlements.plist if needed:
cat > entitlements.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
EOF

# Sign with entitlements
codesign --force --deep --options runtime --timestamp --entitlements entitlements.plist --sign "Developer ID Application: ..." App.app
```

## 8. Notarization Timeout

**Issue:** `notarytool submit --wait` times out

**Cause:** Apple servers overloaded or large file

**Solution:**
```bash
# Submit without waiting
xcrun notarytool submit App.zip --key-id ... --issuer ... --key ...
# Note the submission ID

# Check status manually
xcrun notarytool info SUBMISSION_ID --key-id ... --issuer ... --key ...

# When status is "Accepted", staple:
xcrun stapler staple App.app
```

## 9. CDN Propagation Delay

**Issue:** `check-release-assets.sh` reports 404 immediately after upload

**Cause:** GitHub CDN takes 30-60 seconds to propagate new assets

**Solution:** The script has built-in retry logic. Wait and it will resolve.

If manually checking:
```bash
# Wait 60 seconds after gh release create
sleep 60
curl -I https://github.com/.../releases/download/v1.0.0/OptimusClip.zip
```

## 10. Certificate Expired

**Issue:** `codesign` fails with "certificate trust settings"

**Cause:** Developer ID certificate expired (5-year validity)

**Solution:**
1. Go to [developer.apple.com](https://developer.apple.com)
2. Certificates, Identifiers & Profiles → Certificates
3. Create new Developer ID Application certificate
4. Download and install in Keychain
5. Update `DEVELOPER_ID_APP_IDENTITY` environment variable

## 11. API Key Invalid

**Issue:** `notarytool` fails with "invalid credentials"

**Cause:** App Store Connect API key revoked or wrong key ID

**Solution:**
1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Users and Access → Keys
3. Verify key is active, get correct Key ID and Issuer ID
4. Re-download .p8 file (only available once!)
5. Update environment variables

## 12. GitHub CLI Not Authenticated

**Issue:** `gh release create` fails with "authentication required"

**Solution:**
```bash
gh auth login
# Follow prompts, choose HTTPS, authenticate via browser
gh auth status  # Verify logged in
```

## Recovery Procedures

### Delete a Bad Release

```bash
# Delete GitHub release
gh release delete v1.0.0 --yes

# Delete local and remote tag
git tag -d v1.0.0
git push origin :refs/tags/v1.0.0

# Revert appcast.xml commit if needed
git revert HEAD

# Fix the issue, then re-run release
./Scripts/release.sh
```

### Re-upload Assets

```bash
# Upload replacement asset
gh release upload v1.0.0 OptimusClip-1.0.0-notarized.zip --clobber
```
