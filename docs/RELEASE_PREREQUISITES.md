# Release Prerequisites (Phase 7)

Checklist to unblock signing, notarization, and Sparkle updates. Complete **all** items before starting Phase 7 work.

## Quick Checklist
- [ ] Apple Developer Program membership is active (https://developer.apple.com/account/)
- [ ] Developer ID Application certificate installed in Keychain
- [ ] App Store Connect API key (.p8) created, saved, and base64-encoded
- [ ] Key ID and Issuer ID recorded securely
- [ ] Sparkle ed25519 key pair generated; public key available for Info.plist; private key stored securely
- [ ] Environment variables prepared for signing/notarization (no secrets committed)

## 1) Apple Developer Program
- Sign up / verify: https://developer.apple.com/programs/ → Account page shows active membership.
- Tip: Approval can take 24–48 hours; do this first.

## 2) Developer ID Application Certificate
- Type: **Developer ID Application** (not Mac App Distribution).
- Request via Xcode → Settings → Accounts → Manage Certificates, or https://developer.apple.com/account/resources/certificates/.
- Verify installed:
  ```bash
  security find-identity -v -p codesigning | grep "Developer ID Application"
  ```
- Expected: `Developer ID Application: Your Name (TEAMID)`
- Common fixes:
  - If missing, re-download/install from developer portal.
  - If expired, renew and remove old identities to avoid ambiguous matches.
  - Ensure certificate is in the **login** or **System** keychain accessible to the build user.

## 3) App Store Connect API Credentials (for notarytool)
- Create key: App Store Connect → Users and Access → **Keys** → App Store Connect API → **Create Key** (Role: Developer or Admin).
- Download `AuthKey_<KEYID>.p8` **once**; store securely (cannot re-download).
- Record:
  - Key ID (e.g., `AB12CD34EF`)
  - Issuer ID (UUID from the API Keys page)
- Base64 the key for CI/env use:
  ```bash
  base64 -i AuthKey_<KEYID>.p8 | tr -d "\n"
  ```
- Environment variables (example; do not commit):
  - `APP_STORE_CONNECT_KEY_ID`
  - `APP_STORE_CONNECT_ISSUER_ID`
  - `APP_STORE_CONNECT_API_KEY_P8` (single-line base64)

## 4) Sparkle Signing Key Pair (ed25519)
- Generate (either):
  ```bash
  ./Pods/Sparkle/bin/generate_keys    # if Sparkle tools are available
  # or
  openssl genpkey -algorithm ed25519 -out sparkle_private_key.pem
  openssl pkey -in sparkle_private_key.pem -pubout -out sparkle_public_key.pem
  ```
- Convert private key to single-line base64 (required for signing):
  ```bash
  base64 -i sparkle_private_key.pem | tr -d "\n"
  ```
- Store **private key** securely (1Password/Keychain/CI secret). Do not commit.
- Keep **public key** handy for Info.plist/appcast configuration.

## 5) Secure Storage Recommendations
- Never commit `.p8` or private keys.
- Use: 1Password, macOS Keychain, or CI secret manager for:
  - App Store Connect base64 key
  - Sparkle private key
  - Certificate passwords (if any)
- Restrict CI variables to release jobs only.

## 6) Verification Commands (run before release work)
- Developer ID cert present:
  ```bash
  security find-identity -v -p codesigning | grep "Developer ID Application"
  ```
- Notarytool auth sanity check (no submission):
  ```bash
  xcrun notarytool history --key-id "$APP_STORE_CONNECT_KEY_ID" --issuer "$APP_STORE_CONNECT_ISSUER_ID" --key <(echo "$APP_STORE_CONNECT_API_KEY_P8" | base64 -d)
  ```
- Sparkle private key readability (no output means success):
  ```bash
  echo "$SPARKLE_PRIVATE_KEY_B64" | base64 -d > /tmp/sparkle_test.key && rm /tmp/sparkle_test.key
  ```

## 7) Troubleshooting
- **Wrong certificate type**: Recreate as *Developer ID Application*; Mac App Distribution will fail notarization.
- **Certificate not visible to codesign**: Move to login/System keychain and allow codesign access; restart Xcode if cached.
- **API key download lost**: Revoke old key in App Store Connect; create a new one.
- **Sparkle key format errors**: Ensure private key is single-line base64; remove PEM headers/footers before encoding.
- **Keychain prompts in CI**: Use API key auth for notarytool (no interactive prompts); avoid keychain-backed passwords in CI.
