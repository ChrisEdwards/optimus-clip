import Foundation
import OptimusClipCore

/// OpenRouter provider client using OpenAI-compatible API.
public struct OpenRouterProviderClient: LLMProviderClient, Sendable {
    public let provider: LLMProviderKind = .openRouter

    private let apiKey: String

    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    public func isConfigured() -> Bool {
        !self.apiKey.isEmpty
    }

    public func transform(_ request: LLMRequest) async throws -> LLMResponse {
        guard self.isConfigured() else {
            throw LLMProviderError.notConfigured
        }

        let startTime = Date()
        let urlRequest = try self.buildRequest(request)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch let urlError as URLError {
            throw self.mapURLError(urlError)
        }

        try self.validateResponse(response)

        let chatResponse = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
        return self.buildLLMResponse(chatResponse, startTime: startTime)
    }

    // MARK: - Helpers

    private func buildRequest(_ request: LLMRequest) throws -> URLRequest {
        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
            throw LLMProviderError.invalidResponse("Invalid URL")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("OptimusClip", forHTTPHeaderField: "HTTP-Referer")
        urlRequest.setValue("OptimusClip", forHTTPHeaderField: "X-Title")
        urlRequest.timeoutInterval = request.timeout

        let body = OpenRouterRequest(
            model: request.model,
            messages: [
                OpenRouterMessage(role: "system", content: request.systemPrompt),
                OpenRouterMessage(role: "user", content: request.text)
            ],
            temperature: request.temperature,
            maxTokens: request.maxTokens
        )
        urlRequest.httpBody = try JSONEncoder().encode(body)
        return urlRequest
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMProviderError.invalidResponse("Invalid response type")
        }

        switch httpResponse.statusCode {
        case 200:
            return
        case 401:
            throw LLMProviderError.authenticationError
        case 429:
            throw LLMProviderError.rateLimited(retryAfter: nil)
        case 404:
            throw LLMProviderError.modelNotFound
        case 500 ... 599:
            throw LLMProviderError.server("OpenRouter server error")
        default:
            throw LLMProviderError.server("HTTP \(httpResponse.statusCode)")
        }
    }

    private func buildLLMResponse(_ response: OpenRouterResponse, startTime: Date) -> LLMResponse {
        let output = response.choices.first?.message.content ?? ""
        return LLMResponse(
            provider: .openRouter,
            model: response.model,
            output: output,
            duration: Date().timeIntervalSince(startTime)
        )
    }

    private func mapURLError(_ error: URLError) -> LLMProviderError {
        switch error.code {
        case .timedOut:
            .timeout
        case .notConnectedToInternet:
            .network("No internet connection")
        case .networkConnectionLost:
            .network("Connection lost")
        case .cannotFindHost, .cannotConnectToHost:
            .network("Cannot connect to OpenRouter API")
        case .dnsLookupFailed:
            .network("DNS lookup failed")
        default:
            .network(error.localizedDescription)
        }
    }
}

// MARK: - OpenRouter API Types

private struct OpenRouterRequest: Encodable {
    let model: String
    let messages: [OpenRouterMessage]
    let temperature: Double
    let maxTokens: Int?

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

private struct OpenRouterMessage: Codable {
    let role: String
    let content: String
}

private struct OpenRouterResponse: Decodable {
    let model: String
    let choices: [OpenRouterChoice]
}

private struct OpenRouterChoice: Decodable {
    let message: OpenRouterMessage
}
