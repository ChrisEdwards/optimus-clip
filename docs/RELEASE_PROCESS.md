# Release Process

Step-by-step guide to releasing a new version of OptimusClip.

## Release Modes

| Mode | Command | Apple Developer Required | Gatekeeper | Auto-Updates |
|------|---------|-------------------------|------------|--------------|
| **Signed** | `./Scripts/release.sh` | Yes ($99/year) | No warnings | Works |
| **Unsigned** | `./Scripts/release.sh --unsigned` | No | Warning (bypass with right-click) | No |
| **Dry Run** | `./Scripts/release.sh --dry-run` | No | N/A | N/A |

## Prerequisites

Before your first release, complete the setup in [RELEASE_PREREQUISITES.md](./RELEASE_PREREQUISITES.md).

## Release Steps

### Step 1: Update Version

Edit `version.env`:

```bash
MARKETING_VERSION="1.0.1"  # Bump appropriately (major.minor.patch)
BUILD_NUMBER="6"           # Must be strictly greater than previous release
```

**Version Bumping Rules:**
- Patch (1.0.0 → 1.0.1): Bug fixes, minor improvements
- Minor (1.0.0 → 1.1.0): New features, backwards compatible
- Major (1.0.0 → 2.0.0): Breaking changes

**Important:** Sparkle compares `BUILD_NUMBER`, not `MARKETING_VERSION`. Always increment `BUILD_NUMBER`.

### Step 2: Update CHANGELOG

Edit `CHANGELOG.md`:

```markdown
## [1.0.1] - 2024-02-10

### Fixed
- Fixed clipboard crash when content contains image data
- Fixed memory leak in transformation queue

### Changed
- Improved LLM response handling
```

Follow [Keep a Changelog](https://keepachangelog.com) format.

### Step 3: Commit Version Changes

```bash
git add version.env CHANGELOG.md
git commit -m "chore: bump version to 1.0.1"
```

**Do NOT create a tag** - the release script handles tagging.

### Step 4: Run Release Script

```bash
./Scripts/release.sh
```

The script will:
1. Run pre-flight checks (clean repo, version bumped)
2. Run lint and tests
3. Build release binary
4. Sign with Developer ID certificate
5. Submit to Apple for notarization (~10-15 min wait)
6. Staple notarization ticket
7. Generate Sparkle signature
8. Update appcast.xml
9. Create GitHub release with assets
10. Verify release assets
11. Tag and push

**Duration:** 15-25 minutes (mostly notarization wait time)

### Step 5: Verify Release

After the script completes:

1. **Check GitHub Release:**
   - Visit: `https://github.com/ChrisEdwards/optimus-clip/releases/tag/v1.0.1`
   - Verify both `.zip` and `.dSYM.zip` assets are present

2. **Test Download:**
   ```bash
   curl -LO https://github.com/.../OptimusClip-1.0.1-notarized.zip
   ditto -x -k OptimusClip-1.0.1-notarized.zip .
   open OptimusClip.app  # Should open without warnings
   ```

3. **Verify Appcast:**
   ```bash
   curl https://raw.githubusercontent.com/ChrisEdwards/optimus-clip/main/appcast.xml
   # Check new version entry is present
   ```

4. **Test on Clean Mac (if possible):**
   - Download and run on Mac without developer tools
   - Verify no Gatekeeper warnings

### Step 6: Announce (Optional)

- Post release notes to users
- Update website
- Notify beta testers

## Unsigned Release Mode

To release without an Apple Developer account:

```bash
./Scripts/release.sh --unsigned
```

This creates a fully functional release but:
- Users see Gatekeeper warning on first launch
- Users must right-click → Open → click "Open" to bypass
- Sparkle auto-updates will NOT work (requires Developer ID signature)

**Only requires:**
```bash
export SPARKLE_PRIVATE_KEY_FILE="/path/to/sparkle-private-key"
```

Good for:
- Early development releases
- Technical users comfortable with Gatekeeper bypass
- Testing the release process before getting Apple Developer account

## Dry Run Mode

To test the release process without uploading:

```bash
./Scripts/release.sh --dry-run
```

This simulates all steps but skips:
- Signing and notarization
- GitHub release creation
- Git tagging and pushing

## Troubleshooting

See [RELEASE_GOTCHAS.md](./RELEASE_GOTCHAS.md) for common issues and solutions.

## Environment Variables

**For unsigned releases** (no Apple account):
```bash
export SPARKLE_PRIVATE_KEY_FILE="/path/to/sparkle-private-key"
```

**For signed releases** (requires Apple Developer account):
```bash
export APP_STORE_CONNECT_KEY_ID="..."
export APP_STORE_CONNECT_ISSUER_ID="..."
export APP_STORE_CONNECT_API_KEY_P8="..."  # Base64-encoded .p8 file
export DEVELOPER_ID_APP_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export SPARKLE_PRIVATE_KEY_FILE="/path/to/sparkle-private-key"
```

### Backing Up Sparkle Private Key

The Sparkle private key is stored in your macOS Keychain. To export for backup:

```bash
# Export to file (run in terminal, not in shared environment)
.build/artifacts/sparkle/Sparkle/bin/generate_keys -x > ~/Desktop/sparkle-private-key.txt

# Store in secure location (1Password, encrypted drive, etc.)
# Then delete the plaintext file
rm ~/Desktop/sparkle-private-key.txt
```

See [RELEASE_PREREQUISITES.md](./RELEASE_PREREQUISITES.md) for full setup instructions.
