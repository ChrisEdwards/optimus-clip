import OptimusClip
import Testing

@Suite("ClipboardMonitor lifecycle")
struct ClipboardMonitorLifecycleTests {
    @MainActor
    @Test("Stopping after suspend resumes before cancel")
    func stopAfterSuspendDoesNotCrash() {
        let monitor = ClipboardMonitor()
        monitor.startMonitoring()
        monitor.suspend()

        monitor.stopMonitoring()

        #expect(monitor.isMonitoring == false)
        #expect(monitor.isSuspended == false)
    }

    @MainActor
    @Test("Deinit after suspend does not crash")
    func deinitAfterSuspendDoesNotCrash() {
        var monitor: ClipboardMonitor? = ClipboardMonitor()
        monitor?.startMonitoring()
        monitor?.suspend()

        monitor = nil

        #expect(Bool(true)) // Passes if no crash during deinit
    }
}
