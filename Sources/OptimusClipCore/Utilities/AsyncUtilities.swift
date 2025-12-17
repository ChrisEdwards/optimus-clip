import Foundation

/// Errors that can occur in async utility functions.
public enum AsyncError: LocalizedError, Sendable, Equatable {
    /// Operation exceeded the specified timeout duration.
    case timeout(seconds: Int)

    /// Operation was cancelled before completion.
    case cancelled

    public var errorDescription: String? {
        switch self {
        case let .timeout(seconds):
            "Operation timed out after \(seconds) seconds"
        case .cancelled:
            "Operation was cancelled"
        }
    }
}

/// Execute an async operation with a timeout.
///
/// - Parameters:
///   - duration: Maximum time to wait for the operation to complete.
///   - operation: The async operation to execute.
/// - Returns: The result of the operation if it completes within the timeout.
/// - Throws: `AsyncError.timeout` if the operation exceeds the duration,
///           `AsyncError.cancelled` if the operation group is cancelled,
///           or any error thrown by the operation itself.
public func withTimeout<T: Sendable>(
    _ duration: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Add the main operation
        group.addTask {
            try await operation()
        }

        // Add timeout task
        group.addTask {
            try await Task.sleep(for: .seconds(duration))
            throw AsyncError.timeout(seconds: Int(duration))
        }

        // Return first result (operation or timeout)
        guard let result = try await group.next() else {
            throw AsyncError.cancelled
        }

        // Cancel remaining tasks
        group.cancelAll()

        return result
    }
}

/// Execute an async operation with a timeout, using a custom timeout error.
///
/// - Parameters:
///   - duration: Maximum time to wait for the operation to complete.
///   - timeoutError: Error to throw when timeout occurs.
///   - operation: The async operation to execute.
/// - Returns: The result of the operation if it completes within the timeout.
/// - Throws: The provided `timeoutError` if the operation exceeds the duration,
///           or any error thrown by the operation itself.
public func withTimeout<T: Sendable>(
    _ duration: TimeInterval,
    timeoutError: @autoclosure @escaping @Sendable () -> any Error,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Add the main operation
        group.addTask {
            try await operation()
        }

        // Add timeout task
        group.addTask {
            try await Task.sleep(for: .seconds(duration))
            throw timeoutError()
        }

        // Return first result (operation or timeout)
        guard let result = try await group.next() else {
            throw timeoutError()
        }

        // Cancel remaining tasks
        group.cancelAll()

        return result
    }
}
