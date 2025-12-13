import AppKit
import OptimusClipCore
import SwiftUI

/// Manages menu bar icon state and appearance.
///
/// This observable object wraps `IconStateMachine` to provide SwiftUI bindings
/// for reactive UI updates. It coordinates all icon state changes (idle, disabled,
/// processing) and animations across the entire app lifecycle.
///
/// ## States
/// - **Idle**: Full opacity, normal operation
/// - **Disabled**: Dimmed (0.45 opacity), monitoring paused
/// - **Processing**: Full opacity with pulse animation, transformation in progress
@MainActor
final class MenuBarStateManager: ObservableObject {
    /// Whether the menu is currently presented (open).
    @Published var isMenuPresented: Bool = false

    /// The underlying state machine (testable in OptimusClipCore).
    @Published private(set) var stateMachine = IconStateMachine()

    // MARK: - Initialization

    /// Creates a new menu bar state manager and registers with HotkeyManager.
    ///
    /// This connects the state manager to the hotkey system so that transformation
    /// processing triggers the pulse animation via startProcessing/stopProcessing.
    init() {
        HotkeyManager.shared.menuBarStateManager = self
    }

    // MARK: - Forwarded Properties

    /// Current icon state.
    var iconState: IconStateMachine.State {
        self.stateMachine.state
    }

    /// Trigger ID for pulse animation.
    var pulseID: Int {
        self.stateMachine.pulseID
    }

    /// Computed opacity based on current icon state.
    var iconOpacity: Double {
        self.stateMachine.iconOpacity
    }

    /// Whether processing is currently active.
    var isProcessing: Bool {
        self.stateMachine.isProcessing
    }

    // MARK: - State Transitions

    /// Transitions to processing state and triggers pulse animation.
    ///
    /// Call this when starting a clipboard transformation or LLM request.
    /// Ignored if already processing or when disabled.
    func startProcessing() {
        self.stateMachine.startProcessing()
    }

    /// Transitions from processing back to idle state.
    ///
    /// Call this when a transformation completes (success or failure).
    /// Only transitions if currently in processing state.
    func stopProcessing() {
        self.stateMachine.stopProcessing()
    }

    /// Sets the disabled state for the icon.
    ///
    /// - Parameter disabled: If true, dims the icon; if false, returns to idle.
    ///
    /// Note: Only transitions to idle from disabled state. This prevents
    /// interrupting an in-progress transformation.
    func setDisabled(_ disabled: Bool) {
        self.stateMachine.setDisabled(disabled)
    }

    // MARK: - NSStatusItem Configuration

    /// Configure the status item appearance.
    ///
    /// - Parameter statusItem: The NSStatusItem to configure.
    func configureStatusItem(_ statusItem: NSStatusItem) {
        statusItem.button?.toolTip = "Optimus Clip"
    }
}
