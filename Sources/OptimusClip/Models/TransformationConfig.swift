import Foundation
import KeyboardShortcuts

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

// MARK: - Transformation Configuration

/// Configuration for a user-defined clipboard transformation.
///
/// Stores all settings needed to execute a transformation:
/// - Basic info (name, enabled state)
/// - Transformation type (algorithmic vs LLM)
/// - LLM-specific settings (provider, model, prompt)
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

    /// Type of processing (algorithmic or LLM).
    var type: TransformationType

    /// Whether this transformation is active and responds to hotkeys.
    var isEnabled: Bool

    /// LLM provider to use (only relevant when type == .llm).
    var provider: String?

    /// Model name to use (only relevant when type == .llm).
    var model: String?

    /// System prompt for LLM transformations.
    var systemPrompt: String

    /// Whether this is a built-in transformation that cannot be deleted.
    /// Built-ins have restricted editing (hotkey and enabled only).
    var isBuiltIn: Bool

    /// Creates a new transformation configuration with defaults.
    ///
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID).
    ///   - name: Display name for the transformation.
    ///   - type: Processing type (defaults to algorithmic).
    ///   - isEnabled: Whether the transformation is active (defaults to true).
    ///   - provider: LLM provider name (optional).
    ///   - model: LLM model name (optional).
    ///   - systemPrompt: System prompt for LLM processing (defaults to empty).
    ///   - isBuiltIn: Whether this is a permanent built-in transformation (defaults to false).
    init(
        id: UUID = UUID(),
        name: String,
        type: TransformationType = .algorithmic,
        isEnabled: Bool = true,
        provider: String? = nil,
        model: String? = nil,
        systemPrompt: String = "",
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.isEnabled = isEnabled
        self.provider = provider
        self.model = model
        self.systemPrompt = systemPrompt
        self.isBuiltIn = isBuiltIn
    }

    /// KeyboardShortcuts.Name for this transformation's hotkey.
    ///
    /// This is a computed property that creates the Name on demand.
    /// The KeyboardShortcuts package stores the actual shortcut value.
    var shortcutName: KeyboardShortcuts.Name {
        KeyboardShortcuts.Name.transformation(self.id)
    }
}

// MARK: - Codable Conformance

extension TransformationConfig: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, type, isEnabled, provider, model, systemPrompt, isBuiltIn
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.type = try container.decode(TransformationType.self, forKey: .type)
        self.isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        self.provider = try container.decodeIfPresent(String.self, forKey: .provider)
        self.model = try container.decodeIfPresent(String.self, forKey: .model)
        self.systemPrompt = try container.decode(String.self, forKey: .systemPrompt)
        // Backward compatibility: default to false if key missing (pre-update data)
        self.isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
    }
}

// MARK: - Default Transformations

extension TransformationConfig {
    // MARK: - Stable UUIDs for Defaults

    /// Stable UUID for the default "Clean Terminal Text" transformation.
    ///
    /// Using a fixed UUID ensures the KeyboardShortcuts storage persists
    /// across app restarts, since shortcuts are keyed by transformation UUID.
    /// Public for migration checks.
    static let cleanTerminalTextDefaultID = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()

    /// Stable UUID for the default "Format As Markdown" transformation.
    private static let formatAsMarkdownDefaultID = UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID()

    /// The built-in "Clean Terminal Text" transformation.
    ///
    /// This transformation is permanent and cannot be deleted by users.
    /// Used for migration when ensuring the built-in exists.
    static let builtInCleanTerminalText = TransformationConfig(
        id: cleanTerminalTextDefaultID,
        name: "Clean Terminal Text",
        type: .algorithmic,
        isEnabled: true,
        systemPrompt: "",
        isBuiltIn: true
    )

    /// Default transformations provided on first launch.
    ///
    /// These serve as examples and can be modified or deleted by the user.
    /// Uses stable UUIDs so recorded shortcuts persist across app restarts.
    /// Note: "Clean Terminal Text" is a permanent built-in (isBuiltIn: true).
    static let defaultTransformations: [TransformationConfig] = [
        builtInCleanTerminalText,
        TransformationConfig(
            id: formatAsMarkdownDefaultID,
            name: "Format As Markdown",
            type: .llm,
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
