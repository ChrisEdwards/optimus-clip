# Learnings from Trimmy

Trimmy is an open-source macOS menu bar app by Peter Steinberger that watches the clipboard and flattens multi-line shell commands for easier pasting. It shares many architectural patterns with Optimus Clip.

**Repository:** https://github.com/steipete/Trimmy

---

## 1. Architecture & Project Structure

### Swift Package Manager + Xcode Project
Trimmy uses SPM (`Package.swift`) with an Xcode project for building. This hybrid approach allows:
- Clean dependency management via SPM
- Easy `.app` bundle generation via scripts
- Separate targets: `Trimmy` (app), `TrimmyCore` (shared logic), `TrimmyCLI` (command-line tool)

**Recommendation for Optimus Clip:** Consider a similar structure with a `Core` module for transformation logic that can be tested independently and potentially reused in a CLI.

### Key Dependencies
```swift
.package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.1"),
.package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "1.16.0"),
.package(url: "https://github.com/orchetect/MenuBarExtraAccess", exact: "1.2.2"),
```

| Package | Purpose |
|---------|---------|
| **Sparkle** | Auto-update framework (check for updates, download, install) |
| **KeyboardShortcuts** | Global hotkey recording and handling (by Sindre Sorhus) |
| **MenuBarExtraAccess** | Access to `NSStatusItem` from SwiftUI `MenuBarExtra` |

**Recommendation:** Use `KeyboardShortcuts` for hotkey management—it handles the recorder UI component and global hotkey registration elegantly.

---

## 2. Menu Bar App Configuration

### LSUIElement (No Dock Icon)
In `Info.plist`:
```xml
<key>LSUIElement</key>
<true/>
```
This makes the app a "menu bar only" app with no Dock icon.

### LSMultipleInstancesProhibited
```xml
<key>LSMultipleInstancesProhibited</key>
<true/>
```
Prevents multiple instances from running.

### App Activation Policy
In `AppDelegate`:
```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
}
```

---

## 3. Clipboard Monitoring

### Polling Strategy
Trimmy uses a `DispatchSourceTimer` to poll the clipboard:
```swift
private let pollInterval: DispatchTimeInterval = .milliseconds(150)
private let pollLeeway: DispatchTimeInterval = .milliseconds(50)
private let graceDelay: DispatchTimeInterval = .milliseconds(80)
```

- **Poll interval:** 150ms (lightweight, responsive)
- **Leeway:** 50ms (allows system to coalesce timer fires for power efficiency)
- **Grace delay:** 80ms after detecting change (lets "promised" pasteboard data settle)

### Self-Write Marker (Avoid Processing Own Writes)
Critical pattern: Tag clipboard writes with a custom pasteboard type to avoid reprocessing:
```swift
private let trimmyMarker = NSPasteboard.PasteboardType("com.steipete.trimmy")

private func writeTrimmed(_ text: String) {
    pasteboard.declareTypes([.string, trimmyMarker], owner: nil)
    pasteboard.setString(text, forType: .string)
    pasteboard.setData(Data(), forType: trimmyMarker)
}
```

When reading, skip if marker is present:
```swift
if pasteboard.types?.contains(trimmyMarker) == true { return nil }
```

**Critical for Optimus Clip:** Use this pattern to prevent infinite loops when writing transformed text back to clipboard.

### Robust Text Reading
Trimmy has fallback logic for reading text from various pasteboard types:
```swift
let preferredTypes: [NSPasteboard.PasteboardType] = [
    .init("public.utf8-plain-text"),
    .init("public.utf16-external-plain-text"),
    .init("public.text"),
    .init("public.rtf"),
]
```

### Change Count Tracking
Track `pasteboard.changeCount` to detect clipboard changes:
```swift
private var lastSeenChangeCount: Int
// ...
let current = pasteboard.changeCount
guard current != lastSeenChangeCount else { return }
```

---

## 4. Paste Simulation

### Sending Cmd+V Programmatically
```swift
fileprivate static func sendPasteCommand() {
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

Requires `import Carbon.HIToolbox` for `kVK_ANSI_V`.

### Clipboard Restore After Paste
Trimmy temporarily writes transformed text to clipboard, pastes, then restores the original:
```swift
private func performPaste(with text: String) {
    let previousString = clipboardText()

    // Write transformed text
    pasteboard.declareTypes([.string, trimmyMarker], owner: nil)
    pasteboard.setString(text, forType: .string)

    // Send paste command
    pasteIntoFrontmostApp()

    // Restore original after delay
    guard let previousString else { return }
    restorePasteboard(string: previousString)
}

private func restorePasteboard(string: String) {
    DispatchQueue.main.asyncAfter(deadline: .now() + pasteRestoreDelay) { [weak self] in
        // restore...
    }
}
```

**Note:** For Optimus Clip, we decided NOT to restore—we replace the clipboard with transformed text (Option A).

---

## 5. Accessibility Permissions

### Checking Permission Status
```swift
import ApplicationServices

let trusted = AXIsProcessTrusted()
```

### Requesting Permission
```swift
func requestPermissionPrompt() {
    let options: NSDictionary = ["AXTrustedCheckOptionPrompt": true]
    _ = AXIsProcessTrustedWithOptions(options)
    // Also open System Settings for better UX
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
        self?.openSystemSettings()
    }
}
```

### Opening System Settings Directly
```swift
func openSystemSettings() {
    guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    else { return }
    NSWorkspace.shared.open(url)
}
```

### Polling for Permission Changes
Trimmy polls every 2 seconds to detect when user grants permission:
```swift
private func startPolling() {
    pollTask = Task { [weak self] in
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self?.refresh()
        }
    }
}
```

### UI Callout Component
Trimmy shows a prominent callout when permission is missing:
```swift
struct AccessibilityPermissionCallout: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Accessibility needed to paste")
                        .font(.callout.weight(.semibold))
                    Text("Enable Trimmy in System Settings → Privacy & Security → Accessibility...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
            }

            HStack(spacing: 10) {
                Button("Grant Accessibility") { ... }
                    .buttonStyle(.borderedProminent)
                Button("Open Settings") { ... }
                    .buttonStyle(.bordered)
            }
        }
    }
}
```

---

## 6. Global Hotkeys with KeyboardShortcuts

### Define Shortcut Names
```swift
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let pasteTrimmed = Self("trimClipboard")
    static let pasteOriginal = Self("pasteOriginal")
    static let toggleAutoTrim = Self("toggleAutoTrim")
}
```

### Set Default Shortcuts
```swift
private func ensureDefaultShortcut() {
    if KeyboardShortcuts.getShortcut(for: .pasteTrimmed) == nil {
        KeyboardShortcuts.setShortcut(
            .init(.t, modifiers: [.command, .option]),
            for: .pasteTrimmed)
    }
}
```

### Register Handlers
```swift
KeyboardShortcuts.onKeyUp(for: .pasteTrimmed) { [weak self] in
    self?.handlePasteTrimmedHotkey()
}
```

### Enable/Disable Hotkeys
```swift
KeyboardShortcuts.enable(.pasteTrimmed)
KeyboardShortcuts.disable(.pasteTrimmed)
```

### Recorder UI in SwiftUI
```swift
KeyboardShortcuts.Recorder("", name: .pasteTrimmed)
    .labelsHidden()
    .disabled(!settings.pasteTrimmedHotkeyEnabled)
```

---

## 7. Settings with @AppStorage

### Persisting Settings
```swift
@MainActor
public final class AppSettings: ObservableObject {
    @AppStorage("aggressiveness") public var aggressiveness: Aggressiveness = .normal
    @AppStorage("preserveBlankLines") public var preserveBlankLines: Bool = false
    @AppStorage("autoTrimEnabled") public var autoTrimEnabled: Bool = true
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false {
        didSet { LaunchAtLoginManager.setEnabled(launchAtLogin) }
    }
}
```

### Launch at Login (macOS 13+)
```swift
import ServiceManagement

enum LaunchAtLoginManager {
    @MainActor
    static func setEnabled(_ enabled: Bool) {
        guard #available(macOS 13, *) else { return }
        let service = SMAppService.mainApp
        if enabled {
            try? service.register()
        } else {
            try? service.unregister()
        }
    }
}
```

---

## 8. SwiftUI Menu Bar App Structure

### Main App with MenuBarExtra
```swift
@main
@MainActor
struct TrimmyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings()
    @StateObject private var monitor: ClipboardMonitor

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(...)
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        } label: {
            ScissorStatusLabel(monitor: monitor, isEnabled: settings.autoTrimEnabled)
        }
        Settings {
            SettingsView(...)
        }
    }
}
```

### Animated Status Icon
```swift
private struct ScissorStatusLabel: View {
    @ObservedObject var monitor: ClipboardMonitor
    var isEnabled: Bool

    var body: some View {
        Label("Trimmy", systemImage: "scissors")
            .symbolRenderingMode(.hierarchical)
            .symbolEffect(.pulse, options: .repeat(1).speed(1.15), value: monitor.trimPulseID)
            .foregroundStyle(isEnabled ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
            .opacity(isEnabled ? 1.0 : 0.45)
    }
}
```

The `trimPulseID` is incremented each time a transformation occurs, triggering the pulse animation.

---

## 9. Tabbed Settings Window

### Tab Enum with Dimensions
```swift
enum SettingsTab: String, Hashable, CaseIterable, Codable {
    case general, aggressiveness, shortcuts, about

    static let windowWidth: CGFloat = 410
    static let windowHeight: CGFloat = 484
}
```

### Settings Window Structure
```swift
struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsPane(...)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            // ... more tabs
        }
        .frame(width: SettingsTab.windowWidth, height: SettingsTab.windowHeight)
    }
}
```

---

## 10. App Signing & Notarization

### Key Steps from `sign-and-notarize.sh`
1. Build: `swift build -c release --arch arm64`
2. Package: `./Scripts/package_app.sh release`
3. Sign: `codesign --force --deep --options runtime --timestamp --sign "$APP_IDENTITY" "$APP_BUNDLE"`
4. Zip for notarization: `ditto -c -k --keepParent --sequesterRsrc "$APP_BUNDLE" /tmp/Notarize.zip`
5. Submit: `xcrun notarytool submit ... --wait`
6. Staple: `xcrun stapler staple "$APP_BUNDLE"`
7. Verify: `spctl -a -t exec -vv "$APP_BUNDLE"`

### Environment Variables Needed
- `APP_STORE_CONNECT_API_KEY_P8`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `SPARKLE_PRIVATE_KEY_FILE` (for auto-update signing)

---

## 11. Auto-Update with Sparkle

### Conditional Sparkle (Disable for Dev Builds)
```swift
private func isDeveloperIDSigned(bundleURL: URL) -> Bool {
    // Check if signed with Developer ID certificate
}

private func makeUpdaterController() -> UpdaterProviding {
    let bundleURL = Bundle.main.bundleURL
    let isBundledApp = bundleURL.pathExtension == "app"
    guard isBundledApp, isDeveloperIDSigned(bundleURL: bundleURL) else {
        return DisabledUpdaterController()
    }
    // Return real Sparkle controller...
}
```

This prevents Sparkle dialogs during development.

---

## 12. Frontmost App Detection

Track which app is active to show "Paste to [App Name]":
```swift
@Published var frontmostAppName: String = "current app"

init() {
    updateFrontmostAppName(NSWorkspace.shared.frontmostApplication)
    NSWorkspace.shared.notificationCenter.addObserver(
        self,
        selector: #selector(handleAppActivation(_:)),
        name: NSWorkspace.didActivateApplicationNotification,
        object: nil)
}

@objc private func handleAppActivation(_ notification: Notification) {
    let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
    updateFrontmostAppName(app)
}

private func updateFrontmostAppName(_ app: NSRunningApplication?) {
    // Skip if it's our own app
    if app?.bundleIdentifier == Bundle.main.bundleIdentifier { return }
    frontmostAppName = app?.localizedName ?? "current app"
}
```

---

## 13. Text Transformation Patterns

### Pipeline Architecture
Trimmy applies transformations in sequence:
```swift
func transform(text: String, force: Bool) -> ClipboardVariants {
    var currentText = text
    var wasTransformed = false

    if let cleaned = detector.cleanBoxDrawingCharacters(currentText) {
        currentText = cleaned
        wasTransformed = true
    }
    if let promptStripped = detector.stripPromptPrefixes(currentText) {
        currentText = promptStripped
        wasTransformed = true
    }
    if let repairedURL = detector.repairWrappedURL(currentText) {
        currentText = repairedURL
        wasTransformed = true
    }
    if let commandTransformed = detector.transformIfCommand(currentText, ...) {
        currentText = commandTransformed
        wasTransformed = true
    }

    return ClipboardVariants(original: text, trimmed: currentText, wasTransformed: wasTransformed)
}
```

**Recommendation for Optimus Clip:** Use a similar pipeline pattern where each transformation step returns `nil` if no change was made.

### Known Command Prefixes
Trimmy maintains a list of known command prefixes for heuristic detection:
```swift
private static let knownCommandPrefixes: [String] = [
    "sudo", "./", "~/", "apt", "brew", "git", "python", "pip", "pnpm", "npm", "yarn", "cargo",
    "bundle", "rails", "go", "make", "xcodebuild", "swift", "kubectl", "docker", "podman", "aws",
    "gcloud", "az", "ls", "cd", "cat", "echo", "env", "export", "open", "node", "java", "ruby",
    "perl", "bash", "zsh", "fish", "pwsh", "sh",
]
```

---

## Summary: Key Patterns to Adopt

| Pattern | Recommendation |
|---------|----------------|
| **Clipboard marker** | Use custom pasteboard type to avoid reprocessing own writes |
| **Polling with grace delay** | 150ms poll + 80ms grace delay for settled data |
| **KeyboardShortcuts package** | Use for hotkey recording and global shortcut handling |
| **Accessibility polling** | Poll every 2s to detect when user grants permission |
| **CGEvent for paste** | Use `CGEvent` with `kVK_ANSI_V` to simulate Cmd+V |
| **LSUIElement** | Set in Info.plist for menu-bar-only app |
| **SMAppService** | Use for launch-at-login on macOS 13+ |
| **MenuBarExtraAccess** | Access NSStatusItem from SwiftUI for icon customization |
| **Sparkle** | Consider for auto-update (conditional for signed builds only) |
| **Transformation pipeline** | Chain transformations, each returning nil if no change |
