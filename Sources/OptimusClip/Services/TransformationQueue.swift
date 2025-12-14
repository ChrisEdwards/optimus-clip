import Foundation

/// Identifies a single transformation request and its lifecycle metadata.
public struct TransformationRequest: Sendable, Equatable {
    public enum Source: Sendable, Equatable {
        case pipeline
        case single(transformationId: String)
    }

    public let id: UUID
    public let startedAt: Date
    public let timeout: TimeInterval
    public let source: Source

    public init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        timeout: TimeInterval,
        source: Source
    ) {
        self.id = id
        self.startedAt = startedAt
        self.timeout = timeout
        self.source = source
    }
}

/// Outcome of a completed transformation request.
public struct TransformationFlowOutcome: Sendable, Equatable {
    public let request: TransformationRequest
    public let originalText: String
    public let transformedText: String
    public let finishedAt: Date

    public init(
        request: TransformationRequest,
        originalText: String,
        transformedText: String,
        finishedAt: Date = .now
    ) {
        self.request = request
        self.originalText = originalText
        self.transformedText = transformedText
        self.finishedAt = finishedAt
    }
}

/// Actor that serializes transformation execution and coordinates cancellation.
public actor TransformationQueue {
    /// Currently active request, if any.
    private(set) var currentRequest: TransformationRequest?

    /// Handle to the running transformation task.
    private var currentTask: Task<TransformationFlowOutcome, Error>?

    /// Whether a transformation is in flight.
    public var isProcessing: Bool {
        self.currentTask != nil
    }

    /// Begin tracking a transformation task.
    ///
    /// - Parameters:
    ///   - request: Metadata describing the transformation.
    ///   - task: The task performing the work.
    /// - Throws: `TransformationFlowError.alreadyProcessing` if another task is running.
    public func start(
        request: TransformationRequest,
        task: Task<TransformationFlowOutcome, Error>
    ) throws {
        guard self.currentTask == nil else {
            throw TransformationFlowError.alreadyProcessing
        }

        self.currentRequest = request
        self.currentTask = task
    }

    /// Return the current task handle, if present.
    public func task() -> Task<TransformationFlowOutcome, Error>? {
        self.currentTask
    }

    /// Returns the active request, if any.
    public func request() -> TransformationRequest? {
        self.currentRequest
    }

    /// Cancel the active task and clear state.
    public func cancel() {
        self.currentTask?.cancel()
        self.currentTask = nil
        self.currentRequest = nil
    }

    /// Clear state after completion.
    public func finish() {
        self.currentTask = nil
        self.currentRequest = nil
    }
}
