import Foundation
import Testing
@testable import OptimusClipCore

@Suite("LLM Transformation")
struct LLMTransformationTests {
    @Test("returns provider output on success")
    func returnsProviderOutput() async throws {
        let provider = StubLLMProvider { request in
            LLMResponse(
                provider: request.provider,
                model: request.model,
                output: "cleaned",
                duration: 0.1
            )
        }

        let transformation = LLMTransformation(
            id: "llm-success",
            displayName: "LLM Success",
            providerClient: provider,
            model: "gpt-4o",
            systemPrompt: "test",
            timeoutSeconds: 2
        )

        let output = try await transformation.transform("input text")
        #expect(output == "cleaned")
    }

    @Test("maps rate limit to TransformationError.rateLimited")
    func mapsRateLimit() async {
        let provider = StubLLMProvider { _ in
            throw LLMProviderError.rateLimited(retryAfter: 30)
        }

        let transformation = LLMTransformation(
            id: "llm-rate",
            displayName: "LLM Rate Limit",
            providerClient: provider,
            model: "gpt-4o",
            systemPrompt: "test",
            timeoutSeconds: 2
        )

        await #expect(throws: TransformationError.rateLimited(retryAfter: 30)) {
            _ = try await transformation.transform("Hello")
        }
    }

    @Test("throws timeout when provider exceeds limit")
    func throwsOnTimeout() async {
        let provider = StubLLMProvider { _ in
            try await Task.sleep(for: .seconds(1))
            return LLMResponse(
                provider: .openAI,
                model: "gpt-4o",
                output: "late",
                duration: 1
            )
        }

        let transformation = LLMTransformation(
            id: "llm-timeout",
            displayName: "LLM Timeout",
            providerClient: provider,
            model: "gpt-4o",
            systemPrompt: "test",
            timeoutSeconds: 0.1
        )

        await #expect(throws: TransformationError.timeout(seconds: 0)) {
            _ = try await transformation.transform("Hello")
        }
    }

    @Test("rejects content that exceeds byte limit")
    func rejectsLargeContent() async {
        let provider = StubLLMProvider { _ in
            LLMResponse(provider: .openAI, model: "gpt-4o", output: "ok", duration: 0)
        }

        let transformation = LLMTransformation(
            id: "llm-size",
            displayName: "LLM Size",
            providerClient: provider,
            model: "gpt-4o",
            systemPrompt: "test",
            timeoutSeconds: 1,
            contentLimitBytes: 4
        )

        await #expect(throws: TransformationError.contentTooLarge(bytes: 5, limit: 4)) {
            _ = try await transformation.transform("12345")
        }
    }
}

// MARK: - Test Doubles

private struct StubLLMProvider: LLMProviderClient {
    let provider: LLMProviderKind
    private let handler: @Sendable (LLMRequest) async throws -> LLMResponse
    private let configured: Bool

    init(
        provider: LLMProviderKind = .openAI,
        configured: Bool = true,
        handler: @escaping @Sendable (LLMRequest) async throws -> LLMResponse
    ) {
        self.provider = provider
        self.configured = configured
        self.handler = handler
    }

    func isConfigured() -> Bool {
        self.configured
    }

    func transform(_ request: LLMRequest) async throws -> LLMResponse {
        guard self.configured else {
            throw LLMProviderError.notConfigured
        }
        return try await self.handler(request)
    }
}
