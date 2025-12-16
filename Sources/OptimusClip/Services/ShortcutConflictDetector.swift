import AppKit
import Foundation
import KeyboardShortcuts

// MARK: - Conflict Types

/// Severity level for keyboard shortcut conflicts.
///
/// Determines UI treatment:
/// - `.critical`: Block assignment, show error
/// - `.system`: Allow with warning, could break system functionality
/// - `.internal`: Allow with warning, conflicts with another transformation
/// - `.common`: Allow with info, might interfere with other apps
enum ShortcutConflictSeverity: Int, Comparable, Sendable {
    case critical = 3
    case system = 2
    case `internal` = 1
    case common = 0

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Describes a detected keyboard shortcut conflict.
struct ShortcutConflict: Sendable {
    let severity: ShortcutConflictSeverity
    let message: String
    let shortDescription: String

    /// Icon name for the conflict severity.
    var iconName: String {
        switch self.severity {
        case .critical: "xmark.octagon.fill"
        case .system: "exclamationmark.triangle.fill"
        case .internal: "exclamationmark.triangle"
        case .common: "info.circle"
        }
    }
}

// MARK: - Conflict Detector

/// Detects keyboard shortcut conflicts across different categories.
///
/// Use this to validate shortcuts before assignment:
/// ```swift
/// let detector = ShortcutConflictDetector(allTransformations: configs)
/// if let conflict = detector.detectConflict(for: shortcut, excludingTransformation: currentId) {
///     // Show warning/error based on conflict.severity
/// }
/// ```
struct ShortcutConflictDetector: Sendable {
    // MARK: - Critical Shortcuts (Block)

    /// Shortcuts that would break fundamental system functionality.
    /// These should never be assigned to transformations.
    private static let criticalShortcuts: Set<ShortcutKey> = [
        ShortcutKey(key: .c, modifiers: .command), // Copy
        ShortcutKey(key: .v, modifiers: .command), // Paste
        ShortcutKey(key: .x, modifiers: .command), // Cut
        ShortcutKey(key: .z, modifiers: .command), // Undo
        ShortcutKey(key: .q, modifiers: .command), // Quit
        ShortcutKey(key: .w, modifiers: .command), // Close window
        ShortcutKey(key: .a, modifiers: .command), // Select all
        ShortcutKey(key: .h, modifiers: .command), // Hide
        ShortcutKey(key: .m, modifiers: .command), // Minimize
        ShortcutKey(key: .n, modifiers: .command) // New window
    ]

    // MARK: - System Shortcuts (Warn)

    /// macOS system shortcuts that could interfere with OS functionality.
    private static let systemShortcuts: [ShortcutKey: String] = [
        ShortcutKey(key: .space, modifiers: .command): "Spotlight",
        ShortcutKey(key: .tab, modifiers: .command): "App Switcher",
        ShortcutKey(key: .space, modifiers: [.command, .shift]): "Screenshot Menu",
        ShortcutKey(key: .three, modifiers: [.command, .shift]): "Screenshot",
        ShortcutKey(key: .four, modifiers: [.command, .shift]): "Screenshot Selection",
        ShortcutKey(key: .five, modifiers: [.command, .shift]): "Screenshot Options",
        ShortcutKey(key: .escape, modifiers: [.command, .option]): "Force Quit",
        ShortcutKey(key: .delete, modifiers: [.command, .shift]): "Empty Trash"
    ]

    // MARK: - Common App Shortcuts (Inform)

    /// Shortcuts commonly used by other applications.
    private static let commonAppShortcuts: [ShortcutKey: String] = [
        ShortcutKey(key: .s, modifiers: .command): "Save",
        ShortcutKey(key: .p, modifiers: .command): "Print",
        ShortcutKey(key: .f, modifiers: .command): "Find",
        ShortcutKey(key: .o, modifiers: .command): "Open",
        ShortcutKey(key: .t, modifiers: .command): "New Tab",
        ShortcutKey(key: .r, modifiers: .command): "Reload",
        ShortcutKey(key: .comma, modifiers: .command): "Preferences",
        ShortcutKey(key: .z, modifiers: [.command, .shift]): "Redo",
        ShortcutKey(key: .s, modifiers: [.command, .shift]): "Save As",
        ShortcutKey(key: .g, modifiers: .command): "Find Next"
    ]

    // MARK: - State

    /// All transformations in the app, used for internal conflict detection.
    private let allTransformations: [TransformationConfig]

    /// Creates a conflict detector with the current set of transformations.
    ///
    /// - Parameter allTransformations: All transformation configs to check against.
    init(allTransformations: [TransformationConfig] = []) {
        self.allTransformations = allTransformations
    }

    // MARK: - Detection

    /// Detects any conflict for the given shortcut.
    ///
    /// Returns the highest-severity conflict found, or nil if the shortcut is safe.
    ///
    /// - Parameters:
    ///   - shortcut: The keyboard shortcut to validate.
    ///   - excludingTransformation: Optional ID to exclude from internal conflict check
    ///     (use when validating an edit to an existing transformation).
    /// - Returns: The detected conflict, or nil if shortcut is safe.
    func detectConflict(
        for shortcut: KeyboardShortcuts.Shortcut,
        excludingTransformation: UUID? = nil
    ) -> ShortcutConflict? {
        let key = ShortcutKey(shortcut: shortcut)

        // Check in order of severity
        if let conflict = self.checkCritical(key) {
            return conflict
        }
        if let conflict = self.checkSystem(key) {
            return conflict
        }
        if let conflict = self.checkInternal(shortcut, excludingTransformation: excludingTransformation) {
            return conflict
        }
        if let conflict = self.checkCommon(key) {
            return conflict
        }

        return nil
    }

    // MARK: - Private Checks

    private func checkCritical(_ key: ShortcutKey) -> ShortcutConflict? {
        guard Self.criticalShortcuts.contains(key) else { return nil }
        return ShortcutConflict(
            severity: .critical,
            message: """
            This shortcut (\(key.displayString)) is essential for system clipboard \
            operations and cannot be overridden.
            """,
            shortDescription: "Reserved system shortcut"
        )
    }

    private func checkSystem(_ key: ShortcutKey) -> ShortcutConflict? {
        guard let functionName = Self.systemShortcuts[key] else { return nil }
        return ShortcutConflict(
            severity: .system,
            message: """
            This shortcut is used by macOS for \(functionName). Using it may interfere \
            with system functionality.
            """,
            shortDescription: "Used by macOS for \(functionName)"
        )
    }

    private func checkInternal(
        _ shortcut: KeyboardShortcuts.Shortcut,
        excludingTransformation: UUID?
    ) -> ShortcutConflict? {
        // Check if any other transformation uses this shortcut
        for transformation in self.allTransformations {
            // Skip the transformation being edited
            if transformation.id == excludingTransformation {
                continue
            }

            // Get the shortcut for this transformation
            let name = transformation.shortcutName
            if let existingShortcut = KeyboardShortcuts.getShortcut(for: name),
               existingShortcut == shortcut {
                return ShortcutConflict(
                    severity: .internal,
                    message: """
                    This shortcut is already assigned to "\(transformation.name)". \
                    Both transformations would trigger simultaneously.
                    """,
                    shortDescription: "Conflicts with \"\(transformation.name)\""
                )
            }
        }
        return nil
    }

    private func checkCommon(_ key: ShortcutKey) -> ShortcutConflict? {
        guard let functionName = Self.commonAppShortcuts[key] else { return nil }
        return ShortcutConflict(
            severity: .common,
            message: """
            This shortcut is commonly used by apps for \(functionName). \
            It may interfere with other applications when they're focused.
            """,
            shortDescription: "Commonly used for \(functionName)"
        )
    }
}

// MARK: - Helper Types

/// Hashable key for shortcut comparison.
///
/// Wraps a key and modifier combination for efficient lookup.
/// Uses the raw value of modifiers for hashing since ModifierFlags doesn't conform to Hashable.
private struct ShortcutKey: Hashable, Sendable {
    let keyCode: Int
    let modifierRawValue: UInt

    init(key: KeyboardShortcuts.Key, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = key.rawValue
        // Normalize modifiers to only include relevant flags
        let relevantModifiers = modifiers.intersection([.command, .option, .control, .shift])
        self.modifierRawValue = relevantModifiers.rawValue
    }

    init(shortcut: KeyboardShortcuts.Shortcut) {
        guard let key = shortcut.key else {
            self.keyCode = 0
            self.modifierRawValue = 0
            return
        }
        self.keyCode = key.rawValue
        let relevantModifiers = shortcut.modifiers.intersection([.command, .option, .control, .shift])
        self.modifierRawValue = relevantModifiers.rawValue
    }

    /// Human-readable shortcut string (e.g., "⌘C").
    var displayString: String {
        let modifiers = NSEvent.ModifierFlags(rawValue: self.modifierRawValue)
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }

        // Map key code to display character
        let keyChar = self.keyCharacter
        parts.append(keyChar)
        return parts.joined()
    }

    /// Gets a display character for the key code.
    private var keyCharacter: String {
        // Common key mappings for display
        switch self.keyCode {
        case 0: "A"
        case 1: "S"
        case 2: "D"
        case 3: "F"
        case 4: "H"
        case 5: "G"
        case 6: "Z"
        case 7: "X"
        case 8: "C"
        case 9: "V"
        case 11: "B"
        case 12: "Q"
        case 13: "W"
        case 14: "E"
        case 15: "R"
        case 16: "Y"
        case 17: "T"
        case 18: "1"
        case 19: "2"
        case 20: "3"
        case 21: "4"
        case 22: "6"
        case 23: "5"
        case 24: "="
        case 25: "9"
        case 26: "7"
        case 27: "-"
        case 28: "8"
        case 29: "0"
        case 30: "]"
        case 31: "O"
        case 32: "U"
        case 33: "["
        case 34: "I"
        case 35: "P"
        case 36: "↩"
        case 37: "L"
        case 38: "J"
        case 39: "'"
        case 40: "K"
        case 41: ";"
        case 42: "\\"
        case 43: ","
        case 44: "/"
        case 45: "N"
        case 46: "M"
        case 47: "."
        case 48: "⇥"
        case 49: "Space"
        case 51: "⌫"
        case 53: "⎋"
        default: "Key\(self.keyCode)"
        }
    }
}
