import Foundation

// MARK: - Provider Types

public enum LLMProviderKind: String, Sendable {
    case openAI
    case anthropic
    case openRouter
    case ollama
    case awsBedrock

    /// Human-readable display name for UI purposes.
    public var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .openRouter: "OpenRouter"
        case .ollama: "Ollama"
        case .awsBedrock: "AWS Bedrock"
        }
    }
}

public enum LLMCredentials: Sendable {
    case openAI(apiKey: String)
    case anthropic(apiKey: String)
    case openRouter(apiKey: String)
    case ollama(endpoint: URL)
    case awsBedrock(accessKey: String, secretKey: String, region: String)
    case awsBedrockBearerToken(bearerToken: String, region: String)
}

// MARK: - Request / Response

public struct LLMRequest: Sendable {
    public let provider: LLMProviderKind
    public let model: String
    public let text: String
    public let systemPrompt: String
    public let temperature: Double
    public let maxTokens: Int?
    public let requestID: UUID
    public let timeout: TimeInterval

    public init(
        provider: LLMProviderKind,
        model: String,
        text: String,
        systemPrompt: String,
        temperature: Double = 0.7,
        maxTokens: Int? = 4096,
        requestID: UUID = UUID(),
        timeout: TimeInterval = 30
    ) {
        self.provider = provider
        self.model = model
        self.text = text
        self.systemPrompt = systemPrompt
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.requestID = requestID
        self.timeout = timeout
    }
}

public struct LLMResponse: Sendable {
    public let provider: LLMProviderKind
    public let model: String
    public let output: String
    public let duration: TimeInterval

    public init(
        provider: LLMProviderKind,
        model: String,
        output: String,
        duration: TimeInterval
    ) {
        self.provider = provider
        self.model = model
        self.output = output
        self.duration = duration
    }
}

// MARK: - Errors

public enum LLMProviderError: Error, Sendable, LocalizedError, Equatable {
    case notConfigured
    case authenticationError
    case rateLimited(retryAfter: TimeInterval?)
    case timeout
    case modelNotFound
    case network(String)
    case server(String)
    case invalidResponse(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Provider not configured"
        case .authenticationError:
            return "Authentication failed"
        case let .rateLimited(retryAfter):
            if let retryAfter {
                return "Rate limited. Retry after \(Int(retryAfter)) seconds"
            }
            return "Rate limited"
        case .timeout:
            return "Request timed out"
        case .modelNotFound:
            return "Model not available"
        case let .network(message):
            return "Network error: \(message)"
        case let .server(message):
            return "Server error: \(message)"
        case let .invalidResponse(message):
            return "Invalid response: \(message)"
        }
    }
}

// MARK: - Provider Protocol

public protocol LLMProviderClient: Sendable {
    var provider: LLMProviderKind { get }
    func isConfigured() -> Bool
    func transform(_ request: LLMRequest) async throws -> LLMResponse
    func availableModels() async throws -> [LLMModel]
}

extension LLMProviderClient {
    public func availableModels() async throws -> [LLMModel] {
        []
    }
}
