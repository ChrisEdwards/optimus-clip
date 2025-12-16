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
struct TransformationConfig: Identifiable, Codable, Hashable, Sendable {
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
    init(
        id: UUID = UUID(),
        name: String,
        type: TransformationType = .algorithmic,
        isEnabled: Bool = true,
        provider: String? = nil,
        model: String? = nil,
        systemPrompt: String = ""
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.isEnabled = isEnabled
        self.provider = provider
        self.model = model
        self.systemPrompt = systemPrompt
    }

    /// KeyboardShortcuts.Name for this transformation's hotkey.
    ///
    /// This is a computed property that creates the Name on demand.
    /// The KeyboardShortcuts package stores the actual shortcut value.
    var shortcutName: KeyboardShortcuts.Name {
        KeyboardShortcuts.Name.transformation(self.id)
    }
}

// MARK: - Default Transformations

extension TransformationConfig {
    // MARK: - Stable UUIDs for Defaults

    /// Stable UUID for the default "Clean Terminal Text" transformation.
    ///
    /// Using a fixed UUID ensures the KeyboardShortcuts storage persists
    /// across app restarts, since shortcuts are keyed by transformation UUID.
    private static let cleanTerminalTextDefaultID = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()

    /// Stable UUID for the default "Format As Markdown" transformation.
    private static let formatAsMarkdownDefaultID = UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID()

    /// Default transformations provided on first launch.
    ///
    /// These serve as examples and can be modified or deleted by the user.
    /// Uses stable UUIDs so recorded shortcuts persist across app restarts.
    static let defaultTransformations: [TransformationConfig] = [
        TransformationConfig(
            id: cleanTerminalTextDefaultID,
            name: "Clean Terminal Text",
            type: .algorithmic,
            isEnabled: true,
            systemPrompt: ""
        ),
        TransformationConfig(
            id: formatAsMarkdownDefaultID,
            name: "Format As Markdown",
            type: .llm,
            isEnabled: false,
            provider: "anthropic",
            model: "claude-3-haiku-20240307",
            systemPrompt: """
            Format the following text as clean, well-structured Markdown. \
            Use appropriate headers, lists, code blocks, and emphasis where applicable. \
            Fix any grammar or spelling issues while preserving the original meaning.
            """
        )
    ]
}
