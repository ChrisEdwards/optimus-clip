import AppKit
import Foundation
import OptimusClipCore

/// Categorizes transformation errors for recovery handling.
public enum ErrorCategory: Sendable {
    /// Network connectivity issues - transient, may recover.
    case network

    /// Authentication failures - requires user action.
    case authentication

    /// Rate limiting - wait and retry.
    case rateLimit(retryAfter: TimeInterval?)

    /// Request timeout - may work with shorter input.
    case timeout(seconds: Int)

    /// Service unavailable - provider issue.
    case serviceUnavailable

    /// Permission required - accessibility.
    case permissionRequired

    /// Content issues - binary, empty, too large.
    case contentIssue

    /// Generic processing error.
    case processingError

    /// Provider name if applicable (for auth errors).
    public var providerName: String? {
        nil // Set by caller based on context
    }
}

/// Recovery actions the system can suggest or take.
public enum RecoveryAction: Sendable {
    /// Open settings to fix configuration.
    case openSettings

    /// Retry the operation.
    case retry

    /// Wait a specific duration then retry.
    case waitAndRetry(seconds: TimeInterval)

    /// Request accessibility permission.
    case requestPermission

    /// No automatic recovery - inform user only.
    case informOnly
}

/// Manages error recovery strategies for transformation failures.
///
/// The ErrorRecoveryManager:
/// 1. Categorizes errors into actionable types
/// 2. Generates user-friendly messages
/// 3. Determines appropriate recovery actions
/// 4. Preserves original clipboard content on failure
///
/// ## Golden Rule
/// If transformation fails, the clipboard MUST contain the original content.
/// Never leave the user with empty or corrupted clipboard.
///
/// ## Usage
/// ```swift
/// let manager = ErrorRecoveryManager.shared
///
/// // Before transformation
/// manager.captureOriginalClipboard()
///
/// // On failure
/// manager.restoreOriginalClipboard()
/// let category = manager.categorize(error)
/// await manager.handleError(error, category: category)
/// ```
@MainActor
public final class ErrorRecoveryManager: ObservableObject {
    // MARK: - Singleton

    /// Shared error recovery manager instance.
    public static let shared = ErrorRecoveryManager()

    // MARK: - State

    /// The original clipboard content captured before transformation.
    private var originalClipboardContent: String?

    /// The notification service for user alerts.
    private let notificationService = NotificationService.shared

    /// Current provider being used (for contextual error messages).
    @Published public var currentProvider: String?

    // MARK: - Initialization

    private init() {}

    // MARK: - Clipboard Preservation

    /// Captures the current clipboard content before transformation.
    ///
    /// Call this BEFORE starting any transformation to enable rollback.
    public func captureOriginalClipboard() {
        let pasteboard = NSPasteboard.general
        self.originalClipboardContent = pasteboard.string(forType: .string)
    }

    /// Restores the original clipboard content after a failure.
    ///
    /// This ensures the user never loses their original copied text.
    /// Returns true if restoration was successful.
    @discardableResult
    public func restoreOriginalClipboard() -> Bool {
        guard let original = self.originalClipboardContent else {
            return false
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(original, forType: .string)
    }

    /// Clears the captured original content after successful transformation.
    public func clearOriginalClipboard() {
        self.originalClipboardContent = nil
    }

    // MARK: - Error Categorization

    /// Categorizes a TransformationFlowError for recovery handling.
    public func categorize(_ error: TransformationFlowError) -> ErrorCategory {
        switch error {
        case .accessibilityPermissionRequired:
            .permissionRequired
        case .clipboardEmpty, .noTextContent, .selfWriteDetected, .inputTooLarge:
            .contentIssue
        case .binaryContent:
            .contentIssue
        case let .transformationFailed(underlying):
            self.categorizeTransformationError(underlying)
        case .clipboardWriteFailed, .pasteSimulationFailed:
            .processingError
        case .alreadyProcessing:
            .processingError
        }
    }

    /// Categorizes underlying TransformationError.
    private func categorizeTransformationError(_ error: Error) -> ErrorCategory {
        if let transformError = error as? TransformationError {
            return self.categorizeTransformError(transformError)
        }

        if let urlError = error as? URLError {
            return self.categorizeURLError(urlError)
        }

        return .processingError
    }

    /// Categorizes a TransformationError into an ErrorCategory.
    private func categorizeTransformError(_ error: TransformationError) -> ErrorCategory {
        switch error {
        case .emptyInput, .contentTooLarge:
            .contentIssue
        case let .timeout(seconds):
            .timeout(seconds: seconds)
        case .networkError:
            .network
        case .authenticationError:
            .authentication
        case let .rateLimited(retryAfter):
            .rateLimit(retryAfter: retryAfter)
        case .processingError:
            .processingError
        }
    }

    /// Categorizes a URLError into an ErrorCategory.
    private func categorizeURLError(_ error: URLError) -> ErrorCategory {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut:
            error.code == .timedOut ? .timeout(seconds: 30) : .network
        default:
            .network
        }
    }

    // MARK: - Recovery Actions

    /// Determines the appropriate recovery action for an error category.
    public func determineRecoveryAction(for category: ErrorCategory) -> RecoveryAction {
        switch category {
        case .network:
            return .informOnly
        case .authentication:
            return .openSettings
        case let .rateLimit(retryAfter):
            if let seconds = retryAfter {
                return .waitAndRetry(seconds: seconds)
            }
            return .informOnly
        case .timeout:
            return .informOnly
        case .serviceUnavailable:
            return .informOnly
        case .permissionRequired:
            return .requestPermission
        case .contentIssue:
            return .informOnly
        case .processingError:
            return .informOnly
        }
    }

    // MARK: - Error Handling

    /// Handles an error by restoring clipboard and notifying user.
    ///
    /// This is the main entry point for error recovery. It:
    /// 1. Restores original clipboard content
    /// 2. Categorizes the error
    /// 3. Shows appropriate notification
    /// 4. Returns the recovery action
    ///
    /// - Parameter error: The transformation flow error that occurred.
    /// - Returns: The recommended recovery action.
    @discardableResult
    public func handleError(_ error: TransformationFlowError) async -> RecoveryAction {
        // CRITICAL: Restore original clipboard first
        self.restoreOriginalClipboard()

        let category = self.categorize(error)
        let action = self.determineRecoveryAction(for: category)

        // Show appropriate notification
        await self.showNotification(for: error, category: category)

        return action
    }

    /// Shows the appropriate notification for an error.
    private func showNotification(
        for error: TransformationFlowError,
        category: ErrorCategory
    ) async {
        switch category {
        case .network:
            await self.notificationService.showNetworkError(message: error.message)

        case .authentication:
            let provider = self.currentProvider ?? "the provider"
            await self.notificationService.showAuthenticationError(provider: provider)

        case let .rateLimit(retryAfter):
            await self.notificationService.showRateLimitError(retryAfter: retryAfter)

        case let .timeout(seconds):
            await self.notificationService.showTimeoutError(seconds: seconds)

        case .serviceUnavailable:
            await self.notificationService.showError(
                title: "Service Unavailable",
                message: "The provider service is temporarily unavailable. Try again shortly.",
                category: .transformationError
            )

        case .permissionRequired:
            await self.notificationService.showError(
                title: "Permission Required",
                message: "Accessibility permission is required to paste. Open System Settings to grant access.",
                category: .authenticationError
            )

        case .contentIssue:
            // Content issues are often silent (e.g., self-write, empty clipboard)
            // Only notify for binary content
            if case let .binaryContent(type) = error {
                let typeName = ClipboardContentType.friendlyTypeName(for: type)
                await self.notificationService.showError(
                    title: "Cannot Transform",
                    message: "Only text content can be transformed. Found: \(typeName)",
                    category: .transformationError
                )
            }

        case .processingError:
            await self.notificationService.showError(
                title: "Transformation Failed",
                message: error.message,
                category: .transformationError
            )
        }
    }

    // MARK: - Silent Error Checks

    /// Checks if an error should be handled silently without notification.
    ///
    /// Some errors are expected conditions, not real failures:
    /// - Self-write detection (our own content)
    /// - Empty clipboard (nothing to transform)
    /// - Already processing (duplicate trigger)
    public func shouldHandleSilently(_ error: TransformationFlowError) -> Bool {
        switch error {
        case .selfWriteDetected, .clipboardEmpty, .alreadyProcessing:
            true
        default:
            false
        }
    }

    // MARK: - User-Friendly Messages

    /// Returns a user-friendly title for an error category.
    public func userFriendlyTitle(for category: ErrorCategory) -> String {
        switch category {
        case .network:
            "Connection Problem"
        case .authentication:
            "Invalid API Key"
        case .rateLimit:
            "Rate Limited"
        case .timeout:
            "Request Timed Out"
        case .serviceUnavailable:
            "Service Unavailable"
        case .permissionRequired:
            "Permission Required"
        case .contentIssue:
            "Cannot Transform"
        case .processingError:
            "Transformation Failed"
        }
    }

    /// Returns actionable guidance for an error category.
    public func userGuidance(for category: ErrorCategory) -> String {
        switch category {
        case .network:
            return "Check your internet connection and try again."
        case .authentication:
            return "Your API key may be invalid or expired. Update it in Settings."
        case let .rateLimit(retryAfter):
            if let seconds = retryAfter {
                return "Wait \(Int(seconds)) seconds before trying again."
            }
            return "Please wait a moment before trying again."
        case let .timeout(seconds):
            return "The request took longer than \(seconds)s. Try shorter text or check your connection."
        case .serviceUnavailable:
            return "The provider is temporarily unavailable. Try again shortly or use a different provider."
        case .permissionRequired:
            return "Grant Accessibility permission in System Settings > Privacy & Security."
        case .contentIssue:
            return "Only text content can be transformed. Copy text and try again."
        case .processingError:
            return "An unexpected error occurred. Please try again."
        }
    }
}
