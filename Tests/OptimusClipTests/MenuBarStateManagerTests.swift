import Testing
@testable import OptimusClipCore

/// Tests for IconStateMachine, the pure state logic for menu bar icon states.
///
/// These tests verify the testable state machine that underlies MenuBarStateManager.
@Suite("IconStateMachine Tests")
struct IconStateMachineTests {
    @Test("Initial state is idle")
    func initialState() {
        let machine = IconStateMachine()
        #expect(machine.state == .idle)
        #expect(machine.pulseID == 0)
        #expect(machine.iconOpacity == 1.0)
        #expect(!machine.isProcessing)
    }

    @Test("startProcessing transitions to processing and increments pulseID")
    func startProcessing() {
        var machine = IconStateMachine()
        let result = machine.startProcessing()
        #expect(result == true)
        #expect(machine.state == .processing)
        #expect(machine.pulseID == 1)
        #expect(machine.isProcessing)
    }

    @Test("stopProcessing returns to idle")
    func stopProcessing() {
        var machine = IconStateMachine()
        machine.startProcessing()
        let result = machine.stopProcessing()
        #expect(result == true)
        #expect(machine.state == .idle)
        #expect(!machine.isProcessing)
    }

    @Test("setDisabled dims icon opacity")
    func setDisabled() {
        var machine = IconStateMachine()
        machine.setDisabled(true)
        #expect(machine.state == .disabled)
        #expect(machine.iconOpacity == 0.45)
    }

    @Test("setDisabled(false) returns to idle")
    func reEnable() {
        var machine = IconStateMachine()
        machine.setDisabled(true)
        machine.setDisabled(false)
        #expect(machine.state == .idle)
        #expect(machine.iconOpacity == 1.0)
    }

    @Test("startProcessing ignored when disabled")
    func noProcessingWhenDisabled() {
        var machine = IconStateMachine()
        machine.setDisabled(true)
        let result = machine.startProcessing()
        #expect(result == false)
        #expect(machine.state == .disabled) // Still disabled
        #expect(machine.pulseID == 0) // No pulse triggered
    }

    @Test("pulseID increments on each startProcessing")
    func multiplePulses() {
        var machine = IconStateMachine()
        machine.startProcessing()
        machine.stopProcessing()
        machine.startProcessing()
        #expect(machine.pulseID == 2)
    }

    @Test("stopProcessing only works when processing")
    func stopProcessingGuard() {
        var machine = IconStateMachine()
        // stopProcessing from idle should be a no-op
        let result1 = machine.stopProcessing()
        #expect(result1 == false)
        #expect(machine.state == .idle)

        // stopProcessing from disabled should be a no-op
        machine.setDisabled(true)
        let result2 = machine.stopProcessing()
        #expect(result2 == false)
        #expect(machine.state == .disabled)
    }

    @Test("setDisabled(false) does not interrupt processing")
    func setDisabledFalseWhileProcessing() {
        var machine = IconStateMachine()
        machine.startProcessing()
        machine.setDisabled(false) // Should not change state
        #expect(machine.state == .processing)
        #expect(machine.isProcessing)
    }
}
