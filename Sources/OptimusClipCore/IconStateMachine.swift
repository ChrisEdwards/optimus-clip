/// Pure state machine for menu bar icon states.
///
/// This struct contains the testable logic for icon state transitions.
/// It is wrapped by `MenuBarStateManager` in the main app target to add
/// SwiftUI `@Published` bindings.
///
/// ## States
/// - **idle**: Normal operation, transformations enabled
/// - **disabled**: Transformations disabled by user (dimmed icon)
/// - **processing**: Transformation in progress (pulsing icon)
public struct IconStateMachine: Sendable {
    /// Icon states for visual feedback.
    public enum State: Sendable, Equatable {
        case idle
        case disabled
        case processing
    }

    /// Current icon state.
    public private(set) var state: State = .idle

    /// Trigger ID for pulse animation. Increment to start a new pulse cycle.
    public private(set) var pulseID: Int = 0

    /// Creates a new icon state machine in idle state.
    public init() {}

    // MARK: - Computed Properties

    /// Computed opacity based on current icon state.
    ///
    /// - Returns: 1.0 for idle/processing, 0.45 for disabled.
    public var iconOpacity: Double {
        switch self.state {
        case .idle, .processing:
            1.0
        case .disabled:
            0.45
        }
    }

    /// Whether processing is currently active.
    public var isProcessing: Bool {
        self.state == .processing
    }

    // MARK: - State Transitions

    /// Transitions to processing state and increments pulse ID.
    ///
    /// Call this when starting a clipboard transformation or LLM request.
    /// Ignored when disabled.
    ///
    /// - Returns: True if transition occurred, false if ignored.
    @discardableResult
    public mutating func startProcessing() -> Bool {
        guard self.state != .disabled else { return false }
        self.state = .processing
        self.pulseID += 1
        return true
    }

    /// Transitions from processing back to idle state.
    ///
    /// Call this when a transformation completes (success or failure).
    /// Only transitions if currently in processing state.
    ///
    /// - Returns: True if transition occurred, false if not in processing state.
    @discardableResult
    public mutating func stopProcessing() -> Bool {
        guard self.state == .processing else { return false }
        self.state = .idle
        return true
    }

    /// Sets the disabled state.
    ///
    /// - Parameter disabled: If true, transitions to disabled; if false, returns to idle
    ///   (only if currently disabled, to avoid interrupting processing).
    public mutating func setDisabled(_ disabled: Bool) {
        if disabled {
            self.state = .disabled
        } else if self.state == .disabled {
            self.state = .idle
        }
    }
}
