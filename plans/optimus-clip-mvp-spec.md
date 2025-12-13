Here is the comprehensive Product Specification for the MVP of **Optimus Clip**.

This document outlines the architecture, feature set, and technical requirements needed to build the application based on our discussion.

---

# Product Specification: Optimus Clip (MVP)

- **Version:** 1.0 (MVP)
- **Platform:** macOS
- **Target Audience:** Developers & Power Users (specifically those using CLI tools like Claude Code, Codex CLI, etc.)

## 1. Executive Summary
Optimus Clip is a macOS menu bar application designed to act as an intelligent "clipboard middleware." It solves the problem of copying text from terminal interfaces (CLI) that is often plagued by hard-wrapping (newlines at the end of every visual line) and decorative whitespace (indentation).

Unlike standard clipboard managers, Optimus Clip allows users to define **Transformations**—custom actions triggered by global hotkeys that process clipboard content through either algorithmic rules or Large Language Models (LLMs) before pasting.

---

## 2. Core Features (MVP)

### A. The "Toolbar" (Menu Bar) Interface
* **Status Item:** The app runs in the macOS Menu Bar (top right near the clock).
* **Icon:** SF Symbol (e.g., `clipboard.fill` or custom).
* **States:**
    * *Idle:* Standard appearance, full opacity.
    * *Disabled:* Dimmed (opacity ~0.45) when transformations are disabled.
    * *Processing:* Pulse animation via `.symbolEffect(.pulse)` triggered by state ID increment.
* **Menu Items:**
    * `Settings/Preferences`: Opens the main configuration window (Cmd+,).
    * `Quit`: Exits the application.
* **Implementation:** Use `MenuBarExtra` with `MenuBarExtraAccess` for `NSStatusItem` access.

### B. Global Hotkey Management
* **Customizable Hotkeys:** Users can map specific keyboard shortcuts (e.g., `Cmd+Shift+V`, `Cmd+Option+L`) to specific Transformations.
* **Standard Passthrough:** If a hotkey isn't pressed, standard copy/paste behavior remains untouched.
* **Implementation:** Use `KeyboardShortcuts` package (sindresorhus):
    * Define `KeyboardShortcuts.Name` extensions for each transformation.
    * Use `KeyboardShortcuts.Recorder` SwiftUI component for recording.
    * Register handlers via `KeyboardShortcuts.onKeyUp(for:)`.
    * Enable/disable individual hotkeys via `KeyboardShortcuts.enable/disable`.

### C. Transformation Engine (The Core Logic)
The app must support two types of processing pipelines:

#### 1. "Quick Fix" (Local/Algorithmic)
* **Goal:** Instant cleanup without API latency.
* **Logic:**
    * **Strip Leading Whitespace:** Detects and removes the common 2-space indentation found in CLI outputs.
    * **Unwrap Lines (Heuristic):** Detects "hard wraps" based on line length consistency. If 3+ consecutive lines are within ~5 characters of the same length, treat them as wrapped paragraph text and join them.
* **Safety:** Does not modify indentation if the text appears to be code (detects braces `{}` or indentation hierarchies).

#### 2. "Intelligent Fix" (LLM-Based)
* **Goal:** Context-aware formatting (e.g., "Format as Jira Ticket", "Clean up Slack thread").
* **Configuration:** Users can create named Presets (e.g., "Fix Code", "Make Jira").
* **Inputs:**
    * **System Prompt:** A user-editable text field (e.g., *"You are a text cleaner. Remove line breaks and format as Markdown..."*).
    * **Model Selection:** Dropdown to choose which backend to use for this specific preset.

### D. LLM Provider Integration
The MVP must support the following providers:
1.  **OpenAI:**
    * Auth: API Key stored in macOS Keychain.
    * Models: GPT-4o, GPT-4o-mini, etc.
2.  **Anthropic:**
    * Auth: API Key stored in macOS Keychain.
    * Models: Claude Sonnet, Haiku, Opus.
3.  **OpenRouter:**
    * Auth: API Key stored in macOS Keychain.
    * Models: Fetch available models dynamically.
4.  **Ollama (Local):**
    * Connects to `localhost:11434` (configurable).
    * Fetches list of available local models (e.g., Llama 3, Mistral).
5.  **AWS Bedrock (Cloud):**
    * Authentication via standard AWS credentials profile (`~/.aws/credentials`) or input keys.
    * Region selection (e.g., `us-east-1`).
    * Model selection (e.g., Claude 3 Haiku/Sonnet).

### E. Clipboard Guardrails
* **Binary Safety:** Before processing, check clipboard data type.
    * If `Image` or `File`: **Do nothing** (or pass through raw). Do not attempt to send binary data to a text LLM to prevent crashes.
    * If `Text/Rich Text`: Proceed with transformation.

### F. History Data Storage
* **Log Database:** Store metadata for the last 100 operations locally (SQLite or SwiftData).
* **Data Points:** Timestamp, Transformation Name, Provider, Model Used, System Prompt, Original Text, Processed Text, Input Character Count, Processing Time (ms).
* **History UI:** Deferred to post-MVP. Data stored for future use.

---

## 3. Technical Implementation Plan

### Tech Stack
* **Language:** Swift 5+ (macOS 15+)
* **Frameworks:**
    * `AppKit` for Menu Bar management via `MenuBarExtra`.
    * `SwiftUI` for Settings and Permissions windows.
* **Dependencies (Swift Package Manager):**
    | Package | Purpose |
    |---------|---------|
    | `KeyboardShortcuts` (sindresorhus) | Global hotkey recording and handling |
    | `MenuBarExtraAccess` (orchetect) | Access NSStatusItem from SwiftUI |
    | `LLMChatOpenAI` (kevinhermawan) | OpenAI, OpenRouter, Ollama APIs |
    | `LLMChatAnthropic` (kevinhermawan) | Anthropic Claude API |
    | `AWS SDK for Swift` | AWS Bedrock |
* **Database:** SwiftData for History/Analytics.
* **Concurrency:** Swift `async/await` for non-blocking LLM calls.
* **Security:** macOS Keychain for API key storage.
* **Settings:** `@AppStorage` (UserDefaults) for preferences.
* **Permissions:** Accessibility permission required for global hotkeys and paste simulation.

### Architecture Diagram

1.  **Listener:** Application launches -> Registers Global Hotkeys via `KeyboardShortcuts`.
2.  **Trigger:** User hits `Cmd+Opt+V` -> App reads System Clipboard.
3.  **Router:** App determines which Transformation is mapped to `Cmd+Opt+V`.
4.  **Processor:**
    * *If Local:* Run Regex/String manipulation.
    * *If LLM:* Construct payload -> HTTP POST to provider -> Await response.
5.  **Output (Success):** App writes processed result to System Clipboard (with marker) -> Simulates `Cmd+V` via `CGEvent`.
6.  **Output (Failure):** Clipboard remains unchanged -> No paste action -> User notified via beep/icon flash.

### Implementation Patterns (from Trimmy reference)

#### Clipboard Monitoring
```
Poll Interval: 150ms (DispatchSourceTimer)
Leeway: 50ms (power efficiency)
Grace Delay: 80ms (wait for promised data)
Change Detection: NSPasteboard.general.changeCount
```

#### Self-Write Marker (Critical)
To prevent reprocessing own clipboard writes:
```swift
let marker = NSPasteboard.PasteboardType("com.optimusclip.marker")

// When writing:
pasteboard.declareTypes([.string, marker], owner: nil)
pasteboard.setString(text, forType: .string)
pasteboard.setData(Data(), forType: marker)

// When reading:
if pasteboard.types?.contains(marker) == true { return nil }
```

#### Paste Simulation
```swift
import Carbon.HIToolbox

func sendPasteCommand() {
    guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
    let keyCode = CGKeyCode(kVK_ANSI_V)

    let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
    down?.flags = .maskCommand
    down?.post(tap: .cghidEventTap)

    let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
    up?.flags = .maskCommand
    up?.post(tap: .cghidEventTap)
}
```

#### Accessibility Permission
```swift
import ApplicationServices

// Check
let trusted = AXIsProcessTrusted()

// Request with prompt
let options: NSDictionary = ["AXTrustedCheckOptionPrompt": true]
AXIsProcessTrustedWithOptions(options)

// Open Settings directly
let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
NSWorkspace.shared.open(url)
```

#### App Configuration (Info.plist)
```xml
<key>LSUIElement</key><true/>  <!-- No Dock icon -->
<key>LSMultipleInstancesProhibited</key><true/>
<key>LSMinimumSystemVersion</key><string>15.0</string>
```

#### Launch at Login
```swift
import ServiceManagement

// Enable
try? SMAppService.mainApp.register()

// Disable
try? SMAppService.mainApp.unregister()
```

---

## 4. UI/UX Wireframes

### Settings Window
Use SwiftUI `TabView` with fixed dimensions (e.g., 450×500).

* **Transformations Tab:**
    * Sidebar: List of Transformations (e.g., "Default Clean", "Jira Format").
    * Main Pane (Transformation Editor):
        * Name (Input)
        * Hotkey Recorder (`KeyboardShortcuts.Recorder` component)
        * Enable/Disable toggle for this hotkey
        * Type (Dropdown: Local Algorithm vs. LLM)
        * **If LLM selected:**
            * Provider (Dropdown: OpenAI / Anthropic / OpenRouter / Ollama / AWS Bedrock)
            * Model (Dropdown: populated based on provider)
            * System Prompt (Multi-line Text Area)
* **Providers Tab:**
    * OpenAI Configuration (API Key - SecureField)
    * Anthropic Configuration (API Key - SecureField)
    * OpenRouter Configuration (API Key - SecureField)
    * Ollama Configuration (Host/Port, Test Connection button)
    * AWS Bedrock Configuration (Profile/Region or Access Keys)
* **General Tab:**
    * Launch at Login toggle
* **Permissions Tab:**
    * **Accessibility Callout** (when not granted):
        * Yellow warning icon (`exclamationmark.triangle.fill`)
        * Explanation text
        * "Grant Accessibility" button (`.borderedProminent`)
        * "Open Settings" button (`.bordered`)
    * Status indicator (green checkmark when granted)
    * Auto-refreshes via 2-second polling

### History Window (Post-MVP)
* Deferred to future release. Data stored but UI not built for MVP.

---

## 5. Development Phases

### Phase 0: Project Scaffolding & Agent Configuration
*Goal: Set up repository structure, tooling, and AI assistant configuration before writing application code. Structure the project to be "release-ready" from day one.*

#### Bundle Identifier & Versioning Strategy
* **Bundle ID:** `com.<yourname>.optimusclip` (lowercase, no spaces)
* **Version Source of Truth:** `version.env` file at repository root
* **Versioning Scheme:**
  * `MARKETING_VERSION`: Semantic versioning (e.g., `0.1.0`, `1.0.0`)
  * `BUILD_NUMBER`: Monotonically increasing integer (Sparkle compares this)

#### Repository Structure
```
optimus-clip/
├── CLAUDE.md                    # AI assistant guidelines
├── Package.swift                # SPM manifest with dependencies
├── package.json                 # npm scripts for unified CLI
├── version.env                  # Single source of truth for version/build
├── .swiftformat                 # SwiftFormat config (Swift 6)
├── .swiftlint.yml               # SwiftLint config
├── .gitignore                   # Standard Swift/Xcode ignores
├── Info.plist                   # App configuration template
├── Info.debug.plist             # Debug-specific overrides (optional)
├── Sources/
│   ├── OptimusClip/             # Main app target
│   │   └── OptimusClipApp.swift # Entry point (placeholder)
│   └── OptimusClipCore/         # Shared logic (transformations)
│       └── Transformation.swift # Protocol definition (placeholder)
├── Tests/
│   └── OptimusClipTests/
│       └── TransformationTests.swift # Placeholder test
├── Scripts/
│   ├── compile_and_run.sh       # Dev workflow script
│   ├── package_app.sh           # Build .app bundle (reads version.env)
│   └── kill_optimusclip.sh      # Stop running instances
└── .github/
    └── workflows/
        └── ci.yml               # GitHub Actions CI
```

#### Files to Create

**version.env** — Single source of truth for versioning:
```bash
# Version configuration - edit this file for releases
MARKETING_VERSION="0.1.0"
BUILD_NUMBER="1"
```
*Note: Build number must monotonically increase for Sparkle updates to work correctly.*

**CLAUDE.md** — AI assistant directives:
* Project structure overview
* Build commands (`pnpm start`, `pnpm check`, `pnpm test`)
* Code style (Swift 6, 4-space indent, 120 char lines, explicit `self`)
* Testing expectations (Swift Testing framework)
* Commit/PR guidelines
* Safety guards (no releases without explicit request)
* Bundle ID: `com.<yourname>.optimusclip`

**package.json** — Unified CLI interface:
```json
{
  "name": "optimus-clip",
  "private": true,
  "scripts": {
    "start": "./Scripts/compile_and_run.sh",
    "build": "swift build",
    "build:release": "swift build -c release",
    "test": "swift test",
    "format": "swiftformat .",
    "lint": "swiftlint lint --fix",
    "check": "swiftformat . --lint && swiftlint lint",
    "package": "./Scripts/package_app.sh debug",
    "package:release": "./Scripts/package_app.sh release",
    "stop": "./Scripts/kill_optimusclip.sh || true"
  }
}
```

**Info.plist** — App configuration (template, populated by package_app.sh):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Bundle Identity -->
    <key>CFBundleIdentifier</key>
    <string>com.yourname.optimusclip</string>
    <key>CFBundleName</key>
    <string>OptimusClip</string>
    <key>CFBundleDisplayName</key>
    <string>Optimus Clip</string>
    <key>CFBundleExecutable</key>
    <string>OptimusClip</string>

    <!-- Version (populated from version.env by package_app.sh) -->
    <key>CFBundleShortVersionString</key>
    <string>$(MARKETING_VERSION)</string>
    <key>CFBundleVersion</key>
    <string>$(BUILD_NUMBER)</string>

    <!-- Menu Bar App Configuration -->
    <key>LSUIElement</key>
    <true/>
    <key>LSMultipleInstancesProhibited</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>

    <!-- App Category -->
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>

    <!-- Sparkle (added in Phase 7) -->
    <!-- <key>SUFeedURL</key> -->
    <!-- <string>https://raw.githubusercontent.com/yourname/optimus-clip/main/appcast.xml</string> -->
    <!-- <key>SUPublicEDKey</key> -->
    <!-- <string>YOUR_PUBLIC_KEY_HERE</string> -->
</dict>
</plist>
```

**.swiftformat** — Code formatting (copy from Trimmy):
* `--self insert` (required for Swift 6 concurrency)
* `--indent 4`
* `--maxwidth 120`
* `--wraparguments before-first`
* `--swiftversion 6.0`

**.swiftlint.yml** — Linting rules (copy from Trimmy):
* Analyzer rules: `unused_declaration`, `unused_import`
* `force_cast: warning`, `force_try: warning`
* `file_length: warning 1500`
* `line_length: warning 120`

**Package.swift** — Dependencies:
```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OptimusClip",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "OptimusClip", targets: ["OptimusClip"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/orchetect/MenuBarExtraAccess", from: "1.0.0"),
        // Sparkle added in Phase 7:
        // .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.0"),
    ],
    targets: [
        .executableTarget(
            name: "OptimusClip",
            dependencies: [
                "OptimusClipCore",
                "KeyboardShortcuts",
                "MenuBarExtraAccess",
                // .product(name: "Sparkle", package: "Sparkle"),  // Phase 7
            ]
        ),
        .target(name: "OptimusClipCore"),
        .testTarget(name: "OptimusClipTests", dependencies: ["OptimusClipCore"])
    ]
)
```

**Scripts/package_app.sh** — Build .app bundle:
```bash
#!/usr/bin/env bash
# Package OptimusClip.app from SwiftPM build
# Usage: ./Scripts/package_app.sh [debug|release]

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
    "${ROOT_DIR}/Info.plist" > "${CONTENTS}/Info.plist"

# Copy icon if exists
[[ -f "${ROOT_DIR}/Icon.icns" ]] && cp "${ROOT_DIR}/Icon.icns" "${RESOURCES}/AppIcon.icns"

echo "Packaged ${APP_BUNDLE} (${MODE}, v${MARKETING_VERSION} build ${BUILD_NUMBER})"
```

**Scripts/compile_and_run.sh** — Dev workflow:
* Kill existing instances
* `swift build -q`
* `swift test -q`
* Run `package_app.sh debug`
* Launch and verify running

**.github/workflows/ci.yml** — CI pipeline:
* `swiftformat Sources Tests --lint`
* `swiftlint --strict`
* `swift build`
* `swift test --parallel`

#### Verification
* [ ] `swift build` succeeds
* [ ] `swift test` passes (placeholder test)
* [ ] `pnpm check` runs format and lint without errors
* [ ] `pnpm start` builds and launches (even if app does nothing yet)
* [ ] `pnpm package` creates `OptimusClip.app` with correct version in Info.plist
* [ ] CI workflow passes on push

**Milestone:** Repository scaffolded with working toolchain; `pnpm start` launches a minimal app; version management via `version.env`; CI green.

---

### Phase 1: Menu Bar Shell
*Builds on Phase 0 scaffolding.*

* Configure `Info.plist` (`LSUIElement`, `LSMultipleInstancesProhibited`).
* Implement `@main App` with `MenuBarExtra`.
* Add `NSApplicationDelegateAdaptor` with `.accessory` activation policy.
* Create status icon with SF Symbol (`clipboard.fill`).
* Add basic menu items (Settings placeholder, Quit).
* Ensure single-instance enforcement.
* **Milestone:** App appears in menu bar with icon, no Dock presence, `pnpm start` workflow functional.

### Phase 2: Clipboard & Paste
* Implement `ClipboardMonitor` with `DispatchSourceTimer` polling.
* Add self-write marker pasteboard type.
* Implement grace delay for promised data.
* Implement `CGEvent`-based paste simulation.
* Add `AccessibilityPermissionManager` with polling.
* **Milestone:** Can read clipboard, transform, write back, and paste.

### Phase 3: Hotkeys & Settings
* Add `KeyboardShortcuts` dependency.
* Define hotkey names and default shortcuts.
* Implement `HotkeyManager` for registration.
* Build `SettingsView` with TabView (Transformations, Providers, General, Permissions).
* Implement `KeyboardShortcuts.Recorder` for hotkey configuration.
* Add `AccessibilityPermissionCallout` UI component.
* Use `@AppStorage` for settings persistence.
* **Milestone:** Press custom hotkey to trigger transformation and paste.

### Phase 4: Transformation Engine
* Create `TransformationCore` module.
* Implement algorithmic transformations (whitespace strip, unwrap).
* Build transformation pipeline architecture.
* Wire hotkeys to specific transformations.
* **Milestone:** Algorithmic "Quick Fix" transformations working.

### Phase 5: LLM Integration
* Integrate `LLMChatOpenAI` for OpenAI/OpenRouter/Ollama.
* Integrate `LLMChatAnthropic` for Anthropic.
* Integrate AWS SDK for Bedrock.
* Add model fetching for dynamic lists.
* Implement async transformation with timeout.
* Add processing animation (pulse effect on icon).
* **Milestone:** LLM-based transformations working with all providers.

### Phase 6: Data & Security
* Implement SwiftData models for history logging.
* Integrate macOS Keychain for API key storage.
* Add launch-at-login via `SMAppService`.
* Add binary/image safety checks.
* **Milestone:** Complete, secure, production-ready app.

---

### Phase 7: Release Infrastructure (Post-MVP)
*Goal: Set up Sparkle auto-updates, code signing, notarization, and release automation for public distribution.*

#### Prerequisites
Before starting Phase 7, you need:
1. **Apple Developer Program membership** ($99/year)
2. **Developer ID Application certificate** installed in Keychain
3. **App Store Connect API credentials:**
   * `APP_STORE_CONNECT_API_KEY_P8` (base64-encoded .p8 key)
   * `APP_STORE_CONNECT_KEY_ID`
   * `APP_STORE_CONNECT_ISSUER_ID`
4. **Sparkle signing key pair** (ed25519)

#### 7.1 Sparkle Integration

**Add Sparkle dependency to Package.swift:**
```swift
dependencies: [
    // ... existing dependencies
    .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.0"),
],
targets: [
    .executableTarget(
        name: "OptimusClip",
        dependencies: [
            // ... existing dependencies
            .product(name: "Sparkle", package: "Sparkle"),
        ]
    ),
]
```

**Create UpdaterWrapper (only enables for signed builds):**
```swift
import Foundation
import Sparkle

/// Wrapper that conditionally enables Sparkle only for signed, bundled builds.
/// Prevents update dialogs during development.
@MainActor
final class UpdaterWrapper: ObservableObject {
    private var controller: SPUStandardUpdaterController?

    var updater: SPUUpdater? { controller?.updater }
    var canCheckForUpdates: Bool { controller != nil }

    init() {
        guard shouldEnableUpdater() else { return }
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    private func shouldEnableUpdater() -> Bool {
        let bundle = Bundle.main
        guard bundle.bundleURL.pathExtension == "app" else { return false }
        return isSignedWithDeveloperID(bundle.bundleURL)
    }

    private func isSignedWithDeveloperID(_ url: URL) -> Bool {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess,
              let code = code else { return false }
        let requirement = "anchor apple generic and certificate leaf[subject.OU] = \"YOUR_TEAM_ID\""
        var req: SecRequirement?
        guard SecRequirementCreateWithString(requirement as CFString, [], &req) == errSecSuccess,
              let req = req else { return false }
        return SecStaticCodeCheckValidity(code, [], req) == errSecSuccess
    }
}
```

**Update Info.plist with Sparkle keys:**
```xml
<!-- Sparkle Configuration -->
<key>SUFeedURL</key>
<string>https://raw.githubusercontent.com/yourname/optimus-clip/main/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>YOUR_SPARKLE_PUBLIC_KEY</string>
<key>SUEnableInstallerLauncherService</key>
<true/>
```

**Create initial appcast.xml:**
```xml
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
    <channel>
        <title>Optimus Clip</title>
        <!-- Items added by release script -->
    </channel>
</rss>
```

#### 7.2 Signing & Notarization Scripts

**Scripts/sign-and-notarize.sh:**
```bash
#!/usr/bin/env bash
# Sign and notarize OptimusClip for distribution
# Requires: Developer ID cert, ASC API credentials, Sparkle key

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/version.env"

APP_NAME="OptimusClip"
APP_BUNDLE="${ROOT_DIR}/${APP_NAME}.app"
ZIP_NAME="${APP_NAME}-${MARKETING_VERSION}.zip"
DSYM_ZIP="${APP_NAME}-${MARKETING_VERSION}.dSYM.zip"

# Signing identity (adjust to your certificate)
IDENTITY="Developer ID Application: Your Name (TEAM_ID)"

# 1) Build release
swift build -c release

# 2) Package app
"${ROOT_DIR}/Scripts/package_app.sh" release

# 3) Embed Sparkle framework (if using)
# ... (copy Sparkle.framework into app bundle, sign it)

# 4) Sign everything with hardened runtime
codesign --force --deep --options runtime --timestamp \
    --sign "${IDENTITY}" "${APP_BUNDLE}"

# 5) Verify signature
codesign --verify --deep --strict --verbose "${APP_BUNDLE}"

# 6) Create zip for notarization (use ditto to avoid AppleDouble files)
xattr -cr "${APP_BUNDLE}"
find "${APP_BUNDLE}" -name '._*' -delete
ditto -c -k --keepParent --rsrc "${APP_BUNDLE}" "${ZIP_NAME}"

# 7) Submit for notarization
xcrun notarytool submit "${ZIP_NAME}" \
    --key "${APP_STORE_CONNECT_API_KEY_P8}" \
    --key-id "${APP_STORE_CONNECT_KEY_ID}" \
    --issuer "${APP_STORE_CONNECT_ISSUER_ID}" \
    --wait

# 8) Staple the notarization ticket
xcrun stapler staple "${APP_BUNDLE}"

# 9) Verify stapling
xcrun stapler validate "${APP_BUNDLE}"
spctl -a -t exec -vv "${APP_BUNDLE}"

# 10) Re-zip the stapled app
rm "${ZIP_NAME}"
ditto -c -k --keepParent --rsrc "${APP_BUNDLE}" "${ZIP_NAME}"

# 11) Create dSYM archive for crash symbolication
DSYM_PATH="${ROOT_DIR}/.build/release/${APP_NAME}.dSYM"
if [[ -d "${DSYM_PATH}" ]]; then
    ditto -c -k --keepParent "${DSYM_PATH}" "${DSYM_ZIP}"
fi

echo "✅ Signed and notarized: ${ZIP_NAME}"
```

**Scripts/release.sh:**
```bash
#!/usr/bin/env bash
# Full release workflow: lint, test, sign, notarize, update appcast, create GH release

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/version.env"

# 1) Pre-flight checks
[[ -z "$(git status --porcelain)" ]] || { echo "ERROR: Working tree not clean"; exit 1; }
[[ -n "${SPARKLE_PRIVATE_KEY_FILE:-}" ]] || { echo "ERROR: SPARKLE_PRIVATE_KEY_FILE not set"; exit 1; }

# 2) Lint and test
pnpm check
swift test

# 3) Sign and notarize
"${ROOT_DIR}/Scripts/sign-and-notarize.sh"

# 4) Generate Sparkle signature
ZIP_NAME="OptimusClip-${MARKETING_VERSION}.zip"
SIGNATURE=$(sign_update "${ZIP_NAME}" -f "${SPARKLE_PRIVATE_KEY_FILE}")
LENGTH=$(stat -f%z "${ZIP_NAME}")

# 5) Update appcast.xml (insert new item)
# ... (XML manipulation to add new <item> with version, signature, length, URL)

# 6) Create GitHub release
gh release create "v${MARKETING_VERSION}" \
    "${ZIP_NAME}" \
    "OptimusClip-${MARKETING_VERSION}.dSYM.zip" \
    --title "Optimus Clip ${MARKETING_VERSION}" \
    --notes-file <(grep -A 50 "## ${MARKETING_VERSION}" CHANGELOG.md | tail -n +2 | head -n 20)

# 7) Verify release assets
"${ROOT_DIR}/Scripts/check-release-assets.sh" "v${MARKETING_VERSION}"

# 8) Tag and push
git add appcast.xml CHANGELOG.md version.env
git commit -m "Release v${MARKETING_VERSION}"
git tag "v${MARKETING_VERSION}"
git push origin main --tags

echo "✅ Released v${MARKETING_VERSION}"
```

**Scripts/check-release-assets.sh:**
```bash
#!/usr/bin/env bash
# Verify GitHub release has all required assets

set -euo pipefail

TAG="${1:?Usage: check-release-assets.sh <tag>}"
REPO="${GITHUB_REPOSITORY:-yourname/optimus-clip}"

echo "Checking release assets for ${TAG}..."

# Check zip exists and is downloadable
ZIP_URL="https://github.com/${REPO}/releases/download/${TAG}/OptimusClip-${TAG#v}.zip"
curl -fsSL -o /dev/null "${ZIP_URL}" || { echo "ERROR: ZIP not found at ${ZIP_URL}"; exit 1; }

# Check dSYM exists
DSYM_URL="https://github.com/${REPO}/releases/download/${TAG}/OptimusClip-${TAG#v}.dSYM.zip"
curl -fsSL -o /dev/null "${DSYM_URL}" || { echo "WARNING: dSYM not found at ${DSYM_URL}"; }

echo "✅ Release assets verified"
```

#### 7.3 Environment Variables

Add to your shell profile or CI secrets:
```bash
# App Store Connect API (for notarization)
export APP_STORE_CONNECT_API_KEY_P8="base64-encoded-p8-key"
export APP_STORE_CONNECT_KEY_ID="YOUR_KEY_ID"
export APP_STORE_CONNECT_ISSUER_ID="YOUR_ISSUER_ID"

# Sparkle signing key (single-line base64, no comments)
export SPARKLE_PRIVATE_KEY_FILE="/path/to/sparkle-ed25519-private-key"
```

#### 7.4 Release Flow

1. **Preparation:**
   * Update `version.env` (bump `MARKETING_VERSION`, increment `BUILD_NUMBER`)
   * Update `CHANGELOG.md` with release notes
   * Commit changes

2. **Release:**
   ```bash
   ./Scripts/release.sh
   ```

3. **Verification:**
   * Check GitHub release page has zip and dSYM
   * Download zip, extract with `ditto -x -k`, verify app launches
   * Verify `spctl -a -t exec -vv OptimusClip.app` passes
   * Test Sparkle update from previous version (if applicable)

#### 7.5 Verification Checklist

* [ ] `codesign --verify --deep --strict` passes
* [ ] `spctl -a -t exec -vv` passes (Gatekeeper approval)
* [ ] `stapler validate` passes (notarization ticket stapled)
* [ ] Appcast entry has correct `sparkle:edSignature` and `length`
* [ ] Enclosure URL returns HTTP 200
* [ ] GitHub release has both `.zip` and `.dSYM.zip`
* [ ] Previous version can update via Sparkle

#### 7.6 Common Gotchas

| Issue | Solution |
|-------|----------|
| **Sparkle key file has comments** | Key must be single-line base64, no comments or blank lines |
| **Bundle ID mismatch** | Must match codesign identity, appcast entry, and Info.plist |
| **AppleDouble files break signature** | Run `xattr -cr` and delete `._*` files before zipping; use `ditto` not `zip` |
| **"App is damaged" error** | Re-sign, re-notarize, re-staple; extract with `ditto -x -k` not `unzip` |
| **Build number not increasing** | Sparkle compares `CFBundleVersion`; must be strictly greater |
| **Update not offered** | Check SUFeedURL matches appcast location; verify signature |

#### 7.7 Files Added in Phase 7

```
optimus-clip/
├── appcast.xml                     # Sparkle update feed
├── Sources/OptimusClip/
│   └── UpdaterWrapper.swift        # Conditional Sparkle enablement
├── Scripts/
│   ├── sign-and-notarize.sh        # Signing and notarization
│   ├── release.sh                  # Full release workflow
│   ├── check-release-assets.sh     # Verify GH release assets
│   └── test_live_update.sh         # Manual update smoke test (optional)
└── CHANGELOG.md                    # Release notes
```

**Milestone:** App can be publicly distributed with code signing, notarization, and automatic updates via Sparkle.

