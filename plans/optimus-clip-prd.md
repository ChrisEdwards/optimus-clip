Here is the full Product Requirements Document (PRD) for **Optimus Clip**. This document allows a developer (or you) to move directly into implementation.

---

# Product Requirements Document (PRD)
**Project Name:** Optimus Clip
**Version:** 1.0 (MVP)
**Platform:** macOS (Menu Bar Application)
**Status:** Ready for Development

---

## 1. Problem Statement
Developers and power users frequently copy text from CLI-based AI tools (like Claude Code, Codex, or raw terminal output). This text is often formatted for display, not for reuse: it contains hard line breaks (wrapping), terminal-specific leading whitespace (usually 2 spaces), and broken paragraph structures. Manually reformatting this text for Jira, Slack, or IDEs is time-consuming and tedious.

## 2. Product Vision
A "set-it-and-forget-it" macOS menu bar utility that acts as an intelligent middleware for the system clipboard. It intercepts clipboard content via global hotkeys, cleans or transforms it using either algorithmic rules or LLMs, and prepares it for immediate pasting.

---

## 3. Functional Requirements

### 3.1. Core Clipboard Operations
* **FR-1.1:** The application must run in the background with a persistent menu bar icon.
* **FR-1.2:** The application must be able to read plain text and rich text from the system clipboard.
* **FR-1.3 (Guardrail):** The application must detect binary data (Images, Files) on the clipboard.
    * *Requirement:* If binary data is detected, the app must abort the transformation to prevent crashes and notify the user via a system beep or UI flash.
* **FR-1.4:** The application must be able to write processed text back to the system clipboard.
* **FR-1.5:** After successful transformation, the application must simulate a paste action (Cmd+V) to insert the processed text at the current cursor position.
* **FR-1.6:** If transformation fails (timeout, network error, or processing error), the clipboard must remain unchanged and no paste action should occur.

### 3.2. Global Hotkey Management
* **FR-2.1:** Users must be able to define global keyboard shortcuts (e.g., `Cmd+Shift+V`).
* **FR-2.2:** Multiple hotkeys must be supported, each mapping to a specific **Transformation** (see 3.3).
* **FR-2.3:** Hotkeys must work regardless of which application is currently in focus.

### 3.3. Transformations
The user can create unlimited Transformations. A Transformation consists of a Name, a Trigger (Hotkey), and a Processing Logic.

#### **Type A: Algorithmic (The "Quick Fix")**
* **FR-3.3.1:** **Whitespace Stripping:** Remove the leading 2 spaces (or custom regex pattern) from every line.
* **FR-3.3.2:** **Smart Unwrap:** Detect "hard wraps" based on line length.
    * *Logic:* If line $N$ and line $N+1$ differ in length by $< 10\%$ of the screen width (or a set character limit), merge them into a single line.
* **FR-3.3.3:** **Code Preservation:** If lines start with code syntax (e.g., `{`, `def `, `[ `), bypass unwrapping for that block.

#### **Type B: LLM-Based (The "Smart Fix")**
* **FR-3.4.1:** Users can define a Custom System Prompt for the transformation (e.g., "Format this as a Jira Ticket description").
* **FR-3.4.2:** Users can select a specific LLM Provider and Model for the transformation.

### 3.4. LLM Integration
The application must support the following providers via API:

* **FR-4.1: OpenAI**
    * Auth: API Key stored in macOS Keychain.
    * Models: GPT-4o, GPT-4o-mini, etc.
* **FR-4.2: Anthropic**
    * Auth: API Key stored in macOS Keychain.
    * Models: Claude Sonnet, Haiku, Opus.
* **FR-4.3: OpenRouter**
    * Auth: API Key stored in macOS Keychain.
    * Models: Fetch available models dynamically.
* **FR-4.4: Ollama (Local)**
    * Endpoint: `http://localhost:11434` (Configurable).
    * Action: Fetch available models dynamically.
* **FR-4.5: AWS Bedrock (Cloud)**
    * Auth: Support local AWS credentials (`~/.aws/credentials`) or explicit Access/Secret Key input.
    * Region: Configurable (e.g., `us-east-1`, `us-west-2`).
    * Models: Support Anthropic Claude (Haiku/Sonnet/Opus) and Amazon Titan.

### 3.5. History Data Storage
* **FR-5.1:** Persist a log of the last 100 transformations locally (SQLite or SwiftData).
* **FR-5.2:** Track the following metrics per transaction:
    * Timestamp.
    * Transformation Name.
    * Provider and Model Used (if LLM).
    * System Prompt Used (if LLM).
    * Original Text (input).
    * Processed Text (output).
    * Input Character Count.
    * Processing Time (ms).
* **FR-5.3 (Post-MVP):** History UI and Performance Analytics views deferred to future release.

---

## 4. User Interface (UI) Requirements

### 4.1. Menu Bar Item
* **Icon:** SF Symbol (e.g., `clipboard` or custom icon).
* **States:**
    * *Idle:* Standard appearance, full opacity.
    * *Disabled:* Dimmed appearance (opacity ~0.45) when auto-processing is off.
    * *Processing:* Pulse animation using `.symbolEffect(.pulse)` triggered by incrementing a state ID.
* **Menu:**
    * Preferences...
    * Quit.

### 4.2. Preferences Window
* **Transformations Tab:**
    * List of current transformations (sidebar).
    * "Add New Transformation" button.
    * **Edit View:**
        * Input: Name.
        * Input: Hotkey Recorder (use `KeyboardShortcuts.Recorder` component).
        * Toggle: Enable/disable this transformation's hotkey.
        * Dropdown: Engine (Algorithmic vs. LLM).
        * (If LLM): Dropdown for Provider, Dropdown for Model, Text Area for System Prompt.
* **Providers Tab:**
    * OpenAI Configuration (API Key with secure input).
    * Anthropic Configuration (API Key with secure input).
    * OpenRouter Configuration (API Key with secure input).
    * Ollama Configuration (Host/Port, "Test Connection" button).
    * AWS Bedrock Configuration (Profile/Region or Access Keys).
* **General Tab:**
    * Launch at Login toggle (uses `SMAppService`).
* **Permissions Tab:**
    * **Accessibility Callout:** Prominent warning banner when permission not granted.
        * Yellow warning icon with explanation text.
        * "Grant Accessibility" button (triggers system prompt).
        * "Open Settings" button (opens Privacy & Security directly).
    * Status indicator showing current permission state.
    * Auto-refreshes when permission is granted (via 2-second polling).

### 4.3. History Window (Post-MVP)
* Deferred to future release. Data will be stored but UI not built for MVP.

---

## 5. Non-Functional Requirements

### 5.1. Performance
* Algorithmic transformations must complete in < 100ms.
* Application memory footprint should remain < 200MB.

### 5.2. Security
* **NFR-2.1:** API Keys (for AWS) must be stored in the macOS Keychain, not in plain text config files.
* **NFR-2.2:** No telemetry data is sent to the developer; all analytics are local-only.

### 5.3. Reliability
* If an LLM call fails (timeout or network error), the clipboard should remain unchanged (or revert to original) and a notification should appear.
* Timeout for LLM calls defaults to 30 seconds.

---

## 6. Technical Architecture

### 6.1. Language & Frameworks
* **Language:** Swift 5+ (macOS 15+)
* **GUI Framework:**
    * `AppKit` for Menu Bar management via `MenuBarExtra`.
    * `SwiftUI` for Settings and Permissions windows.
* **Concurrency:** Swift `async/await` and `Task` for non-blocking LLM calls.

### 6.2. Dependencies (Swift Package Manager)
| Package | Purpose |
|---------|---------|
| `KeyboardShortcuts` (sindresorhus) | Global hotkey recording UI and handler registration |
| `MenuBarExtraAccess` (orchetect) | Access `NSStatusItem` from SwiftUI `MenuBarExtra` for icon customization |
| `LLMChatOpenAI` (kevinhermawan) | OpenAI, OpenRouter, Ollama (OpenAI-compatible APIs) |
| `LLMChatAnthropic` (kevinhermawan) | Anthropic Claude direct API |
| `AWS SDK for Swift` | AWS Bedrock integration |
| `Sparkle` (optional, post-MVP) | Auto-update framework |

### 6.3. Data Storage
* **Settings:** `@AppStorage` (UserDefaults) for user preferences.
* **History:** `SwiftData` or `SQLite` for transformation logs.
* **API Keys:** macOS Keychain via Security framework.

### 6.4. App Configuration (Info.plist)
* `LSUIElement = true` — Menu bar only, no Dock icon.
* `LSMultipleInstancesProhibited = true` — Prevent multiple instances.
* `LSMinimumSystemVersion = 15.0` — macOS 15+ required.

### 6.5. Clipboard Implementation
* **Polling Strategy:** `DispatchSourceTimer` at ~150ms interval with 50ms leeway.
* **Grace Delay:** 80ms after detecting change to allow "promised" pasteboard data to settle.
* **Self-Write Marker:** Custom pasteboard type (e.g., `com.optimusclip.marker`) to avoid reprocessing own clipboard writes.
* **Change Tracking:** Monitor `NSPasteboard.general.changeCount` for clipboard changes.
* **Text Reading Fallbacks:** Try `.string`, then `public.utf8-plain-text`, `public.utf16-external-plain-text`, `public.text`.

### 6.6. Paste Simulation
* **Approach:** Use `CGEvent` API with `Carbon.HIToolbox` to simulate `Cmd+V`.
* **Key Code:** `kVK_ANSI_V` with `.maskCommand` modifier flags.
* **Requirement:** Accessibility permission must be granted.

### 6.7. Accessibility Permission
* **Check:** `AXIsProcessTrusted()` from ApplicationServices.
* **Request:** `AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true])`.
* **Settings URL:** `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`.
* **Polling:** Check permission status every 2 seconds to detect when user grants access.

### 6.8. Launch at Login
* **Framework:** `ServiceManagement` with `SMAppService.mainApp` (macOS 13+).
* **Register:** `SMAppService.mainApp.register()`.
* **Unregister:** `SMAppService.mainApp.unregister()`.

---

## 7. Future Roadmap (Post-MVP)

* **History & Analytics UI:** Searchable history list, detail view with original/transformed toggle, performance analysis modal.
* **Auto-Update:** Integrate Sparkle framework for automatic updates (requires Developer ID signed builds).
* **Image-to-Text:** Detect images on clipboard, send to Multimodal LLM (e.g., Claude 3 Haiku), return Markdown description.
* **CLI Tool:** Headless transformation tool for scripting (separate executable target).
* **Marketplace:** Share and download Transformations from a community repository.
* **IDE Plugins:** Direct integration into VS Code or JetBrains.

---

## 8. Implementation Steps

1.  **Project Setup:**
    * Create Xcode project with Swift Package Manager.
    * Add dependencies: `KeyboardShortcuts`, `MenuBarExtraAccess`, `LLMChatOpenAI`, `LLMChatAnthropic`, `AWS SDK for Swift`.
    * Configure `Info.plist`: `LSUIElement=true`, `LSMultipleInstancesProhibited=true`, `LSMinimumSystemVersion=15.0`.

2.  **Menu Bar App Shell:**
    * Implement `@main App` struct with `MenuBarExtra`.
    * Create `NSApplicationDelegateAdaptor` with `NSApp.setActivationPolicy(.accessory)`.
    * Add status icon with SF Symbol and pulse animation state.

3.  **Clipboard Monitor:**
    * Implement `ClipboardMonitor` class with `DispatchSourceTimer` polling (150ms).
    * Add self-write marker pasteboard type to prevent reprocessing.
    * Implement grace delay (80ms) for promised data.
    * Track `changeCount` for clipboard change detection.

4.  **Paste Simulation:**
    * Implement `CGEvent`-based Cmd+V simulation using `Carbon.HIToolbox`.
    * Add `AccessibilityPermissionManager` with `AXIsProcessTrusted()` checks.
    * Implement permission request flow with system prompt and Settings link.

5.  **Hotkey Management:**
    * Define `KeyboardShortcuts.Name` extensions for transformation hotkeys.
    * Implement `HotkeyManager` to register/unregister handlers.
    * Set sensible default shortcuts (e.g., `Cmd+Option+V`).

6.  **Transformation Engine:**
    * Create `TransformationCore` module for shared logic.
    * Implement algorithmic transformations (whitespace strip, unwrap).
    * Implement LLM transformation wrapper with provider abstraction.

7.  **Settings UI:**
    * Build tabbed `SettingsView` with SwiftUI.
    * Implement `KeyboardShortcuts.Recorder` for hotkey configuration.
    * Add `AccessibilityPermissionCallout` component for permission UX.
    * Use `@AppStorage` for settings persistence.

8.  **LLM Integration:**
    * Implement provider-specific clients (OpenAI, Anthropic, Ollama, Bedrock).
    * Add model fetching for dynamic model lists.
    * Implement async transformation with timeout handling.

9.  **Data & Security:**
    * Implement SwiftData models for history logging.
    * Integrate macOS Keychain for API key storage.
    * Add launch-at-login via `SMAppService`.

10. **Packaging & Distribution:**
    * Create `package_app.sh` script for `.app` bundle creation.
    * Implement code signing with Developer ID.
    * Add notarization via `notarytool` and stapling.
