import Carbon.HIToolbox
import CoreGraphics

/// Error types for paste simulation failures.
public enum PasteSimulationError: Error, Sendable {
    /// Accessibility permission is not granted.
    case accessibilityNotGranted
    /// Failed to create CGEventSource.
    case eventSourceCreationFailed
    /// Failed to create keyboard event.
    case eventCreationFailed
}

/// Simulates keyboard paste (Cmd+V) using low-level CGEvent APIs.
///
/// ## Background
/// macOS doesn't provide a public API for "paste into any app". We must simulate
/// the keyboard shortcut Cmd+V using CGEvent APIs. This allows Optimus Clip to
/// paste transformed clipboard content into any application.
///
/// ## Requirements
/// - **Accessibility permission**: CGEvent posting requires explicit user permission.
///   Without it, events are silently dropped (no error, nothing happens).
///
/// ## How It Works
/// 1. Create a CGEventSource (represents keyboard state)
/// 2. Create key-down event for 'V' with Command modifier
/// 3. Post the event to the system
/// 4. Create and post key-up event
/// 5. macOS routes these events to the frontmost app -> paste happens
///
/// ## Event Tap Location
/// Uses `.cghidEventTap` (system-wide) so events go to whichever app has focus.
///
/// ## Carbon HIToolbox
/// `kVK_ANSI_V` comes from Carbon's HIToolbox - the virtual key code for 'V' on ANSI keyboards.
/// While Carbon is deprecated, these key code constants remain the official way to reference keys.
///
/// ## Edge Cases
/// - **Keyboard Layout**: `kVK_ANSI_V` is a physical key position, not a character.
///   Works regardless of keyboard layout (QWERTY, Dvorak, etc.).
/// - **Secure Input**: Some apps enable "secure input mode" (password fields, 1Password).
///   CGEvents may be blocked - this is by design for security.
/// - **Full-Screen Apps**: Works as long as accessibility permission is granted.
///
/// ## Usage
/// ```swift
/// let simulator = PasteSimulator()
/// do {
///     try await simulator.paste()
/// } catch PasteSimulationError.accessibilityNotGranted {
///     // Show permission UI
/// }
/// ```
@MainActor
public final class PasteSimulator {
    // MARK: - Singleton

    /// Shared instance for global access.
    public static let shared = PasteSimulator()

    // MARK: - Initialization

    /// Creates a new paste simulator.
    public init() {}

    // MARK: - Public Methods

    /// Simulates Cmd+V paste to the frontmost application.
    ///
    /// - Throws: `PasteSimulationError.accessibilityNotGranted` if accessibility permission is missing.
    /// - Throws: `PasteSimulationError.eventSourceCreationFailed` if CGEventSource creation fails.
    /// - Throws: `PasteSimulationError.eventCreationFailed` if keyboard event creation fails.
    ///
    /// - Note: This is async to allow the caller to handle timing around clipboard writes.
    public func paste() throws {
        // Pre-flight: Verify accessibility permission
        guard AccessibilityPermissionManager.shared.isGranted else {
            throw PasteSimulationError.accessibilityNotGranted
        }

        try self.performPasteSimulation()
    }

    /// Simulates paste if accessibility permission is granted.
    ///
    /// - Returns: `true` if paste was simulated, `false` if permission was denied.
    ///
    /// Use this when you want to silently skip paste simulation rather than throw an error.
    /// Useful for graceful degradation.
    @discardableResult
    public func pasteIfAllowed() -> Bool {
        guard AccessibilityPermissionManager.shared.isGranted else {
            return false
        }

        do {
            try self.performPasteSimulation()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Private Methods

    /// Performs the actual CGEvent-based paste simulation.
    ///
    /// - Throws: `PasteSimulationError.eventSourceCreationFailed` if CGEventSource creation fails.
    /// - Throws: `PasteSimulationError.eventCreationFailed` if keyboard event creation fails.
    private func performPasteSimulation() throws {
        // 1. Create event source representing combined session state
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            throw PasteSimulationError.eventSourceCreationFailed
        }

        // 2. Get virtual key code for 'V' from Carbon HIToolbox
        // kVK_ANSI_V = 9 on US keyboard layout (physical position, not character)
        let keyCode = CGKeyCode(kVK_ANSI_V)

        // 3. Create key-down event
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) else {
            throw PasteSimulationError.eventCreationFailed
        }
        // Add Command modifier for Cmd+V
        keyDown.flags = .maskCommand

        // 4. Create key-up event
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            throw PasteSimulationError.eventCreationFailed
        }
        // Must also have Command modifier on key-up
        keyUp.flags = .maskCommand

        // 5. Post events to system-wide HID event tap
        // .cghidEventTap sends to whichever app has keyboard focus
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
