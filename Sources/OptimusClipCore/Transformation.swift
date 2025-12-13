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
    /// Transform the input text according to this transformation's logic.
    ///
    /// - Parameter input: The text to transform (clipboard content)
    /// - Returns: The transformed text (to be written to clipboard)
    /// - Throws: TransformationError if processing fails
    func transform(_ input: String) async throws -> String
}

/// Errors that can occur during transformation.
public enum TransformationError: Error, Sendable {
    /// Input is empty or whitespace-only
    case emptyInput

    /// Transformation timed out (LLM calls)
    case timeout

    /// Network error (LLM API unreachable)
    case networkError(String)

    /// Invalid API key or auth failure
    case authenticationError

    /// Generic processing error
    case processingError(String)
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
