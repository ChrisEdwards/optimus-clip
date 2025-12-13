import AppKit
import OptimusClipCore
import SwiftUI

/// Manages menu bar icon state and appearance.
///
/// This observable object wraps `IconStateMachine` to provide SwiftUI bindings
/// for reactive UI updates. It coordinates icon state changes (idle, disabled)
/// across the entire app lifecycle.
///
/// ## States
/// - **Idle**: Full opacity, normal operation
/// - **Disabled**: Dimmed (0.45 opacity), monitoring paused
@MainActor
final class MenuBarStateManager: ObservableObject {
    /// Whether the menu is currently presented (open).
    @Published var isMenuPresented: Bool = false

    /// The underlying state machine (testable in OptimusClipCore).
    @Published private(set) var stateMachine = IconStateMachine()

    // MARK: - Forwarded Properties

    /// Current icon state.
    var iconState: IconStateMachine.State {
        self.stateMachine.state
    }

    /// Computed opacity based on current icon state.
    var iconOpacity: Double {
        self.stateMachine.iconOpacity
    }

    // MARK: - State Transitions

    /// Sets the disabled state for the icon.
    ///
    /// - Parameter disabled: If true, dims the icon; if false, returns to idle.
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
