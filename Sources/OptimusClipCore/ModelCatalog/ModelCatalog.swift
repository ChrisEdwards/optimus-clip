import Foundation

// MARK: - Public Types

/// Supported LLM model providers.
/// Note: Raw values match `LLMProviderKind` from LLMProvider.swift for consistency.
public enum ModelProvider: String, Codable, CaseIterable, Sendable {
    case openAI
    case anthropic
    case openRouter
    case ollama
    case awsBedrock
}

/// Metadata describing an individual LLM model.
public struct LLMModel: Codable, Hashable, Sendable {
    public struct Pricing: Codable, Hashable, Sendable {
        public let prompt: String?
        public let completion: String?

        public init(prompt: String?, completion: String?) {
            self.prompt = prompt
            self.completion = completion
        }
    }

    public let id: String
    public let name: String
    public let provider: ModelProvider
    public let contextLength: Int?
    public let pricing: Pricing?
    public let isDeprecated: Bool

    public init(
        id: String,
        name: String? = nil,
        provider: ModelProvider,
        contextLength: Int? = nil,
        pricing: Pricing? = nil,
        isDeprecated: Bool = false
    ) {
        self.id = id
        self.name = name ?? id
        self.provider = provider
        self.contextLength = contextLength
        self.pricing = pricing
        self.isDeprecated = isDeprecated
    }
}

/// Configuration for fetching models for a provider.
public struct ModelProviderConfig: Sendable {
    public let provider: ModelProvider
    public let apiKey: String?
    public let host: URL?
    public let region: String?

    public init(
        provider: ModelProvider,
        apiKey: String? = nil,
        host: URL? = nil,
        region: String? = nil
    ) {
        self.provider = provider
        self.apiKey = apiKey
        self.host = host
        self.region = region
    }

    public static func openAI(apiKey: String) -> Self {
        ModelProviderConfig(provider: .openAI, apiKey: apiKey)
    }

    public static func anthropic() -> Self {
        ModelProviderConfig(provider: .anthropic)
    }

    public static func openRouter(apiKey: String) -> Self {
        ModelProviderConfig(provider: .openRouter, apiKey: apiKey)
    }

    public static func ollama(host: URL) -> Self {
        ModelProviderConfig(provider: .ollama, host: host)
    }

    public static func awsBedrock(region: String) -> Self {
        ModelProviderConfig(provider: .awsBedrock, region: region)
    }

    /// Cache TTL in seconds for the provider.
    var cacheTTL: TimeInterval {
        switch self.provider {
        case .openAI:
            24 * 60 * 60
        case .openRouter:
            12 * 60 * 60
        case .ollama:
            0
        case .anthropic, .awsBedrock:
            7 * 24 * 60 * 60
        }
    }

    /// Unique key for cache isolation per provider + configuration.
    var cacheKey: String {
        var components: [String] = [self.provider.rawValue]
        if let region {
            components.append(region)
        }
        if let host {
            components.append(host.absoluteString)
        }
        return components.joined(separator: "::")
    }
}

/// Errors that can occur during model fetching.
public enum ModelCatalogError: LocalizedError, Equatable {
    case missingAPIKey(ModelProvider)
    case invalidEndpoint
    case httpError(Int)
    case unexpectedResponse
    case decodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .missingAPIKey(provider):
            "API key required for \(provider.rawValue)"
        case .invalidEndpoint:
            "Invalid endpoint for model fetch"
        case let .httpError(status):
            "Request failed with status \(status)"
        case .unexpectedResponse:
            "Unexpected response from model API"
        case let .decodingFailed(message):
            "Unable to parse model response: \(message)"
        }
    }
}

// MARK: - HTTP Client Abstraction

public protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await self.session.data(for: request)
    }
}

// MARK: - Cache

public actor ModelCache {
    private let userDefaults: UserDefaults
    private let storagePrefix: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(userDefaults: UserDefaults = .standard, storagePrefix: String = "model_cache.") {
        self.userDefaults = userDefaults
        self.storagePrefix = storagePrefix
    }

    public func loadFresh(key: String, now: Date) -> [LLMModel]? {
        guard let entry = self.entry(for: key) else {
            return nil
        }
        guard entry.expiresAt >= now else {
            return nil
        }
        return entry.models
    }

    public func loadStale(key: String) -> [LLMModel]? {
        self.entry(for: key)?.models
    }

    public func save(models: [LLMModel], key: String, fetchedAt: Date, expiresAt: Date) {
        let entry = CacheEntry(models: models, fetchedAt: fetchedAt, expiresAt: expiresAt)
        guard let data = try? self.encoder.encode(entry) else {
            return
        }
        self.userDefaults.set(data, forKey: self.defaultsKey(for: key))
    }

    public func clear(key: String) {
        self.userDefaults.removeObject(forKey: self.defaultsKey(for: key))
    }

    private func entry(for key: String) -> CacheEntry? {
        guard let data = self.userDefaults.data(forKey: self.defaultsKey(for: key)) else {
            return nil
        }
        do {
            return try self.decoder.decode(CacheEntry.self, from: data)
        } catch {
            return nil
        }
    }

    private func defaultsKey(for key: String) -> String {
        "\(self.storagePrefix)\(key)"
    }

    private struct CacheEntry: Codable, Sendable {
        let models: [LLMModel]
        let fetchedAt: Date
        let expiresAt: Date
    }
}

// MARK: - Model Catalog

public actor ModelCatalog {
    private let httpClient: any HTTPClient
    private let cache: ModelCache
    private let now: () -> Date
    private let decoder = JSONDecoder()

    public init(
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        cache: ModelCache = ModelCache(),
        now: @escaping () -> Date = Date.init
    ) {
        self.httpClient = httpClient
        self.cache = cache
        self.now = now
    }

    /// Fetch models, using cache when available and falling back to stale cache or minimal defaults on failures.
    public func models(for config: ModelProviderConfig) async throws -> [LLMModel] {
        let cacheKey = config.cacheKey
        let now = self.now()

        if let cached = await self.cache.loadFresh(key: cacheKey, now: now) {
            return cached
        }

        do {
            let models = try await self.fetchLive(for: config)

            if config.cacheTTL > 0 {
                let expiresAt = now.addingTimeInterval(config.cacheTTL)
                await self.cache.save(models: models, key: cacheKey, fetchedAt: now, expiresAt: expiresAt)
            } else {
                await self.cache.clear(key: cacheKey)
            }

            return models
        } catch {
            if let stale = await self.cache.loadStale(key: cacheKey) {
                return stale
            }
            if let fallback = self.fallbackModels(for: config) {
                return fallback
            }
            throw error
        }
    }

    public func cachedModels(for config: ModelProviderConfig) async -> [LLMModel]? {
        await self.cache.loadFresh(key: config.cacheKey, now: self.now())
    }

    public func clearCache(for config: ModelProviderConfig) async {
        await self.cache.clear(key: config.cacheKey)
    }

    // MARK: - Live Fetchers

    private func fetchLive(for config: ModelProviderConfig) async throws -> [LLMModel] {
        switch config.provider {
        case .openAI:
            guard let apiKey = config.apiKey else {
                throw ModelCatalogError.missingAPIKey(.openAI)
            }
            return try await self.fetchOpenAIModels(apiKey: apiKey)
        case .openRouter:
            guard let apiKey = config.apiKey else {
                throw ModelCatalogError.missingAPIKey(.openRouter)
            }
            return try await self.fetchOpenRouterModels(apiKey: apiKey)
        case .ollama:
            let host = config.host ?? URL(string: "http://localhost:11434")
            guard let resolvedHost = host else {
                throw ModelCatalogError.invalidEndpoint
            }
            return try await self.fetchOllamaModels(host: resolvedHost)
        case .anthropic:
            return self.staticAnthropicModels()
        case .awsBedrock:
            let region = config.region ?? "us-east-1"
            return self.staticBedrockModels(region: region)
        }
    }

    private func fetchOpenAIModels(apiKey: String) async throws -> [LLMModel] {
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            throw ModelCatalogError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await self.httpClient.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ModelCatalogError.unexpectedResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw ModelCatalogError.httpError(httpResponse.statusCode)
        }

        do {
            let result = try self.decoder.decode(OpenAIModelsResponse.self, from: data)
            let chatModels = result.data.filter { self.isChatModel(id: $0.id) }
            return chatModels.map { model in
                LLMModel(id: model.id, provider: .openAI, contextLength: nil, pricing: nil, isDeprecated: false)
            }
        } catch {
            throw ModelCatalogError.decodingFailed(error.localizedDescription)
        }
    }

    private func fetchOpenRouterModels(apiKey: String) async throws -> [LLMModel] {
        guard let url = URL(string: "https://openrouter.ai/api/v1/models") else {
            throw ModelCatalogError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await self.httpClient.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ModelCatalogError.unexpectedResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw ModelCatalogError.httpError(httpResponse.statusCode)
        }

        do {
            let result = try self.decoder.decode(OpenRouterModelsResponse.self, from: data)
            return result.data.map { model in
                let pricing = LLMModel.Pricing(
                    prompt: model.pricing?.prompt,
                    completion: model.pricing?.completion
                )
                return LLMModel(
                    id: model.id,
                    name: model.name ?? model.id,
                    provider: .openRouter,
                    contextLength: model.contextLength,
                    pricing: pricing,
                    isDeprecated: model.deprecated ?? false
                )
            }
        } catch {
            throw ModelCatalogError.decodingFailed(error.localizedDescription)
        }
    }

    private func fetchOllamaModels(host: URL) async throws -> [LLMModel] {
        var components = URLComponents(url: host, resolvingAgainstBaseURL: false)
        let basePath = components?.path ?? ""
        let normalizedPath: String = if basePath.hasSuffix("/api/tags") {
            basePath
        } else if basePath.isEmpty || basePath == "/" {
            "/api/tags"
        } else {
            basePath.appending("/api/tags")
        }
        components?.path = normalizedPath

        guard let url = components?.url else {
            throw ModelCatalogError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        let (data, response) = try await self.httpClient.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ModelCatalogError.unexpectedResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw ModelCatalogError.httpError(httpResponse.statusCode)
        }

        do {
            let result = try self.decoder.decode(OllamaTagsResponse.self, from: data)
            return result.models.map { model in
                LLMModel(
                    id: model.name,
                    name: model.name,
                    provider: .ollama,
                    contextLength: nil,
                    pricing: nil,
                    isDeprecated: false
                )
            }
        } catch {
            throw ModelCatalogError.decodingFailed(error.localizedDescription)
        }
    }

    // MARK: - Static / Fallback Lists

    private func staticAnthropicModels() -> [LLMModel] {
        [
            LLMModel(id: "claude-3-opus-20240229", provider: .anthropic, contextLength: 200_000),
            LLMModel(id: "claude-3-sonnet-20240229", provider: .anthropic, contextLength: 200_000),
            LLMModel(id: "claude-3-haiku-20240307", provider: .anthropic, contextLength: 200_000),
            LLMModel(id: "claude-3-5-sonnet-20241022", provider: .anthropic, contextLength: 200_000)
        ]
    }

    private func staticBedrockModels(region: String) -> [LLMModel] {
        let models = [
            LLMModel(id: "anthropic.claude-3-haiku-20240307-v1:0", provider: .awsBedrock, contextLength: 200_000),
            LLMModel(id: "anthropic.claude-3-sonnet-20240229-v1:0", provider: .awsBedrock, contextLength: 200_000),
            LLMModel(id: "anthropic.claude-3-opus-20240229-v1:0", provider: .awsBedrock, contextLength: 200_000),
            LLMModel(id: "anthropic.claude-3-5-sonnet-20241022-v2:0", provider: .awsBedrock, contextLength: 200_000),
            LLMModel(id: "meta.llama3-8b-instruct-v1:0", provider: .awsBedrock, contextLength: 8000)
        ]
        return models.map { model in
            LLMModel(
                id: model.id,
                name: "\(model.name) (\(region))",
                provider: model.provider,
                contextLength: model.contextLength,
                pricing: model.pricing,
                isDeprecated: model.isDeprecated
            )
        }
    }

    private func fallbackModels(for config: ModelProviderConfig) -> [LLMModel]? {
        switch config.provider {
        case .openAI:
            [
                LLMModel(id: "gpt-4o", provider: .openAI),
                LLMModel(id: "gpt-4o-mini", provider: .openAI)
            ]
        case .openRouter:
            [
                LLMModel(
                    id: "openrouter/anthropic/claude-3.5-sonnet",
                    name: "Claude 3.5 Sonnet",
                    provider: .openRouter
                ),
                LLMModel(
                    id: "openrouter/openai/gpt-4o",
                    name: "GPT-4o (OpenRouter)",
                    provider: .openRouter
                ),
                LLMModel(
                    id: "openrouter/google/gemini-flash-1.5",
                    name: "Gemini Flash 1.5",
                    provider: .openRouter
                )
            ]
        case .ollama:
            nil
        case .anthropic:
            self.staticAnthropicModels()
        case .awsBedrock:
            self.staticBedrockModels(region: config.region ?? "us-east-1")
        }
    }

    // MARK: - Helpers

    private func isChatModel(id: String) -> Bool {
        id.contains("gpt") || id.hasPrefix("o1")
    }
}
