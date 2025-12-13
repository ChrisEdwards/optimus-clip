/// Pure state machine for menu bar icon states.
///
/// This struct contains the testable logic for icon state transitions.
/// It is wrapped by `MenuBarStateManager` in the main app target to add
/// SwiftUI `@Published` bindings.
///
/// ## States
/// - **idle**: Normal operation, transformations enabled
/// - **disabled**: Transformations disabled by user (dimmed icon)
public struct IconStateMachine: Sendable {
    /// Icon states for visual feedback.
    public enum State: Sendable, Equatable {
        case idle
        case disabled
    }

    /// Current icon state.
    public private(set) var state: State = .idle

    /// Creates a new icon state machine in idle state.
    public init() {}

    // MARK: - Computed Properties

    /// Computed opacity based on current icon state.
    ///
    /// - Returns: 1.0 for idle, 0.45 for disabled.
    public var iconOpacity: Double {
        switch self.state {
        case .idle:
            1.0
        case .disabled:
            0.45
        }
    }

    // MARK: - State Transitions

    /// Sets the disabled state.
    ///
    /// - Parameter disabled: If true, transitions to disabled; if false, returns to idle.
    public mutating func setDisabled(_ disabled: Bool) {
        self.state = disabled ? .disabled : .idle
    }
}
