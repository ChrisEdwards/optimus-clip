import AppKit
import OptimusClipCore

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

    /// The transformation to apply to clipboard content.
    /// Defaults to IdentityTransformation (no-op) for Phase 2.
    public var transformation: any Transformation = IdentityTransformation()

    /// Delegate for receiving flow events.
    public weak var delegate: TransformationFlowDelegate?

    // MARK: - State

    /// Whether a transformation is currently in progress.
    /// Used to prevent concurrent transformations.
    @Published public private(set) var isProcessing: Bool = false

    /// The last error that occurred, if any.
    @Published public private(set) var lastError: TransformationFlowError?

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
        guard !self.isProcessing else {
            self.lastError = .alreadyProcessing
            self.delegate?.transformationFlowDidFail(error: .alreadyProcessing)
            NSSound.beep()
            return false
        }

        self.isProcessing = true
        self.lastError = nil
        self.delegate?.transformationFlowDidStart()

        defer {
            self.isProcessing = false
        }

        do {
            // Step 1: Check accessibility permission
            try self.checkAccessibilityPermission()

            // Step 2: Check self-write marker (skip our own writes)
            try self.checkSelfWriteMarker()

            // Step 3: Check for binary content and read text
            let clipboardText = try self.readClipboardText()

            // Step 4: Transform content with timeout
            let transformedText = try await self.transformWithTimeout(clipboardText)

            // Step 5: Write to clipboard with marker
            try self.writeToClipboard(transformedText)

            // Step 6: Wait briefly for clipboard to settle
            try await Task.sleep(nanoseconds: UInt64(self.pasteDelay * 1_000_000_000))

            // Step 7: Simulate paste
            try self.simulatePaste()

            // Success!
            self.delegate?.transformationFlowDidComplete(
                originalText: clipboardText,
                transformedText: transformedText
            )

            return true

        } catch let error as TransformationFlowError {
            self.lastError = error
            self.delegate?.transformationFlowDidFail(error: error)
            NSSound.beep()
            return false

        } catch {
            let flowError = TransformationFlowError.transformationFailed(error)
            self.lastError = flowError
            self.delegate?.transformationFlowDidFail(error: flowError)
            NSSound.beep()
            return false
        }
    }

    /// Resets the coordinator state.
    ///
    /// Call this to clear error state and prepare for a new transformation.
    public func reset() {
        self.lastError = nil
        self.isProcessing = false
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

    /// Transforms content with timeout protection.
    private func transformWithTimeout(_ input: String) async throws -> String {
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(self.transformationTimeout * 1_000_000_000))
            throw TransformationError.timeout
        }

        let transformTask = Task {
            try await self.transformation.transform(input)
        }

        // Race between timeout and transformation
        return try await withTaskCancellationHandler {
            let result = try await transformTask.value
            timeoutTask.cancel()
            return result
        } onCancel: {
            timeoutTask.cancel()
            transformTask.cancel()
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
}
