import MenuBarExtraAccess
import OptimusClipCore
import SwiftUI

/// Main entry point for Optimus Clip.
///
/// This menu bar app uses MenuBarExtra to display a clipboard icon
/// in the system menu bar. The app runs as an accessory (no Dock icon)
/// and provides quick access to clipboard transformations via hotkeys.
@main
struct OptimusClipApp: App {
    /// Bridge to AppKit for setting activation policy and lifecycle events.
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// Observable state manager for menu bar icon appearance.
    @StateObject private var menuBarState = MenuBarStateManager()

    var body: some Scene {
        MenuBarExtra {
            Button("Settings...") {
                self.showSettingsPlaceholder()
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit Optimus Clip") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        } label: {
            // Dynamic icon with state-based opacity and pulse animation
            Image(systemName: "clipboard.fill")
                .symbolEffect(
                    .pulse.byLayer,
                    options: .repeating,
                    isActive: self.menuBarState.iconState == .processing
                )
                .opacity(self.menuBarState.iconOpacity)
                .accessibilityLabel(self.accessibilityLabel)
        }
        .menuBarExtraStyle(.menu)
        .menuBarExtraAccess(isPresented: self.$menuBarState.isMenuPresented) { statusItem in
            self.menuBarState.configureStatusItem(statusItem)
        }
    }

    /// Accessibility label describing the current icon state.
    private var accessibilityLabel: String {
        switch self.menuBarState.iconState {
        case .idle:
            "Optimus Clip"
        case .disabled:
            "Optimus Clip (Disabled)"
        case .processing:
            "Optimus Clip (Processing)"
        }
    }

    // MARK: - Menu Actions

    /// Shows a placeholder alert for Settings until Phase 2 implements the Settings window.
    private func showSettingsPlaceholder() {
        let alert = NSAlert()
        alert.messageText = "Settings"
        alert.informativeText = "Settings window will be implemented in Phase 2."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
