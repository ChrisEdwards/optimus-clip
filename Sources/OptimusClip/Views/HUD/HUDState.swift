import Foundation

/// Represents the current state of a transformation operation displayed in the HUD.
enum HUDState: Equatable, Sendable {
    /// Initial state when hotkey is pressed, before any processing begins.
    case starting

    /// Establishing connection to the LLM provider.
    case connecting(provider: String)

    /// Request has been sent, waiting for response.
    case sending

    /// Receiving response from the LLM.
    /// - Parameter elapsedSeconds: Time elapsed since the operation started.
    case receiving(elapsedSeconds: Double)

    /// Operation completed successfully.
    case success

    /// Operation failed with an error.
    /// - Parameter message: Human-readable error description.
    case error(message: String)

    /// Operation was cancelled by the user (via Esc key).
    case cancelled

    /// Status text to display in the HUD.
    var statusText: String {
        switch self {
        case .starting:
            "Starting..."
        case let .connecting(provider):
            "Connecting to \(provider)..."
        case .sending:
            "Sending..."
        case let .receiving(elapsed):
            "Receiving... (\(Self.formatElapsed(elapsed)))"
        case .success:
            "Done!"
        case let .error(message):
            "Error: \(message)"
        case .cancelled:
            "Cancelled"
        }
    }

    /// Whether this state represents a terminal state (success, error, or cancelled).
    var isTerminal: Bool {
        switch self {
        case .success, .error, .cancelled:
            true
        case .starting, .connecting, .sending, .receiving:
            false
        }
    }

    /// How long the HUD should remain visible after reaching this state.
    var dismissDelay: TimeInterval {
        switch self {
        case .success:
            1.5
        case .error:
            3.0
        case .cancelled:
            1.0
        case .starting, .connecting, .sending, .receiving:
            0 // Don't auto-dismiss while in progress
        }
    }

    /// Formats elapsed seconds for display (e.g., "2.3s").
    private static func formatElapsed(_ seconds: Double) -> String {
        String(format: "%.1fs", seconds)
    }
}
