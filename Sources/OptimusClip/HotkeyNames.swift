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
/// - `quickFix`: Fast algorithmic cleanup (Cmd+Option+V default)
/// - `smartFix`: LLM-based intelligent transformation (Cmd+Option+S default)
///
/// ## User-Created Transformations
/// Dynamic transformations created by users get names at runtime via:
/// ```swift
/// KeyboardShortcuts.Name("transformation_\(uuid)")
/// ```
/// These are managed by TransformationConfig.shortcutName computed property.
extension KeyboardShortcuts.Name {
    // MARK: - Built-in Transformations

    /// Quick Fix transformation: Fast algorithmic cleanup.
    ///
    /// Default shortcut: Cmd+Option+V
    /// - Strips leading/trailing whitespace
    /// - Normalizes line endings
    /// - No LLM call (instant execution)
    static let quickFix = Self(
        "quickFix",
        default: .init(.v, modifiers: [.command, .option])
    )

    /// Smart Fix transformation: LLM-based intelligent transformation.
    ///
    /// Default shortcut: Cmd+Option+S
    /// - Uses configured LLM provider
    /// - Context-aware text cleanup
    /// - Slower but more intelligent
    static let smartFix = Self(
        "smartFix",
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
