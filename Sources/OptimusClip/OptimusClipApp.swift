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
            MenuBarMenuContent()
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
        // Remove default Edit menu to prevent Cmd+Option+V conflict with our global hotkey
        .commands {
            CommandGroup(replacing: .pasteboard) {}
            CommandGroup(replacing: .undoRedo) {}
            CommandGroup(replacing: .textEditing) {}
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
}

// MARK: - Menu Bar Menu Content

/// Content view for the menu bar dropdown menu.
///
/// Extracted to a separate View to enable use of `@Environment(\.openSettings)`.
private struct MenuBarMenuContent: View {
    /// Environment action to open the Settings window.
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Settings...") {
            // Bring app to foreground since we're in accessory mode (no Dock icon)
            NSApp.activate(ignoringOtherApps: true)
            self.openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Quit Optimus Clip") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
