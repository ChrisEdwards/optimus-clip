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
    func applicationDidFinishLaunching(_: Notification) {
        // Set activation policy to accessory (no Dock icon)
        NSApp.setActivationPolicy(.accessory)

        // Enforce single instance (defense in depth with LSMultipleInstancesProhibited)
        self.enforceSingleInstance()
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
