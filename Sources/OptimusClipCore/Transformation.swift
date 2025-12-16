import Foundation

/// A clipboard transformation that processes text input and produces text output.
///
/// Transformations can be either algorithmic (local processing) or LLM-based (API calls).
/// All transformations must be thread-safe and support Swift 6 strict concurrency.
///
/// Example implementations:
/// - Whitespace stripping (algorithmic)
/// - Line unwrapping (algorithmic)
/// - Format as Jira ticket (LLM-based)
///
/// - Phase 0: Protocol definition only (minimal)
/// - Phase 4: Algorithmic implementations (WhitespaceStripTransformation, UnwrapTransformation)
/// - Phase 5: LLM implementations (OpenAITransformation, AnthropicTransformation)
public protocol Transformation: Sendable {
    /// Unique identifier for this transformation type.
    ///
    /// Used for persistence, lookup, and hotkey mapping.
    /// Convention: lowercase with hyphens (e.g., "whitespace-strip", "smart-unwrap")
    var id: String { get }

    /// Human-readable name for display in UI.
    ///
    /// Shown in menus, settings, and status messages.
    /// Example: "Strip Whitespace", "Smart Unwrap"
    var displayName: String { get }

    /// Transform the input text according to this transformation's logic.
    ///
    /// - Parameter input: The text to transform (clipboard content)
    /// - Returns: The transformed text (to be written to clipboard)
    /// - Throws: TransformationError if processing fails
    func transform(_ input: String) async throws -> String
}

/// Errors that can occur during transformation.
public enum TransformationError: Error, Sendable, LocalizedError {
    /// Input is empty or whitespace-only
    case emptyInput

    /// Transformation timed out (LLM calls)
    case timeout(seconds: Int)

    /// Network error (LLM API unreachable)
    case networkError(String)

    /// Invalid API key or auth failure
    case authenticationError

    /// Generic processing error
    case processingError(String)

    /// Rate limited by API provider
    case rateLimited(retryAfter: TimeInterval?)

    /// Content exceeds size limit
    case contentTooLarge(bytes: Int, limit: Int)

    /// User-friendly error description for display.
    public var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "No text to transform"
        case let .timeout(seconds):
            return "Transformation timed out after \(seconds) seconds"
        case let .networkError(message):
            return "Network error: \(message)"
        case .authenticationError:
            return "Invalid API key or authentication failed"
        case let .processingError(message):
            return "Processing error: \(message)"
        case let .rateLimited(retryAfter):
            if let seconds = retryAfter {
                return "Rate limited. Try again in \(Int(seconds)) seconds"
            }
            return "Rate limited. Please wait and try again"
        case let .contentTooLarge(bytes, limit):
            return "Content too large (\(bytes) bytes, limit \(limit))"
        }
    }

    /// Short message suitable for HUD display.
    public var shortMessage: String {
        switch self {
        case .emptyInput:
            "Empty input"
        case .timeout:
            "Timed out"
        case .networkError:
            "Network error"
        case .authenticationError:
            "Auth failed"
        case .rateLimited:
            "Rate limited"
        case .contentTooLarge:
            "Content too large"
        case .processingError:
            "Processing error"
        }
    }
}

// MARK: - Placeholder Implementation

/// Minimal placeholder transformation for Phase 0 testing.
///
/// Simply returns the input unchanged. Used to verify:
/// - Protocol can be implemented
/// - Tests can instantiate conforming types
/// - Async/await works correctly
///
/// Phase 4 will add real algorithmic transformations.
public struct IdentityTransformation: Transformation {
    public let id = "identity"
    public let displayName = "Identity (No Change)"

    public init() {}

    public func transform(_ input: String) async throws -> String {
        // Phase 0: No-op transformation for testing
        // Validates async/throws/Sendable semantics
        if input.isEmpty {
            throw TransformationError.emptyInput
        }
        return input
    }
}

// MARK: - Metadata Support

/// Supplemental metadata describing how a transformation was executed.
///
/// Used for history logging to capture provider/model details for LLM-based
/// transformations while keeping algorithmic transformations lightweight.
public struct TransformationHistoryMetadata: Sendable, Equatable {
    public let providerName: String?
    public let modelUsed: String?
    public let systemPrompt: String?

    public init(
        providerName: String? = nil,
        modelUsed: String? = nil,
        systemPrompt: String? = nil
    ) {
        self.providerName = providerName
        self.modelUsed = modelUsed
        self.systemPrompt = systemPrompt
    }
}

/// Protocol that allows a transformation to expose metadata for history logging.
public protocol TransformationHistoryMetadataProviding {
    /// Metadata describing how the transformation was configured/executed.
    var historyMetadata: TransformationHistoryMetadata { get }
}
