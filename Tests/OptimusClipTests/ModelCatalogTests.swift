import Foundation
import Testing
@testable import OptimusClipCore

@Suite("Model Catalog")
struct ModelCatalogTests {
    @Test("returns cached models when entry is still fresh")
    func returnsCachedModelsWhenFresh() async throws {
        let baseDate = Date()
        let cache = self.makeCache()
        let cachedModel = LLMModel(id: "gpt-4o-mini", provider: .openAI)
        await cache.save(
            models: [cachedModel],
            key: ModelProviderConfig.openAI(apiKey: "sk-test").cacheKey,
            fetchedAt: baseDate,
            expiresAt: baseDate.addingTimeInterval(3600)
        )

        let catalog = ModelCatalog(
            httpClient: FailingHTTPClient(),
            cache: cache,
            now: { baseDate }
        )

        let result = try await catalog.models(for: .openAI(apiKey: "sk-test"))
        #expect(result == [cachedModel])
    }

    @Test("fetches and caches OpenRouter models when cache is empty")
    func fetchesOpenRouterAndCaches() async throws {
        let mockClient = MockHTTPClient()
        guard let openRouterURL = URL(string: "https://openrouter.ai/api/v1/models") else {
            throw TestError.invalidURL
        }

        let responseData = try self.makeOpenRouterResponseData()
        let decoder = JSONDecoder()
        let parsed = try decoder.decode(OpenRouterModelsResponse.self, from: responseData)
        #expect(parsed.data.count == 1)

        await mockClient.enqueue(
            data: responseData,
            statusCode: 200,
            url: openRouterURL
        )

        let time = MutableNow()
        let cache = self.makeCache()
        let catalog = ModelCatalog(
            httpClient: mockClient,
            cache: cache,
            now: { time.value }
        )

        let config = ModelProviderConfig.openRouter(apiKey: "sk-or-test")

        let first = try await catalog.models(for: config)
        #expect(first.count == 1)
        #expect(first.first?.id == "openrouter/anthropic/claude-3.5-sonnet")
        #expect(await mockClient.callCount() == 1)

        // Advance time but keep within cache TTL (12h) to verify cache hit.
        time.value = time.value.addingTimeInterval(3600)
        let second = try await catalog.models(for: config)
        #expect(second == first)
        #expect(await mockClient.callCount() == 1)
    }

    @Test("OpenRouter model fetch includes required headers")
    func openRouterFetchIncludesHeaders() async throws {
        let mockClient = MockHTTPClient()
        guard let openRouterURL = URL(string: "https://openrouter.ai/api/v1/models") else {
            throw TestError.invalidURL
        }

        try await mockClient.enqueue(
            data: self.makeOpenRouterResponseData(),
            statusCode: 200,
            url: openRouterURL
        )

        let catalog = ModelCatalog(
            httpClient: mockClient,
            cache: self.makeCache(),
            now: { Date() }
        )

        #expect(ModelCatalog.openRouterReferer() == "https://optimusclip.app")
        #expect(ModelCatalog.openRouterTitle() == "Optimus Clip")

        _ = try await catalog.models(for: .openRouter(apiKey: "sk-or-test"))

        #expect(await mockClient.callCount() == 1)

        let headers = try #require(await mockClient.lastHeaders())
        print("Captured headers:", headers)
        #expect(headers.isEmpty == false, "headers: \(headers)")
        #expect(headers["Authorization"] == "Bearer sk-or-test")
        let referer = headers["HTTP-Referer"] ?? headers["Referer"]
        #expect(referer == "https://optimusclip.app", "headers: \(headers)")
        #expect(headers["X-Title"] == "Optimus Clip", "headers: \(headers)")
    }

    @Test("falls back to stale cache when live fetch fails")
    func fallsBackToStaleCache() async throws {
        let pastDate = Date().addingTimeInterval(-7200)
        let cache = self.makeCache()
        let config = ModelProviderConfig.openAI(apiKey: "sk-late")
        let staleModel = LLMModel(id: "gpt-4o", provider: .openAI)

        await cache.save(
            models: [staleModel],
            key: config.cacheKey,
            fetchedAt: pastDate,
            expiresAt: pastDate.addingTimeInterval(60) // expired
        )

        let catalog = ModelCatalog(
            httpClient: FailingHTTPClient(),
            cache: cache,
            now: { Date() }
        )

        let result = try await catalog.models(for: config)
        #expect(result == [staleModel])
    }

    @Test("ollama bypasses cache and always refreshes")
    func ollamaBypassesCache() async throws {
        let responseJSON = """
        { "models": [ { "name": "llama3.2" } ] }
        """

        let mockClient = MockHTTPClient()
        guard let tagsURL = URL(string: "http://localhost:11434/api/tags"),
              let hostURL = URL(string: "http://localhost:11434") else {
            throw TestError.invalidURL
        }
        await mockClient.enqueue(
            data: Data(responseJSON.utf8),
            statusCode: 200,
            url: tagsURL
        )
        await mockClient.enqueue(
            data: Data(responseJSON.utf8),
            statusCode: 200,
            url: tagsURL
        )

        let time = MutableNow()
        let cache = self.makeCache()
        let catalog = ModelCatalog(
            httpClient: mockClient,
            cache: cache,
            now: { time.value }
        )

        let config = ModelProviderConfig.ollama(host: hostURL)

        _ = try await catalog.models(for: config)
        #expect(await mockClient.callCount() == 1)

        time.value = time.value.addingTimeInterval(10000)
        _ = try await catalog.models(for: config)
        #expect(await mockClient.callCount() == 2)
    }

    // MARK: - Helpers

    private func makeCache() -> ModelCache {
        let suiteName = "ModelCatalogTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return ModelCache(userDefaults: defaults, storagePrefix: "\(suiteName).")
    }

    private func makeOpenRouterResponseData() throws -> Data {
        let responsePayload: [String: Any] = [
            "data": [
                [
                    "id": "openrouter/anthropic/claude-3.5-sonnet",
                    "name": "Claude 3.5 Sonnet",
                    "context_length": 200_000,
                    "pricing": [
                        "prompt": "0.003",
                        "completion": "0.015"
                    ]
                ]
            ]
        ]

        return try JSONSerialization.data(
            withJSONObject: responsePayload,
            options: [.withoutEscapingSlashes]
        )
    }
}

// MARK: - Test Doubles

private enum TestError: Error {
    case network
    case noQueuedResponse
    case invalidURL
}

private struct FailingHTTPClient: HTTPClient {
    func data(for _: URLRequest) async throws -> (Data, URLResponse) {
        throw TestError.network
    }
}

private actor MockHTTPClient: HTTPClient {
    private var queue: [Result<(Data, URLResponse), Error>] = []
    private var calls = 0
    private var lastCapturedRequest: URLRequest?
    private var lastCapturedHeaders: [String: String]?

    func enqueue(data: Data, statusCode: Int, url: URL) {
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        ) else {
            return
        }
        self.queue.append(.success((data, response)))
    }

    func enqueue(error: Error) {
        self.queue.append(.failure(error))
    }

    func callCount() -> Int {
        self.calls
    }

    func lastRequest() -> URLRequest? {
        self.lastCapturedRequest
    }

    func lastHeaders() -> [String: String]? {
        self.lastCapturedHeaders
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        self.lastCapturedRequest = request
        self.lastCapturedHeaders = request.allHTTPHeaderFields
        self.calls += 1
        guard !self.queue.isEmpty else {
            throw TestError.noQueuedResponse
        }

        let result = self.queue.removeFirst()
        switch result {
        case let .success(value):
            return value
        case let .failure(error):
            throw error
        }
    }
}

private final class MutableNow: @unchecked Sendable {
    var value: Date

    init(value: Date = Date()) {
        self.value = value
    }
}
