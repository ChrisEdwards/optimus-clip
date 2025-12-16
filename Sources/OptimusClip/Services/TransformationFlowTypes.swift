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

    /// Short error message suitable for HUD display.
    public var shortMessage: String {
        switch self {
        case .accessibilityPermissionRequired:
            return "Permission required"
        case .clipboardEmpty:
            return "Clipboard empty"
        case .binaryContent:
            return "Not text content"
        case .selfWriteDetected:
            return "Already transformed"
        case .noTextContent:
            return "No text found"
        case let .transformationFailed(underlying):
            // Try to get specific error message from known error types
            if let txError = underlying as? TransformationError {
                return txError.shortMessage
            }
            // Unwrap pipeline stage failures to get the real error
            if let pipelineError = underlying as? PipelineError {
                switch pipelineError {
                case .emptyPipeline:
                    return "No transforms configured"
                case let .stageFailed(_, _, innerError):
                    // Get the actual error from the failed stage
                    if let txError = innerError as? TransformationError {
                        return txError.shortMessage
                    }
                    let desc = innerError.localizedDescription
                    if desc.count > 40 {
                        return String(desc.prefix(37)) + "..."
                    }
                    return desc
                case .timeout:
                    return "Timed out"
                case .cancelled:
                    return "Cancelled"
                }
            }
            // For other errors, extract a meaningful message
            let description = underlying.localizedDescription
            // Truncate if too long for HUD
            if description.count > 40 {
                return String(description.prefix(37)) + "..."
            }
            return description
        case .clipboardWriteFailed:
            return "Write failed"
        case .pasteSimulationFailed:
            return "Paste failed"
        case .alreadyProcessing:
            return "Already processing"
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
