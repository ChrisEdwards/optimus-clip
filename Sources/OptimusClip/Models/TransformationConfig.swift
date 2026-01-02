import Foundation
import KeyboardShortcuts

// MARK: - Transformation Configuration

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
        self.systemPrompt = try container.decodeIfPresent(String.self, forKey: .systemPrompt) ?? ""
    }
}

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
            Clean up terminal-copied text while preserving content.

            This text was likely copied from a terminal application (such as Claude Code) where:
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
            3. Preserve code blocks carefully: Code should retain its original structure. \
            Use the indent pattern to identify wrapped lines within code too, but be \
            cautious—code indentation is meaningful.
            4. No text changes: Do not rephrase, reword, or "improve" the writing. Do not \
            fix misspellings. Do not change capitalization of proper terms, technical names, \
            or acronyms. This is purely a format operation, not a correction or proofreading \
            exercise.

            ONLY RETURN THE TRANSFORMED TEXT, DO NOT ADD ANY OTHER OUTPUT OR COMMENTS TO \
            THE RESPONSE. THIS IS IMPORTANT! DO NOT EXPLAIN WHAT YOU DID, JUST RETURN THE \
            TEXT AND THE TEXT ONLY!

            Examples of Bad transforms. DO NOT RETURN THESE STATEMENTS:
            - Here's the formatted Markdown version of the code:
            - In this markdown, I have used…
            or anything similar to that that is NOT the text being transformed.
            """
        ),
        TransformationConfig(
            id: formatAsMarkdownDefaultID,
            name: "Format As Markdown",
            isEnabled: true,
            provider: "anthropic",
            model: nil,
            systemPrompt: """
            Clean up terminal-copied text while preserving content.

            This text was likely copied from a terminal application (such as Claude Code) where:
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
            5. Use backticks to format filenames, terminal commands, code, or other obvious \
            code-related items to show in monospace as appropriate.
            6. Minimal text changes: Fix only obvious spelling errors. Do not rephrase, \
            reword, or "improve" the writing. Do not change capitalization of proper terms, \
            technical names, or acronyms.
            7. Plain code handling: If the input is entirely code with no prose, output it \
            as a clean code block without adding markdown prose around it.
            8. Make the output visually appealing adding bold/italics and styling as \
            necessary to reproduce what may have been lost in the copy/paste from the \
            original.

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
