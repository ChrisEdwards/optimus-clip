# Replace Algorithmic Transforms with AI-Powered Clean Terminal Text

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove all algorithmic transformation code and replace "Clean Terminal Text" with an LLM-based transformation that removes leading spaces and unwraps terminal-wrapped lines.

**Architecture:** All transformations become LLM-based. The `TransformationType` enum, `isBuiltIn` flag, and all algorithmic transformation code are removed. The UI simplifies to show LLM configuration for all transformations. Default transformations ship with editable system prompts.

**Tech Stack:** Swift 6, SwiftUI, KeyboardShortcuts, OptimusClipCore

---

## Overview

This plan removes the distinction between "algorithmic" and "LLM" transformations. All transformations will be LLM-based and fully user-configurable. The current "Clean Terminal Text" algorithmic pipeline (WhitespaceStrip + SmartUnwrap) is replaced with a single LLM transformation.

### Files to Delete
- `Sources/OptimusClipCore/Transformations/WhitespaceStripTransformation.swift`
- `Sources/OptimusClipCore/Transformations/SmartUnwrapTransformation.swift`
- `Sources/OptimusClipCore/Detection/CodeDetector.swift`
- `Tests/OptimusClipTests/WhitespaceStripTransformationTests.swift`
- `Tests/OptimusClipTests/SmartUnwrapTransformationTests.swift`
- `Tests/OptimusClipTests/SmartUnwrapConfigurationTests.swift`
- `Tests/OptimusClipTests/CodeDetectorTests.swift`

### Files to Modify
- `Sources/OptimusClip/Models/TransformationConfig.swift`
- `Sources/OptimusClipCore/TransformationPipeline.swift`
- `Sources/OptimusClipCore/TransformationRegistry.swift`
- `Sources/OptimusClipCore/Transformation.swift`
- `Sources/OptimusClip/Managers/HotkeyManager.swift`
- `Sources/OptimusClip/Services/TransformationTester.swift`
- `Sources/OptimusClip/Views/Settings/Transformations/TransformationsSidebarView.swift`
- `Sources/OptimusClip/Views/Settings/Transformations/TransformationEditorView.swift`
- `Sources/OptimusClip/HotkeyNames.swift`
- `Tests/OptimusClipTests/TransformationPipelineTests.swift`
- `Tests/OptimusClipTests/TransformationConfigTests.swift`
- `Tests/OptimusClipTests/TransformationTesterTests.swift`
- `Tests/OptimusClipTests/MenuBarTransformationsLoaderTests.swift`

---

## Task 1: Remove TransformationType Enum and Type Field

**Files:**
- Modify: `Sources/OptimusClip/Models/TransformationConfig.swift`

**Step 1: Write the failing test**

Create test file `Tests/OptimusClipTests/TransformationConfigLLMOnlyTests.swift`:

```swift
import Testing
@testable import OptimusClip

@Suite("TransformationConfig LLM-Only Tests")
struct TransformationConfigLLMOnlyTests {
    @Test("TransformationConfig has no type property")
    func noTypeProperty() {
        let config = TransformationConfig(
            name: "Test",
            isEnabled: true,
            provider: "anthropic",
            systemPrompt: "Test prompt"
        )

        // If this compiles, there's no type property
        #expect(config.name == "Test")
        #expect(config.provider == "anthropic")
    }

    @Test("TransformationConfig has no isBuiltIn property")
    func noIsBuiltInProperty() {
        let config = TransformationConfig(
            name: "Test",
            isEnabled: true
        )

        // If this compiles, there's no isBuiltIn property
        #expect(config.name == "Test")
    }

    @Test("Default Clean Terminal Text is LLM-based with prompt")
    func defaultCleanTerminalTextHasPrompt() {
        let defaults = TransformationConfig.defaultTransformations
        let cleanTerminal = defaults.first { $0.id == TransformationConfig.cleanTerminalTextDefaultID }

        #expect(cleanTerminal != nil)
        #expect(cleanTerminal?.systemPrompt.isEmpty == false)
        #expect(cleanTerminal?.provider == "anthropic")
    }
}
```

**Step 2: Run test to verify it fails**

Run: `make test VERBOSE=1 2>&1 | grep -A5 "TransformationConfigLLMOnlyTests"`
Expected: FAIL - compilation errors due to missing `type` parameter

**Step 3: Remove TransformationType enum from TransformationConfig.swift**

Delete lines 4-31 (the entire `TransformationType` enum):

```swift
// DELETE THIS ENTIRE BLOCK:
// MARK: - Transformation Types

/// Type of transformation processing.
///
/// - `algorithmic`: Fast, rule-based transformations (whitespace cleanup, etc.)
/// - `llm`: LLM-based intelligent transformations using configured provider
enum TransformationType: String, Codable, CaseIterable, Identifiable, Sendable {
    case algorithmic
    case llm

    var id: String { self.rawValue }

    /// User-friendly display name for the transformation type.
    var displayName: String {
        switch self {
        case .algorithmic: "Quick"
        case .llm: "LLM"
        }
    }

    /// Detailed description for UI picker.
    var detailedName: String {
        switch self {
        case .algorithmic: "Algorithmic (Fast)"
        case .llm: "LLM-Based (Smart)"
        }
    }
}
```

**Step 4: Remove type and isBuiltIn properties from TransformationConfig struct**

Update the struct to remove `type` and `isBuiltIn`:

```swift
/// Configuration for a user-defined clipboard transformation.
///
/// Stores all settings needed to execute a transformation:
/// - Basic info (name, enabled state)
/// - LLM settings (provider, model, prompt)
///
/// ## Persistence
/// TransformationConfig is Codable for JSON serialization to @AppStorage.
/// Use AppStorageCodable property wrapper for array storage.
///
/// ## Hotkey Integration
/// Use `shortcutName` computed property with KeyboardShortcuts package:
/// ```swift
/// KeyboardShortcuts.Recorder("Hotkey:", name: config.shortcutName)
/// ```
struct TransformationConfig: Identifiable, Hashable, Sendable {
    /// Unique identifier for this transformation.
    var id: UUID

    /// User-provided name for the transformation.
    var name: String

    /// Whether this transformation is active and responds to hotkeys.
    var isEnabled: Bool

    /// LLM provider to use.
    var provider: String?

    /// Model name to use.
    var model: String?

    /// System prompt for LLM transformations.
    var systemPrompt: String

    /// Creates a new transformation configuration with defaults.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID).
    ///   - name: Display name for the transformation.
    ///   - isEnabled: Whether the transformation is active (defaults to true).
    ///   - provider: LLM provider name (optional).
    ///   - model: LLM model name (optional).
    ///   - systemPrompt: System prompt for LLM processing (defaults to empty).
    init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool = true,
        provider: String? = nil,
        model: String? = nil,
        systemPrompt: String = ""
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.provider = provider
        self.model = model
        self.systemPrompt = systemPrompt
    }

    /// KeyboardShortcuts.Name for this transformation's hotkey.
    var shortcutName: KeyboardShortcuts.Name {
        KeyboardShortcuts.Name.transformation(self.id)
    }
}
```

**Step 5: Update Codable conformance**

```swift
// MARK: - Codable Conformance

extension TransformationConfig: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, isEnabled, provider, model, systemPrompt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        self.provider = try container.decodeIfPresent(String.self, forKey: .provider)
        self.model = try container.decodeIfPresent(String.self, forKey: .model)
        self.systemPrompt = try container.decode(String.self, forKey: .systemPrompt)
    }
}
```

**Step 6: Update default transformations with Clean Terminal Text prompt**

```swift
// MARK: - Default Transformations

extension TransformationConfig {
    // MARK: - Stable UUIDs for Defaults

    /// Stable UUID for the default "Clean Terminal Text" transformation.
    static let cleanTerminalTextDefaultID = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()

    /// Stable UUID for the default "Format As Markdown" transformation.
    static let formatAsMarkdownDefaultID = UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID()

    /// Default transformations provided on first launch.
    ///
    /// These serve as examples and can be modified or deleted by the user.
    /// Uses stable UUIDs so recorded shortcuts persist across app restarts.
    static let defaultTransformations: [TransformationConfig] = [
        TransformationConfig(
            id: cleanTerminalTextDefaultID,
            name: "Clean Terminal Text",
            isEnabled: true,
            provider: "anthropic",
            model: nil,
            systemPrompt: """
            Clean up terminal-copied text by removing leading indentation and unwrapping hard-wrapped lines.

            This text was copied from a terminal application where:
            - Lines have consistent leading whitespace (usually 2-4 spaces) added by the terminal
            - Long lines are hard-wrapped at a fixed column width (typically 50-80 characters)
            - Wrapped continuation lines may or may not have the same leading indent

            Your task:
            1. Detect and remove consistent leading whitespace from all lines
            2. Identify hard-wrapped lines (lines that end mid-sentence and continue on the next line)
            3. Join hard-wrapped lines back into proper paragraphs
            4. Preserve intentional line breaks (empty lines, list items, code blocks)
            5. Preserve code blocks and their original indentation structure

            CRITICAL: Return ONLY the cleaned text. No explanations, no summaries, no commentary. Just the transformed text verbatim.
            """
        ),
        TransformationConfig(
            id: formatAsMarkdownDefaultID,
            name: "Format As Markdown",
            isEnabled: false,
            provider: "anthropic",
            model: nil,
            systemPrompt: """
            Clean up terminal-copied text while preserving content.

            This text was likely copied from a terminal application (such as Claude Code) \
            where:
            - Original lines have a consistent leading indent (often 2 spaces), but wrapped \
            continuation lines do NOT have this indent
            - The first line may or may not have the leading indent depending on where the \
            selection started
            - Markdown formatting (headers, bold, lists, code blocks) loses its visual styling

            Your task:

            1. Rejoin wrapped lines: Lines WITHOUT the consistent leading indent are likely \
            continuations of the previous line due to terminal word-wrap. Join them to the \
            preceding line. Lines WITH the indent are true line breaks.
            2. Strip the consistent leading indent: After rejoining, remove the consistent \
            prefix (e.g., 2 spaces) from all lines while preserving intentional relative \
            indentation within the content.
            3. Restore markdown structure: Identify headers, bullet lists, numbered lists, \
            bold/italic text, and code blocks. Often these headers need to be inferred as \
            only the text is preserved, not the formatting on the copy. Identify the headers \
            from the context of the document. You should be able to infer the hierarchy. \
            Format them with proper markdown syntax.
            4. Preserve code blocks carefully: Code should retain its original structure. \
            Use the indent pattern to identify wrapped lines within code too, but be \
            cautious—code indentation is meaningful.
            5. Minimal text changes: Fix only obvious spelling errors. Do not rephrase, \
            reword, or "improve" the writing. Do not change capitalization of proper terms, \
            technical names, or acronyms.
            6. Plain code handling: If the input is entirely code with no prose, output it \
            as a clean code block without adding markdown prose around it.

            ONLY RETURN THE TRANSFORMED TEXT, DO NOT ADD ANY OTHER OUTPUT OR COMMENTS TO \
            THE RESPONSE. THIS IS IMPORTANT! DO NOT EXPLAIN WHAT YOU DID, JUST RETURN THE \
            TEXT AND THE TEXT ONLY!

            Examples of Bad transforms. DO NOT RETURN THESE STATEMENTS:
            - Here's the formatted Markdown version of the code:
            - In this markdown, I have used…
            or anything similar to that that is NOT the text being transformed.
            """
        )
    ]
}
```

**Step 7: Update persistence helpers - remove migration**

```swift
// MARK: - Persistence Helpers

extension TransformationConfig {
    /// Decodes stored transformations from persisted data.
    ///
    /// - Parameter data: Raw Data from @AppStorage.
    /// - Returns: Decoded transformations, or defaults if data is empty/missing.
    /// - Throws: Decoding errors when data exists but cannot be parsed.
    static func decodeStoredTransformations(from data: Data?) throws -> [TransformationConfig] {
        guard let data, !data.isEmpty else {
            return self.defaultTransformations
        }
        return try JSONDecoder().decode([TransformationConfig].self, from: data)
    }
}
```

**Step 8: Run test to verify it passes**

Run: `make test`
Expected: PASS

**Step 9: Commit**

```bash
git add Sources/OptimusClip/Models/TransformationConfig.swift Tests/OptimusClipTests/TransformationConfigLLMOnlyTests.swift
git commit -m "refactor(model): remove TransformationType enum and isBuiltIn (oc-f5d)

- Remove TransformationType enum (algorithmic/llm distinction)
- Remove isBuiltIn property from TransformationConfig
- Remove type field from struct and Codable conformance
- Update Clean Terminal Text to be LLM-based with system prompt
- Remove migration logic (no longer needed)
- Add tests for LLM-only configuration"
```

---

## Task 2: Update TransformationPipeline - Remove Algorithmic Factory

**Files:**
- Modify: `Sources/OptimusClipCore/TransformationPipeline.swift`

**Step 1: Write the failing test**

Add to `Tests/OptimusClipTests/TransformationPipelineTests.swift`:

```swift
@Test("PipelineConfig has no algorithmic static property")
func noAlgorithmicConfig() {
    // Only .llm config should exist
    let config = PipelineConfig.llm
    #expect(config.timeout == 30.0)
}
```

**Step 2: Run test to verify current state**

Run: `make test`
Expected: Test passes but we need to verify `.algorithmic` still exists - check compilation after removal

**Step 3: Remove cleanTerminalText() factory and .algorithmic config**

In `TransformationPipeline.swift`, remove:

1. Remove `.algorithmic` from `PipelineConfig`:
```swift
// DELETE:
/// Default configuration for algorithmic transforms (fast, fail-fast).
public static let algorithmic = PipelineConfig(timeout: 5.0, failFast: true)
```

2. Update the default initializer:
```swift
public init(
    transformations: [any Transformation],
    config: PipelineConfig = .llm  // Changed default from .algorithmic
)
```

3. Remove `cleanTerminalText()` factory method entirely:
```swift
// DELETE THIS ENTIRE METHOD:
/// Creates a "Clean Terminal Text" pipeline with strip whitespace and smart unwrap.
///
/// This is the default algorithmic transformation pipeline for
/// cleaning up CLI output before pasting.
///
/// - Returns: Pipeline configured with whitespace strip and smart unwrap.
public static func cleanTerminalText() -> TransformationPipeline {
    TransformationPipeline(
        transformations: [
            WhitespaceStripTransformation(),
            SmartUnwrapTransformation()
        ],
        config: .algorithmic
    )
}
```

4. Update `single()` factory default:
```swift
public static func single(
    _ transformation: any Transformation,
    config: PipelineConfig = .llm  // Changed from .algorithmic
) -> TransformationPipeline
```

**Step 4: Run tests to check for compilation errors**

Run: `make test`
Expected: Compilation errors in files referencing `.algorithmic` or `cleanTerminalText()`

**Step 5: Commit**

```bash
git add Sources/OptimusClipCore/TransformationPipeline.swift
git commit -m "refactor(pipeline): remove algorithmic config and cleanTerminalText factory (oc-f5d)

- Remove PipelineConfig.algorithmic static property
- Remove TransformationPipeline.cleanTerminalText() factory
- Update defaults to use .llm config
- Pipeline now expects LLM transformations only"
```

---

## Task 3: Update HotkeyManager - Remove Algorithmic Branch

**Files:**
- Modify: `Sources/OptimusClip/Managers/HotkeyManager.swift`

**Step 1: Read current implementation**

The `triggerTransformation` method has a switch on `transformation.type`:
- `.algorithmic` → uses `cleanTerminalText()` pipeline
- `.llm` → creates LLM pipeline

**Step 2: Update handleBuiltInHotkey to use LLM for cleanTerminalText**

Replace the `.cleanTerminalText` case:

```swift
case .cleanTerminalText:
    logger.debug("Creating Clean Terminal Text LLM pipeline")
    guard let pipeline = self.createCleanTerminalTextPipeline() else {
        logger
            .error(
                "Clean Terminal Text failed: No LLM provider configured. Add API key in Settings > Providers."
            )
        SoundManager.shared.playBeep()
        return
    }
    self.flowCoordinator.pipeline = pipeline
```

**Step 3: Add createCleanTerminalTextPipeline method**

```swift
/// Builds the Clean Terminal Text pipeline using stored settings or a provider fallback.
func createCleanTerminalTextPipeline() -> TransformationPipeline? {
    let factory = self.llmFactory
    guard let stored = self.cleanTerminalTextTransformation() else {
        logger.warning("No stored Clean Terminal Text transformation found")
        return nil
    }

    if let pipeline = self.createLLMPipeline(for: stored) {
        logger.info("Using stored Clean Terminal Text transformation")
        return pipeline
    }

    // Fall back to any configured provider while preserving the user's prompt
    guard let configuredClients = try? factory.configuredClients(),
          let (provider, client) = configuredClients.first else {
        logger.warning("No LLM providers configured in Keychain")
        return nil
    }

    logger.info("Using fallback provider: \(provider.rawValue) with stored Clean Terminal Text prompt")
    let model = stored.model ?? Self.defaultModel(for: provider)
    return self.makeLLMPipeline(
        client: client,
        model: model,
        systemPrompt: stored.systemPrompt,
        displayName: stored.name,
        id: "clean-terminal-text-builtin"
    )
}

/// Loads the stored Clean Terminal Text transformation (if available).
func cleanTerminalTextTransformation() -> TransformationConfig? {
    guard let transformations = self.loadPersistedTransformations() else {
        return nil
    }

    return transformations.first { $0.id == TransformationConfig.cleanTerminalTextDefaultID }
}
```

**Step 4: Refactor makeFormatAsMarkdownPipeline to generic makeLLMPipeline**

```swift
/// Creates an LLM pipeline with the given client and configuration.
private func makeLLMPipeline(
    client: any LLMProviderClient,
    model: String,
    systemPrompt: String,
    displayName: String,
    id: String
) -> TransformationPipeline {
    let timeoutSeconds = self.userDefaults.double(forKey: SettingsKey.transformationTimeout)
    let effectiveTimeout = timeoutSeconds > 0 ? timeoutSeconds : DefaultSettings.transformationTimeout

    let transformation = LLMTransformation(
        id: id,
        displayName: displayName,
        providerClient: client,
        model: model,
        systemPrompt: systemPrompt,
        timeoutSeconds: effectiveTimeout
    )
    return TransformationPipeline.single(transformation, config: .llm)
}
```

**Step 5: Update makeFormatAsMarkdownPipeline to use makeLLMPipeline**

```swift
private func makeFormatAsMarkdownPipeline(
    client: any LLMProviderClient,
    model: String,
    systemPrompt: String,
    displayName: String
) -> TransformationPipeline {
    self.makeLLMPipeline(
        client: client,
        model: model,
        systemPrompt: systemPrompt,
        displayName: displayName,
        id: "format-as-markdown-builtin"
    )
}
```

**Step 6: Remove the algorithmic branch from triggerTransformation**

Replace the entire switch statement:

```swift
// Configure pipeline - all transformations are now LLM-based
guard let pipeline = self.createLLMPipeline(for: effectiveTransformation) else {
    // LLM not configured - beep and abort
    SoundManager.shared.playBeep()
    return false
}
self.flowCoordinator.pipeline = pipeline
```

**Step 7: Run tests**

Run: `make test`
Expected: Compilation errors for `.type` property access

**Step 8: Fix remaining .type references**

Search for any remaining `.type` references and update them.

**Step 9: Run tests again**

Run: `make test`
Expected: PASS

**Step 10: Commit**

```bash
git add Sources/OptimusClip/Managers/HotkeyManager.swift
git commit -m "refactor(hotkey): remove algorithmic transformation branch (oc-f5d)

- Update handleBuiltInHotkey to use LLM for Clean Terminal Text
- Add createCleanTerminalTextPipeline() method
- Refactor to shared makeLLMPipeline() helper
- Remove switch on transformation.type in triggerTransformation
- All transformations now route through LLM pipeline"
```

---

## Task 4: Update TransformationTester - Remove Algorithmic Branch

**Files:**
- Modify: `Sources/OptimusClip/Services/TransformationTester.swift`

**Step 1: Remove the switch statement and algorithmic test**

Replace `runTest` method:

```swift
/// Runs a transformation test and returns the result.
///
/// - Parameters:
///   - transformation: The transformation configuration to test.
///   - input: The input text to transform.
/// - Returns: The transformed output.
/// - Throws: `TransformationTestError` if the test fails.
func runTest(transformation: TransformationConfig, input: String) async throws -> String {
    try await self.runLLMTest(transformation: transformation, input: input)
}
```

**Step 2: Delete runAlgorithmicTest method**

```swift
// DELETE THIS ENTIRE METHOD:
private func runAlgorithmicTest(input: String) async throws -> String {
    let pipeline = TransformationPipeline.cleanTerminalText()
    let result = try await pipeline.execute(input)
    return result.output
}
```

**Step 3: Run tests**

Run: `make test`
Expected: PASS

**Step 4: Commit**

```bash
git add Sources/OptimusClip/Services/TransformationTester.swift
git commit -m "refactor(tester): remove algorithmic test branch (oc-f5d)

- Remove runAlgorithmicTest method
- All transformations now test via LLM pipeline"
```

---

## Task 5: Update TransformationsSidebarView - Remove Type Badge and Lock Icon

**Files:**
- Modify: `Sources/OptimusClip/Views/Settings/Transformations/TransformationsSidebarView.swift`

**Step 1: Remove isSelectedBuiltIn computed property**

Delete:
```swift
/// Whether the currently selected transformation is a built-in.
private var isSelectedBuiltIn: Bool {
    guard let id = self.selectedID else { return false }
    return self.transformations.first { $0.id == id }?.isBuiltIn ?? false
}
```

**Step 2: Update delete button to always be enabled when selection exists**

```swift
Button {
    if let id = self.selectedID {
        self.onDelete(id)
    }
} label: {
    Image(systemName: "minus")
}
.buttonStyle(.borderless)
.disabled(self.selectedID == nil)
.help("Delete Transformation")
```

**Step 3: Update TransformationRowView - remove type badge and lock icon**

```swift
struct TransformationRowView: View {
    let transformation: TransformationConfig

    var body: some View {
        HStack(spacing: 8) {
            // Enabled indicator
            Image(systemName: self.transformation.isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(self.transformation.isEnabled ? .green : .secondary)
                .font(.system(size: 12))

            // Name only (no lock icon)
            Text(self.transformation.name)
                .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, 2)
    }
}
```

**Step 4: Run app to verify visual changes**

Run: `make start`
Expected: No type badges, no lock icons in sidebar

**Step 5: Commit**

```bash
git add Sources/OptimusClip/Views/Settings/Transformations/TransformationsSidebarView.swift
git commit -m "refactor(ui): remove type badge and lock icon from sidebar (oc-f5d)

- Remove 'Quick' and 'LLM' type badges
- Remove lock icon for built-in transformations
- Remove isSelectedBuiltIn computed property
- All transformations can now be deleted"
```

---

## Task 6: Update TransformationEditorView - Show LLM Config for All

**Files:**
- Modify: `Sources/OptimusClip/Views/Settings/Transformations/TransformationEditorView.swift`

**Step 1: Remove isBuiltIn conditional**

Change:
```swift
// LLM Configuration: shown for user transformations (always LLM), hidden for built-ins
if !self.transformation.isBuiltIn {
```

To:
```swift
// LLM Configuration: shown for all transformations
```

Remove the `if` wrapper entirely - always show the LLM Configuration section.

**Step 2: Update name field - always editable**

Change:
```swift
// Name: read-only for built-ins, editable for user transformations
if self.transformation.isBuiltIn {
    LabeledContent("Name", value: self.transformation.name)
} else {
    TextField("Name", text: self.$transformation.name)
        .textFieldStyle(.roundedBorder)
}
```

To:
```swift
TextField("Name", text: self.$transformation.name)
    .textFieldStyle(.roundedBorder)
```

**Step 3: Run app to verify**

Run: `make start`
Expected: All transformations show editable name and LLM configuration

**Step 4: Commit**

```bash
git add Sources/OptimusClip/Views/Settings/Transformations/TransformationEditorView.swift
git commit -m "refactor(ui): show LLM config for all transformations (oc-f5d)

- Remove isBuiltIn conditional from editor
- Name field is now always editable
- LLM Configuration section always shown
- All transformations are fully configurable"
```

---

## Task 7: Update TransformationRegistry - Remove Algorithmic Registrations

**Files:**
- Modify: `Sources/OptimusClipCore/TransformationRegistry.swift`

**Step 1: Update TransformationCategory enum**

```swift
/// Category of transformation for organizational purposes.
public enum TransformationCategory: Sendable {
    /// Default transformations that ship with the app
    case defaultTransformation
    /// Custom transforms created by user
    case userDefined
}
```

**Step 2: Remove registerBuiltInTransformations method**

Delete or empty the method:

```swift
/// Register all built-in transformations.
private func registerBuiltInTransformations() {
    // No longer registers algorithmic transformations
    // LLM transformations are managed via TransformationConfig persistence
}
```

**Step 3: Run tests**

Run: `make test`
Expected: Some tests may fail due to expecting WhitespaceStripTransformation

**Step 4: Commit**

```bash
git add Sources/OptimusClipCore/TransformationRegistry.swift
git commit -m "refactor(registry): remove algorithmic transformation registrations (oc-f5d)

- Update TransformationCategory to use defaultTransformation instead of builtin
- Remove WhitespaceStripTransformation and SmartUnwrapTransformation registrations
- Registry no longer auto-registers algorithmic transforms"
```

---

## Task 8: Delete Algorithmic Transformation Files

**Files:**
- Delete: `Sources/OptimusClipCore/Transformations/WhitespaceStripTransformation.swift`
- Delete: `Sources/OptimusClipCore/Transformations/SmartUnwrapTransformation.swift`
- Delete: `Sources/OptimusClipCore/Detection/CodeDetector.swift`

**Step 1: Delete the files**

```bash
rm Sources/OptimusClipCore/Transformations/WhitespaceStripTransformation.swift
rm Sources/OptimusClipCore/Transformations/SmartUnwrapTransformation.swift
rm Sources/OptimusClipCore/Detection/CodeDetector.swift
```

**Step 2: Run build to find remaining references**

Run: `make build`
Expected: Compilation errors in files still referencing these types

**Step 3: Fix remaining references**

Update any files that still import or reference:
- `WhitespaceStripTransformation`
- `SmartUnwrapTransformation`
- `CodeDetector`
- `WhitespaceStripConfig`
- `SmartUnwrapConfig`
- `CodePreservationConfig`

**Step 4: Commit**

```bash
git add -A
git commit -m "refactor(core): delete algorithmic transformation files (oc-f5d)

- Delete WhitespaceStripTransformation.swift
- Delete SmartUnwrapTransformation.swift
- Delete CodeDetector.swift
- Remove all references to these types"
```

---

## Task 9: Delete Algorithmic Transformation Tests

**Files:**
- Delete: `Tests/OptimusClipTests/WhitespaceStripTransformationTests.swift`
- Delete: `Tests/OptimusClipTests/SmartUnwrapTransformationTests.swift`
- Delete: `Tests/OptimusClipTests/SmartUnwrapConfigurationTests.swift`
- Delete: `Tests/OptimusClipTests/CodeDetectorTests.swift`

**Step 1: Delete the test files**

```bash
rm Tests/OptimusClipTests/WhitespaceStripTransformationTests.swift
rm Tests/OptimusClipTests/SmartUnwrapTransformationTests.swift
rm Tests/OptimusClipTests/SmartUnwrapConfigurationTests.swift
rm Tests/OptimusClipTests/CodeDetectorTests.swift
```

**Step 2: Run tests**

Run: `make test`
Expected: PASS (fewer tests, but all passing)

**Step 3: Commit**

```bash
git add -A
git commit -m "test: delete algorithmic transformation tests (oc-f5d)

- Delete WhitespaceStripTransformationTests.swift
- Delete SmartUnwrapTransformationTests.swift
- Delete SmartUnwrapConfigurationTests.swift
- Delete CodeDetectorTests.swift"
```

---

## Task 10: Update Remaining Test Files

**Files:**
- Modify: `Tests/OptimusClipTests/TransformationPipelineTests.swift`
- Modify: `Tests/OptimusClipTests/TransformationConfigTests.swift`
- Modify: `Tests/OptimusClipTests/TransformationTesterTests.swift`
- Modify: `Tests/OptimusClipTests/MenuBarTransformationsLoaderTests.swift`
- Modify: `Tests/OptimusClipTests/TransformationRegistryTests.swift`

**Step 1: Update TransformationPipelineTests.swift**

Remove tests that use `cleanTerminalText()` or `.algorithmic` config. Update to use `.llm` config and mock LLM transformations.

**Step 2: Update TransformationConfigTests.swift**

Remove tests for `type` property and `isBuiltIn`. Update tests to verify new LLM-only structure.

**Step 3: Update TransformationTesterTests.swift**

Remove tests for algorithmic testing. Update to only test LLM path.

**Step 4: Update MenuBarTransformationsLoaderTests.swift**

Remove references to `cleanTerminalText()` pipeline.

**Step 5: Update TransformationRegistryTests.swift**

Remove tests expecting WhitespaceStripTransformation and SmartUnwrapTransformation to be registered.

**Step 6: Run all tests**

Run: `make test`
Expected: PASS

**Step 7: Commit**

```bash
git add Tests/
git commit -m "test: update tests for LLM-only architecture (oc-f5d)

- Remove algorithmic transformation test cases
- Update pipeline tests to use .llm config
- Update config tests to remove type/isBuiltIn assertions
- Update registry tests to not expect algorithmic registrations"
```

---

## Task 11: Update Documentation and Comments

**Files:**
- Modify: `Sources/OptimusClipCore/Transformation.swift`
- Modify: `Sources/OptimusClip/HotkeyNames.swift`
- Modify: `AGENTS.md`

**Step 1: Update Transformation.swift comments**

Remove references to algorithmic transformations in comments:

```swift
/// A clipboard transformation that processes text input and produces text output.
///
/// All transformations are LLM-based and use the configured provider to process text.
/// Transformations must be thread-safe and support Swift 6 strict concurrency.
///
/// Example implementations:
/// - Clean Terminal Text (removes whitespace, unwraps lines)
/// - Format as Markdown (converts to clean markdown)
/// - Format as Jira ticket (converts to Jira format)
public protocol Transformation: Sendable {
```

**Step 2: Update HotkeyNames.swift comments**

```swift
/// Clean Terminal Text transformation: LLM-based text cleanup.
///
/// Default shortcut: Cmd+Option+V
/// - Strips leading whitespace via LLM
/// - Smart unwraps hard-wrapped text via LLM
/// - Uses configured LLM provider
static let cleanTerminalText = Self(
```

**Step 3: Update AGENTS.md if needed**

Check for any references to algorithmic transformations that need updating.

**Step 4: Commit**

```bash
git add Sources/OptimusClipCore/Transformation.swift Sources/OptimusClip/HotkeyNames.swift AGENTS.md
git commit -m "docs: update comments for LLM-only architecture (oc-f5d)

- Remove references to algorithmic transformations
- Update Transformation protocol documentation
- Update HotkeyNames documentation"
```

---

## Task 12: Final Verification and Cleanup

**Step 1: Run full test suite**

Run: `make check-test`
Expected: All checks pass, all tests pass

**Step 2: Run the app and test manually**

Run: `make start`

Test:
1. Open Settings > Transformations
2. Verify Clean Terminal Text shows LLM configuration (provider, model, prompt)
3. Verify no type badges in sidebar
4. Verify no lock icons
5. Try editing Clean Terminal Text name and prompt
6. Try deleting Clean Terminal Text (should work now)
7. Create a new transformation, verify it has LLM fields
8. Test Clean Terminal Text hotkey with configured provider

**Step 3: Verify no dangling references**

```bash
rg "algorithmic" --type swift
rg "isBuiltIn" --type swift
rg "TransformationType" --type swift
rg "WhitespaceStrip" --type swift
rg "SmartUnwrap" --type swift
rg "CodeDetector" --type swift
```

Expected: No matches (or only in comments explaining removal)

**Step 4: Final commit**

```bash
git add -A
git commit -m "chore: final cleanup for LLM-only architecture (oc-f5d)"
```

**Step 5: Close the bead**

```bash
bd close oc-f5d --reason="Removed algorithmic transformations. All transforms now LLM-based. Clean Terminal Text has AI prompt for whitespace/unwrap."
bd sync
```

---

## Summary

This plan removes ~800 lines of algorithmic transformation code and simplifies the architecture to LLM-only. Key changes:

1. **Model**: Removed `TransformationType` enum, `type` field, and `isBuiltIn` flag
2. **Core**: Deleted WhitespaceStripTransformation, SmartUnwrapTransformation, CodeDetector
3. **Pipeline**: Removed `.algorithmic` config and `cleanTerminalText()` factory
4. **Hotkey**: All transformations route through LLM pipeline
5. **UI**: Removed type badges, lock icons; all fields editable
6. **Defaults**: Clean Terminal Text now has LLM prompt for AI-powered cleanup

The user experience remains the same (Cmd+Option+V cleans text) but the implementation is now AI-powered and fully configurable.
