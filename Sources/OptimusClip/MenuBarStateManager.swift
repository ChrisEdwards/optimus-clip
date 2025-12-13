import AppKit
import SwiftUI

/// Manages menu bar icon state and appearance.
///
/// This observable object tracks icon state (idle, processing, error)
/// and provides access to the underlying NSStatusItem for customization.
///
/// Phase 1: Basic state management stub.
/// Phase 2: Will add processing state for clipboard transformations.
@MainActor
final class MenuBarStateManager: ObservableObject {
    /// Whether the menu is currently presented (open).
    @Published var isMenuPresented: Bool = false

    /// Current icon state.
    @Published var iconState: IconState = .idle

    /// Icon states for visual feedback.
    enum IconState: Sendable {
        case idle
        case processing
        case error
    }

    /// Configure the status item appearance.
    /// - Parameter statusItem: The NSStatusItem to configure.
    func configureStatusItem(_ statusItem: NSStatusItem) {
        // Phase 1: Basic configuration
        // Phase 2: Will add pulse animation and state-based icon changes
        statusItem.button?.toolTip = "Optimus Clip"
    }
}
