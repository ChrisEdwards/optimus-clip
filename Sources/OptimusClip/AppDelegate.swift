import AppKit

/// Application delegate for Optimus Clip.
///
/// Handles app lifecycle events and sets activation policy to accessory
/// so the app runs as a menu bar utility without a Dock icon.
///
/// Phase 1: Basic setup with accessory activation policy.
/// Phase 3: Will add hotkey registration in applicationDidFinishLaunching.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        // Set activation policy to accessory (no Dock icon)
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        // Menu bar apps should not terminate when windows close
        false
    }
}
