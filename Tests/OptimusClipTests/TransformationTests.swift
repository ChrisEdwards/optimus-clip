import Testing
@testable import OptimusClipCore

/// Test suite for Transformation protocol and implementations.
///
/// Phase 0: Validates test infrastructure with minimal placeholder.
/// Phase 4: Comprehensive tests for algorithmic transformations.
/// Phase 5: Tests for LLM transformations (with mocking).
@Suite("Transformation Tests")
struct TransformationTests {
    // MARK: - Phase 0: Infrastructure Validation

    @Test("IdentityTransformation returns input unchanged")
    func identityTransformation() async throws {
        let transformation = IdentityTransformation()
        let input = "Hello, World!"
        let output = try await transformation.transform(input)

        #expect(output == input)
    }

    @Test("IdentityTransformation throws on empty input")
    func identityTransformationEmptyInput() async {
        let transformation = IdentityTransformation()
        let input = ""

        await #expect(throws: TransformationError.self) {
            try await transformation.transform(input)
        }
    }

    @Test("Transformation protocol supports async/await")
    func transformationAsync() async throws {
        // Verify async semantics work correctly
        let transformation = IdentityTransformation()

        let task = Task {
            try await transformation.transform("Async test")
        }

        let result = try await task.value
        #expect(result == "Async test")
    }

    // MARK: - Protocol Property Tests

    @Test("IdentityTransformation has id property")
    func identityTransformationId() {
        let transformation = IdentityTransformation()
        #expect(transformation.id == "identity")
    }

    @Test("IdentityTransformation has displayName property")
    func identityTransformationDisplayName() {
        let transformation = IdentityTransformation()
        #expect(transformation.displayName == "Identity (No Change)")
    }

    // MARK: - Error LocalizedError Tests

    @Test("TransformationError.emptyInput has localized description")
    func emptyInputErrorDescription() {
        let error = TransformationError.emptyInput
        #expect(error.errorDescription == "No text to transform")
    }

    @Test("TransformationError.timeout has localized description with seconds")
    func timeoutErrorDescription() {
        let error = TransformationError.timeout(seconds: 30)
        #expect(error.errorDescription == "Transformation timed out after 30 seconds")
    }

    @Test("TransformationError.rateLimited has localized description")
    func rateLimitedErrorDescription() {
        let errorWithRetry = TransformationError.rateLimited(retryAfter: 60)
        #expect(errorWithRetry.errorDescription == "Rate limited. Try again in 60 seconds")

        let errorNoRetry = TransformationError.rateLimited(retryAfter: nil)
        #expect(errorNoRetry.errorDescription == "Rate limited. Please wait and try again")
    }

    @Test("TransformationError.contentTooLarge has localized description")
    func contentTooLargeErrorDescription() {
        let error = TransformationError.contentTooLarge(bytes: 10000, limit: 5000)
        #expect(error.errorDescription == "Content too large (10000 bytes, limit 5000)")
    }

    // MARK: - Phase 4: Algorithmic Transformation Tests (TODO)

    // TODO: Phase 4 - Add tests for WhitespaceStripTransformation
    // TODO: Phase 4 - Add tests for SmartUnwrapTransformation

    // MARK: - Phase 5: LLM Transformation Tests (TODO)

    // TODO: Phase 5 - Add tests for OpenAI integration (with mocking)
    // TODO: Phase 5 - Add tests for Anthropic integration (with mocking)
}
