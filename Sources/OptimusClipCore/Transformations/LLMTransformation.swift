import Foundation

/// LLM-backed transformation that delegates to a provider client with unified error handling.
public struct LLMTransformation: Transformation {
    public let id: String
    public let displayName: String

    private let providerClient: any LLMProviderClient
    private let providerKind: LLMProviderKind
    private let model: String
    private let systemPrompt: String
    private let temperature: Double
    private let maxTokens: Int?
    private let timeoutSeconds: TimeInterval
    private let contentLimitBytes: Int

    public init(
        id: String = "llm-transformation",
        displayName: String = "LLM Transformation",
        providerClient: any LLMProviderClient,
        model: String,
        systemPrompt: String,
        temperature: Double = 0.7,
        maxTokens: Int? = 4096,
        timeoutSeconds: TimeInterval = 30,
        contentLimitBytes: Int = 200_000
    ) {
        self.id = id
        self.displayName = displayName
        self.providerClient = providerClient
        self.providerKind = providerClient.provider
        self.model = model
        self.systemPrompt = systemPrompt
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.timeoutSeconds = timeoutSeconds
        self.contentLimitBytes = contentLimitBytes
    }

    public func transform(_ input: String) async throws -> String {
        try self.validateContent(input)

        let request = LLMRequest(
            provider: self.providerClient.provider,
            model: self.model,
            text: input,
            systemPrompt: self.systemPrompt,
            temperature: self.temperature,
            maxTokens: self.maxTokens,
            timeout: self.timeoutSeconds
        )

        let response: LLMResponse
        do {
            response = try await self.withTimeout(self.timeoutSeconds) {
                try await self.providerClient.transform(request)
            }
        } catch let error as LLMProviderError {
            throw self.mapProviderError(error)
        } catch {
            throw TransformationError.processingError(error.localizedDescription)
        }

        guard !response.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TransformationError.processingError("LLM returned empty content")
        }

        return response.output
    }

    private func validateContent(_ input: String) throws {
        if input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw TransformationError.emptyInput
        }

        let byteCount = input.utf8.count
        if byteCount > self.contentLimitBytes {
            throw TransformationError.contentTooLarge(bytes: byteCount, limit: self.contentLimitBytes)
        }
    }

    private func mapProviderError(_ error: LLMProviderError) -> TransformationError {
        switch error {
        case .notConfigured:
            TransformationError.processingError("Provider is not configured")
        case .authenticationError:
            TransformationError.authenticationError
        case let .rateLimited(retryAfter):
            TransformationError.rateLimited(retryAfter: retryAfter)
        case .timeout:
            TransformationError.timeout(seconds: Int(self.timeoutSeconds))
        case .modelNotFound:
            TransformationError.processingError("Model not available")
        case let .network(message):
            TransformationError.networkError(message)
        case let .server(message), let .invalidResponse(message):
            TransformationError.processingError(message)
        }
    }

    private func withTimeout<T: Sendable>(
        _ duration: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(for: .seconds(duration))
                throw LLMProviderError.timeout
            }

            guard let result = try await group.next() else {
                throw LLMProviderError.timeout
            }

            group.cancelAll()
            return result
        }
    }
}

extension LLMTransformation: TransformationHistoryMetadataProviding {
    public var historyMetadata: TransformationHistoryMetadata {
        TransformationHistoryMetadata(
            providerName: self.providerKind.rawValue,
            modelUsed: self.model,
            systemPrompt: self.systemPrompt
        )
    }
}
