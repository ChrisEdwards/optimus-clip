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
        #expect(machine.iconOpacity == 1.0)
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

    @Test("setDisabled toggles correctly")
    func toggleDisabled() {
        var machine = IconStateMachine()

        // Start idle
        #expect(machine.state == .idle)

        // Disable
        machine.setDisabled(true)
        #expect(machine.state == .disabled)

        // Re-enable
        machine.setDisabled(false)
        #expect(machine.state == .idle)

        // Disable again
        machine.setDisabled(true)
        #expect(machine.state == .disabled)
    }
}
