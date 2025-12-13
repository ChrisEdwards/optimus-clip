import MenuBarExtraAccess
import OptimusClipCore
import SwiftUI

/// Main entry point for Optimus Clip.
///
/// This menu bar app uses MenuBarExtra to display a clipboard icon
/// in the system menu bar. The app runs as an accessory (no Dock icon)
/// and provides quick access to clipboard transformations via hotkeys.
///
/// ## Scenes
/// - **MenuBarExtra**: Primary menu bar icon with dropdown menu
/// - **Settings**: Native settings window opened via Cmd+, or menu item
@main
struct OptimusClipApp: App {
    /// Bridge to AppKit for setting activation policy and lifecycle events.
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// Observable state manager for menu bar icon appearance.
    @StateObject private var menuBarState = MenuBarStateManager()

    var body: some Scene {
        // Primary menu bar scene
        MenuBarExtra {
            Button("Settings...") {
                self.openSettings()
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

        // Settings window scene (native macOS settings pattern)
        Settings {
            SettingsView()
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

    /// Opens the Settings window and brings it to the foreground.
    ///
    /// Uses the native macOS settings window mechanism which provides:
    /// - Automatic Cmd+, shortcut handling
    /// - Single window enforcement (only one settings window can be open)
    /// - Window state restoration across app launches
    private func openSettings() {
        // Use the native settings window selector
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)

        // Bring app to foreground since we're in accessory mode (no Dock icon)
        NSApp.activate(ignoringOtherApps: true)
    }
}
