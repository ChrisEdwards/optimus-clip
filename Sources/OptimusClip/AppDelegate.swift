import AppKit

/// Application delegate for Optimus Clip.
///
/// Handles app lifecycle events and sets activation policy to accessory
/// so the app runs as a menu bar utility without a Dock icon.
///
/// Phase 1: Basic setup with accessory activation policy and single instance enforcement.
/// Phase 3: Will add hotkey registration in applicationDidFinishLaunching.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Tracks windows that were visible before app resigned active.
    private var windowsToRestore: [NSWindow] = []

    /// Bundle ID of System Settings (System Preferences on older macOS).
    private let systemSettingsBundleID = "com.apple.systempreferences"

    func applicationDidFinishLaunching(_: Notification) {
        // Set activation policy to accessory (no Dock icon)
        NSApp.setActivationPolicy(.accessory)

        // Enforce single instance (defense in depth with LSMultipleInstancesProhibited)
        self.enforceSingleInstance()

        // Register built-in hotkeys (Clean Terminal Text, Format As Markdown)
        HotkeyManager.shared.registerBuiltInShortcuts()

        // Register saved user transformations
        let savedTransformations = self.loadSavedTransformations()
        HotkeyManager.shared.registerAll(transformations: savedTransformations)

        // Observe app activation to restore windows (fixes Settings window closing issue)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleWillResignActive),
            name: NSApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.handleDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        // Also watch for System Settings termination to restore windows
        // (Menu bar apps don't become "active" when other apps close)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(self.handleAppTerminated),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
    }

    @objc private func handleWillResignActive(_: Notification) {
        // Remember which windows were visible before losing focus
        self.windowsToRestore = NSApp.windows.filter { $0.isVisible && !$0.isMiniaturized }
    }

    @objc private func handleDidBecomeActive(_: Notification) {
        // Restore windows that were visible before losing focus
        for window in self.windowsToRestore {
            window.makeKeyAndOrderFront(nil)
        }
        self.windowsToRestore = []
    }

    @objc private func handleAppTerminated(_ notification: Notification) {
        // When System Settings closes, restore our windows
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == self.systemSettingsBundleID,
              !self.windowsToRestore.isEmpty else {
            return
        }

        // Small delay to let the window manager settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)
            for window in self.windowsToRestore {
                window.makeKeyAndOrderFront(nil)
            }
            self.windowsToRestore = []
        }
    }

    /// Loads saved transformations from UserDefaults.
    ///
    /// Returns default transformations on first launch so they get registered with HotkeyManager.
    private func loadSavedTransformations() -> [TransformationConfig] {
        guard let data = UserDefaults.standard.data(forKey: "transformations_data"),
              !data.isEmpty,
              let transformations = try? JSONDecoder().decode([TransformationConfig].self, from: data) else {
            return TransformationConfig.defaultTransformations
        }
        return transformations
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        // Menu bar apps should not terminate when windows close
        false
    }

    func applicationWillTerminate(_: Notification) {
        // Cleanup hook for future phases:
        // - Phase 2: Stop clipboard monitoring
        // - Phase 4: Cancel in-flight LLM requests
        // - Phase 6: Persist state before exit
    }

    // MARK: - Single Instance Enforcement

    /// Ensures only one instance of Optimus Clip can run at a time.
    ///
    /// This provides defense in depth beyond LSMultipleInstancesProhibited in Info.plist,
    /// which can be bypassed with `open -n`. If a duplicate instance is detected,
    /// shows an alert and terminates.
    private func enforceSingleInstance() {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.optimusclip"

        // Query kernel for all running instances of this app
        let runningInstances = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == bundleID
        }

        // If count <= 1, we're the only instance (normal case)
        guard runningInstances.count > 1 else {
            return
        }

        // Sort by launch date to find the oldest (first) instance
        let sortedByLaunchDate = runningInstances.sorted {
            ($0.launchDate ?? Date.distantPast) < ($1.launchDate ?? Date.distantPast)
        }

        let firstInstance = sortedByLaunchDate.first
        let currentPID = ProcessInfo.processInfo.processIdentifier

        // If we're not the first instance, we should quit
        if firstInstance?.processIdentifier != currentPID {
            self.showAlreadyRunningAlert(existingInstance: firstInstance)
            NSApp.terminate(nil)
        }
    }

    /// Shows an alert informing the user that another instance is already running.
    ///
    /// - Parameter existingInstance: The running instance to activate after dismissing the alert.
    private func showAlreadyRunningAlert(existingInstance: NSRunningApplication?) {
        let alert = NSAlert()
        alert.messageText = "Optimus Clip is Already Running"
        alert.informativeText = """
        Another instance of Optimus Clip is already running. \
        Only one instance can run at a time to prevent conflicts.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")

        // Run modal (blocks until dismissed)
        alert.runModal()

        // Activate the existing instance so user can see it
        existingInstance?.activate()
    }
}
