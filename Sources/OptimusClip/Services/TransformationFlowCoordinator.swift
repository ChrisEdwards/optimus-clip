import AppKit
import Foundation
import OptimusClipCore

/// Represents lifecycle states for transformation execution.
public enum TransformationProcessingState: Sendable {
    case idle
    case processing(request: TransformationRequest)
    case completed(outcome: TransformationFlowOutcome)
    case failed(request: TransformationRequest, error: TransformationFlowError)
    case cancelled(request: TransformationRequest)
}

/// Errors specific to the transformation flow.
public enum TransformationFlowError: Error, Sendable {
    /// Accessibility permission is not granted (required for paste simulation).
    case accessibilityPermissionRequired

    /// Clipboard is empty.
    case clipboardEmpty

    /// Clipboard contains binary content that cannot be transformed.
    case binaryContent(type: String)

    /// Detected our own write (self-write marker present).
    case selfWriteDetected

    /// No text content could be read from clipboard.
    case noTextContent

    /// Transformation failed.
    case transformationFailed(Error)

    /// Clipboard write failed.
    case clipboardWriteFailed(Error)

    /// Paste simulation failed.
    case pasteSimulationFailed(Error)

    /// A transformation is already in progress.
    case alreadyProcessing

    /// User-friendly error message.
    public var message: String {
        switch self {
        case .accessibilityPermissionRequired:
            "Accessibility permission is required to paste transformed content"
        case .clipboardEmpty:
            "Clipboard is empty"
        case let .binaryContent(type):
            "Cannot transform \(ClipboardContentType.friendlyTypeName(for: type)) - only text content is supported"
        case .selfWriteDetected:
            "Content was already transformed by Optimus Clip"
        case .noTextContent:
            "No text content found on clipboard"
        case let .transformationFailed(error):
            "Transformation failed: \(error.localizedDescription)"
        case let .clipboardWriteFailed(error):
            "Failed to write to clipboard: \(error.localizedDescription)"
        case let .pasteSimulationFailed(error):
            "Failed to paste: \(error.localizedDescription)"
        case .alreadyProcessing:
            "A transformation is already in progress"
        }
    }
}

/// Protocol for receiving transformation flow events.
///
/// Implement this to receive notifications about transformation progress,
/// completion, and errors. Useful for updating UI state.
@MainActor
public protocol TransformationFlowDelegate: AnyObject {
    /// Called when transformation processing begins.
    func transformationFlowDidStart()

    /// Called when transformation completes successfully.
    /// - Parameter originalText: The original clipboard text before transformation.
    /// - Parameter transformedText: The transformed text that was pasted.
    func transformationFlowDidComplete(originalText: String, transformedText: String)

    /// Called when transformation fails at any stage.
    /// - Parameter error: The error that occurred.
    func transformationFlowDidFail(error: TransformationFlowError)
}

/// Central orchestrator for the clipboard transformation flow.
///
/// The TransformationFlowCoordinator ties together all Phase 2 components:
/// - ClipboardSafety: Binary content detection
/// - SelfWriteMarker: Infinite loop prevention
/// - ClipboardWriter: Writing with markers
/// - PasteSimulator: Cmd+V simulation
/// - AccessibilityPermissionManager: Permission checks
///
/// ## Flow Sequence
/// When a hotkey is triggered, the coordinator:
/// 1. Checks accessibility permission (required for paste)
/// 2. Checks for self-write marker (skip our own writes)
/// 3. Detects binary content (reject images, files)
/// 4. Reads text from clipboard
/// 5. Transforms content (via Transformation protocol)
/// 6. Writes transformed text with marker
/// 7. Simulates Cmd+V paste
///
/// ## Thread Safety
/// All operations are MainActor-isolated for NSPasteboard safety.
/// The `isProcessing` flag prevents concurrent transformations.
///
/// ## Error Handling
/// Each stage has specific error handling:
/// - Permission errors: Show settings guidance
/// - Binary content: User notification
/// - Transformation errors: Clipboard preserved, user notified
/// - Paste errors: Clipboard has transformed content (manual paste works)
///
/// ## Usage
/// ```swift
/// let coordinator = TransformationFlowCoordinator()
/// coordinator.delegate = self
/// coordinator.transformation = IdentityTransformation()
///
/// // Called when hotkey is pressed
/// await coordinator.handleHotkeyTrigger()
/// ```
@MainActor
public final class TransformationFlowCoordinator: ObservableObject {
    // MARK: - Singleton

    /// Shared instance for global access.
    public static let shared = TransformationFlowCoordinator()

    // MARK: - Configuration

    /// Timeout duration for transformation operations (especially LLM calls).
    public var transformationTimeout: TimeInterval = 30.0

    /// Delay after clipboard write before simulating paste.
    /// Allows clipboard to settle for apps that read clipboard asynchronously.
    public var pasteDelay: TimeInterval = 0.05

    // MARK: - Dependencies

    /// The transformation pipeline to execute.
    /// When set, takes precedence over the single transformation.
    public var pipeline: TransformationPipeline?

    /// The transformation to apply to clipboard content.
    /// Used as fallback when no pipeline is set.
    /// Defaults to IdentityTransformation (no-op).
    public var transformation: any Transformation = IdentityTransformation()

    /// History store used for logging transformation events.
    public var historyStore: HistoryStore?

    /// Delegate for receiving flow events.
    public weak var delegate: TransformationFlowDelegate?

    // MARK: - Error Recovery

    /// Error recovery manager for clipboard preservation and notifications.
    private let errorRecoveryManager = ErrorRecoveryManager.shared

    // MARK: - State

    /// Queue that serializes transformation execution and cancellation.
    private let queue = TransformationQueue()

    /// Whether a transformation is currently in progress.
    /// Used to prevent concurrent transformations.
    @Published public private(set) var isProcessing: Bool = false

    /// Detailed processing state for UI and coordination.
    @Published public private(set) var processingState: TransformationProcessingState = .idle

    /// The last error that occurred, if any.
    @Published public private(set) var lastError: TransformationFlowError?

    /// Captured input text from the current transformation.
    /// Used for failure history logging when transformation fails after reading clipboard.
    private var capturedInputText: String?

    // MARK: - Initialization

    /// Creates a new transformation flow coordinator.
    public init() {}

    // MARK: - Public Methods

    /// Handles a hotkey trigger to perform the full transformation flow.
    ///
    /// This is the main entry point called when the user presses a transformation hotkey.
    /// It orchestrates the entire flow: read -> transform -> write -> paste.
    ///
    /// - Returns: `true` if transformation completed successfully, `false` otherwise.
    @discardableResult
    public func handleHotkeyTrigger() async -> Bool {
        // Prevent concurrent transformations
        guard await !self.queue.isProcessing else {
            self.handleFlowError(.alreadyProcessing)
            return false
        }

        let request = self.makeRequest()

        // Launch the transformation work as a Task tracked by the queue.
        let task = Task(priority: .userInitiated) { @MainActor in
            try await self.executeFlow(for: request)
        }

        do {
            try await self.queue.start(request: request, task: task)
        } catch {
            task.cancel()
            self.handleFlowError(.alreadyProcessing)
            return false
        }

        self.transition(to: .processing(request: request))
        self.lastError = nil
        self.delegate?.transformationFlowDidStart()

        // Observe completion without blocking the caller.
        Task { @MainActor in
            await self.awaitCompletion(for: request)
        }

        return true
    }

    /// Handles a flow error by restoring clipboard, notifying user, and updating state.
    ///
    /// ## Error Recovery Flow
    /// 1. Restore original clipboard content (never lose user data)
    /// 2. Show appropriate notification to user
    /// 3. Update state and notify delegate
    /// 4. Play system beep for non-silent errors
    private func handleFlowError(_ error: TransformationFlowError) {
        self.lastError = error
        self.delegate?.transformationFlowDidFail(error: error)

        // Check if this error should be handled silently
        if self.errorRecoveryManager.shouldHandleSilently(error) {
            return
        }

        // Handle error with recovery manager (restores clipboard, shows notification)
        Task { @MainActor in
            await self.errorRecoveryManager.handleError(error)
        }
    }

    /// Resets the coordinator state.
    ///
    /// Call this to clear error state and prepare for a new transformation.
    public func reset() {
        self.lastError = nil
        self.transition(to: .idle)
        Task {
            await self.queue.cancel()
        }
    }

    // MARK: - Flow Steps

    /// Checks that accessibility permission is granted.
    private func checkAccessibilityPermission() throws {
        guard AccessibilityPermissionManager.shared.isGranted else {
            throw TransformationFlowError.accessibilityPermissionRequired
        }
    }

    /// Checks if the clipboard contains our self-write marker.
    private func checkSelfWriteMarker() throws {
        guard SelfWriteMarker.isSafeToProcess() else {
            throw TransformationFlowError.selfWriteDetected
        }
    }

    /// Reads text from clipboard after checking for binary content.
    private func readClipboardText() throws -> String {
        let result = ClipboardSafety.readText()

        switch result {
        case let .success(text):
            guard !text.isEmpty else {
                throw TransformationFlowError.clipboardEmpty
            }
            return text

        case let .failure(error):
            switch error {
            case .empty:
                throw TransformationFlowError.clipboardEmpty
            case let .binaryContent(type):
                throw TransformationFlowError.binaryContent(type: type)
            case .noTextContent:
                throw TransformationFlowError.noTextContent
            case .unknownContent:
                throw TransformationFlowError.noTextContent
            }
        }
    }

    /// Writes transformed text to clipboard with self-write marker.
    private func writeToClipboard(_ text: String) throws {
        let result = ClipboardWriter.shared.write(text)

        switch result {
        case .success:
            return
        case let .failure(error):
            throw TransformationFlowError.clipboardWriteFailed(error)
        }
    }

    /// Simulates Cmd+V paste.
    private func simulatePaste() throws {
        do {
            try PasteSimulator.shared.paste()
        } catch {
            throw TransformationFlowError.pasteSimulationFailed(error)
        }
    }

    /// Build a request object describing the pending transformation.
    private func makeRequest() -> TransformationRequest {
        let timeout = self.transformationTimeout
        let source: TransformationRequest.Source = self.pipeline == nil
            ? .single(transformationId: self.transformation.id)
            : .pipeline

        return TransformationRequest(timeout: timeout, source: source)
    }

    /// Update processing and UI state in a single place.
    private func transition(to newState: TransformationProcessingState) {
        self.processingState = newState
        switch newState {
        case .processing:
            self.isProcessing = true
        case .idle, .completed, .failed, .cancelled:
            self.isProcessing = false
        }
    }

    /// Wait for the tracked task to complete and update UI/delegate callbacks.
    private func awaitCompletion(for request: TransformationRequest) async {
        guard let task = await self.queue.task() else {
            if case .processing = self.processingState {
                self.transition(to: .idle)
            }
            return
        }

        do {
            let outcome = try await task.value
            self.recordHistoryEntry(for: outcome)
            self.transition(to: .completed(outcome: outcome))
            self.delegate?.transformationFlowDidComplete(
                originalText: outcome.originalText,
                transformedText: outcome.transformedText
            )
        } catch is CancellationError {
            self.transition(to: .cancelled(request: request))
        } catch {
            let flowError = (error as? TransformationFlowError)
                ?? TransformationFlowError.transformationFailed(error)
            self.recordHistoryFailure(for: request, error: flowError, inputText: self.capturedInputText)
            self.transition(to: .failed(request: request, error: flowError))
            self.handleFlowError(flowError)
        }

        self.capturedInputText = nil
        // Clear pipeline after completion to avoid reuse across triggers.
        self.pipeline = nil
        await self.queue.finish()
    }

    /// Cancel the current transformation if one is running.
    public func cancelCurrentTransformation() async {
        let request = await self.queue.request()
        await self.queue.cancel()

        if let request {
            self.transition(to: .cancelled(request: request))
        } else {
            self.transition(to: .idle)
        }
    }

    /// Execute the full transformation flow for a specific request.
    ///
    /// ## Error Recovery
    /// Original clipboard content is captured BEFORE transformation begins.
    /// If any step fails, the ErrorRecoveryManager will restore the original
    /// content, ensuring no data loss.
    private func executeFlow(for request: TransformationRequest) async throws -> TransformationFlowOutcome {
        try self.checkAccessibilityPermission()
        try self.checkSelfWriteMarker()

        // CRITICAL: Capture original clipboard BEFORE reading/transforming
        // This enables recovery if transformation fails
        self.errorRecoveryManager.captureOriginalClipboard()

        let clipboardText = try self.readClipboardText()
        self.capturedInputText = clipboardText
        try Task.checkCancellation()

        let (transformedText, descriptor) = try await self.performTransformation(
            clipboardText,
            timeout: request.timeout
        )

        try Task.checkCancellation()
        try self.writeToClipboard(transformedText)

        try await self.waitForPasteDelay()
        try Task.checkCancellation()

        try self.simulatePaste()

        // Clear captured clipboard on success - no longer needed for recovery
        self.errorRecoveryManager.clearOriginalClipboard()

        return TransformationFlowOutcome(
            request: request,
            originalText: clipboardText,
            transformedText: transformedText,
            historyDescriptor: descriptor
        )
    }

    /// Run pipeline or single transformation with timeout protection.
    private func performTransformation(
        _ input: String,
        timeout: TimeInterval
    ) async throws -> (String, TransformationHistoryDescriptor) {
        if let pipeline {
            do {
                let result = try await pipeline.execute(input)
                return (result.output, self.makeDescriptor(from: result))
            } catch let error as PipelineError {
                throw TransformationFlowError.transformationFailed(error)
            } catch let error as TransformationError {
                throw TransformationFlowError.transformationFailed(error)
            }
        }

        do {
            let output = try await self.executeWithTimeout(timeout) {
                try await self.transformation.transform(input)
            }
            return (
                output,
                self.makeDescriptor(
                    id: self.transformation.id,
                    name: self.transformation.displayName,
                    metadataProvider: self.transformation
                )
            )
        } catch let error as TransformationError {
            throw TransformationFlowError.transformationFailed(error)
        }
    }

    /// Sleep for the configured paste delay.
    private func waitForPasteDelay() async throws {
        try await Task.sleep(for: .seconds(self.pasteDelay))
    }

    /// Execute a task with timeout and cooperative cancellation.
    private func executeWithTimeout<T: Sendable>(
        _ duration: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(for: .seconds(duration))
                throw TransformationError.timeout(seconds: Int(duration))
            }

            guard let result = try await group.next() else {
                throw TransformationFlowError.transformationFailed(
                    TransformationError.processingError("Transformation did not produce a result")
                )
            }

            group.cancelAll()
            return result
        }
    }
}
