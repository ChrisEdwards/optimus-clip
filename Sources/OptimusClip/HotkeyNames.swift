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
/// ## Built-in Transformations
/// These are pre-defined transformations that ship with Optimus Clip:
/// - `cleanTerminalText`: Fast algorithmic cleanup (Cmd+Option+V default)
/// - `formatAsMarkdown`: LLM-based markdown formatting (Cmd+Option+S default)
///
/// ## User-Created Transformations
/// Dynamic transformations created by users get names at runtime via:
/// ```swift
/// KeyboardShortcuts.Name("transformation_\(uuid)")
/// ```
/// These are managed by TransformationConfig.shortcutName computed property.
extension KeyboardShortcuts.Name {
    // MARK: - Built-in Transformations

    /// Clean Terminal Text transformation: Fast algorithmic cleanup.
    ///
    /// Default shortcut: Cmd+Option+V
    /// - Strips leading/trailing whitespace
    /// - Smart unwraps hard-wrapped text
    /// - No LLM call (instant execution)
    static let cleanTerminalText = Self(
        "cleanTerminalText",
        default: .init(.v, modifiers: [.command, .option])
    )

    /// Format As Markdown transformation: LLM-based formatting.
    ///
    /// Default shortcut: Cmd+Option+S
    /// - Uses configured LLM provider
    /// - Converts text to clean markdown
    /// - Slower but more intelligent
    static let formatAsMarkdown = Self(
        "formatAsMarkdown",
        default: .init(.s, modifiers: [.command, .option])
    )

    // MARK: - Dynamic Transformation Names

    /// Creates a shortcut name for a user-created transformation.
    ///
    /// - Parameter id: The UUID of the transformation.
    /// - Returns: A unique KeyboardShortcuts.Name for this transformation.
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
        Self("transformation_\(id.uuidString)")
    }
}
