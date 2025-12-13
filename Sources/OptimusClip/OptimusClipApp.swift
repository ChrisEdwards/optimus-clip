import MenuBarExtraAccess
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
        MenuBarExtra("Optimus Clip", systemImage: "clipboard.fill") {
            // Placeholder menu content - will be replaced in oc-uzt.4
            Button("Settings...") {
                // Phase 3: Open settings window
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit Optimus Clip") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .menuBarExtraStyle(.menu)
        .menuBarExtraAccess(isPresented: self.$menuBarState.isMenuPresented) { statusItem in
            self.menuBarState.configureStatusItem(statusItem)
        }
    }
}
