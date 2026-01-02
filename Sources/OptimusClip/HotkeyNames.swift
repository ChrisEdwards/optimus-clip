import Foundation
import KeyboardShortcuts

/// KeyboardShortcuts.Name extensions for Optimus Clip hotkeys.
///
/// This file defines all available keyboard shortcut identifiers. The KeyboardShortcuts
/// package uses these names to:
/// - Register global hotkey handlers
/// - Persist user-configured shortcuts to UserDefaults
/// - Display shortcuts in the UI via KeyboardShortcuts.Recorder
///
/// ## Default Transformations
/// These are pre-defined transformations that ship with Optimus Clip:
/// - `cleanTerminalText`: LLM-based terminal text cleanup (Cmd+Option+V default)
/// - `formatAsMarkdown`: LLM-based markdown formatting (Cmd+Option+S default)
///
/// ## User-Created Transformations
/// Dynamic transformations created by users get names at runtime via:
/// ```swift
/// KeyboardShortcuts.Name("transformation_\(uuid)")
/// ```
/// These are managed by TransformationConfig.shortcutName computed property.
extension KeyboardShortcuts.Name {
    // MARK: - Default Transformations

    /// Clean Terminal Text transformation: LLM-based cleanup.
    ///
    /// Default shortcut: Cmd+Option+V
    /// - Removes leading indentation from terminal output
    /// - Unwraps hard-wrapped lines
    /// - Preserves code blocks and intentional formatting
    static let cleanTerminalText = Self(
        "cleanTerminalText",
        default: .init(.v, modifiers: [.command, .option])
    )

    /// Format As Markdown transformation: LLM-based formatting.
    ///
    /// Default shortcut: Cmd+Option+S
    /// - Converts text to clean markdown
    /// - Restores markdown structure from terminal output
    /// - Rejoins wrapped lines and preserves code blocks
    static let formatAsMarkdown = Self(
        "formatAsMarkdown",
        default: .init(.s, modifiers: [.command, .option])
    )

    // MARK: - Default Transformation UUIDs

    /// Stable UUID for the default "Clean Terminal Text" transformation.
    /// Must match TransformationConfig.cleanTerminalTextDefaultID.
    private static let cleanTerminalTextDefaultID = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()

    /// Stable UUID for the default "Format As Markdown" transformation.
    /// Must match TransformationConfig.formatAsMarkdownDefaultID.
    private static let formatAsMarkdownDefaultID = UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID()

    // MARK: - Dynamic Transformation Names

    /// Creates a shortcut name for a user-created transformation.
    ///
    /// - Parameter id: The UUID of the transformation.
    /// - Returns: A unique KeyboardShortcuts.Name for this transformation.
    ///
    /// For default transformations (with stable UUIDs), returns a name with a default shortcut:
    /// - Clean Terminal Text: ⌃⌥T (Control+Option+T)
    /// - Format As Markdown: ⌃⌥M (Control+Option+M)
    ///
    /// ## Usage
    /// ```swift
    /// let name = KeyboardShortcuts.Name.transformation(config.id)
    /// KeyboardShortcuts.Recorder("Hotkey:", name: name)
    /// ```
    ///
    /// ## Important
    /// Don't create Names repeatedly - cache via computed property in TransformationConfig.
    /// Creating new Name instances on every view refresh causes memory leaks.
    static func transformation(_ id: UUID) -> Self {
        let nameString = "transformation_\(id.uuidString)"

        // Provide default shortcuts for the built-in default transformations
        switch id {
        case Self.cleanTerminalTextDefaultID:
            // Control+Option+T for "Terminal" text cleanup
            return Self(nameString, default: .init(.t, modifiers: [.control, .option]))
        case Self.formatAsMarkdownDefaultID:
            // Control+Option+M for "Markdown" formatting
            return Self(nameString, default: .init(.m, modifiers: [.control, .option]))
        default:
            // User-created transformations have no default shortcut
            return Self(nameString)
        }
    }
}
