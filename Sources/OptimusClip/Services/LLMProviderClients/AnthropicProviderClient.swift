import Foundation
import OptimusClipCore

/// Anthropic provider client using direct HTTP calls to Anthropic Messages API.
public struct AnthropicProviderClient: LLMProviderClient, Sendable {
    public let provider: LLMProviderKind = .anthropic

    private let apiKey: String
    private static let apiVersion = "2023-06-01"

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

        let messagesResponse = try JSONDecoder().decode(AnthropicMessagesResponse.self, from: data)
        return self.buildLLMResponse(messagesResponse, startTime: startTime)
    }

    // MARK: - Helpers

    private func buildRequest(_ request: LLMRequest) throws -> URLRequest {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw LLMProviderError.invalidResponse("Invalid URL")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(self.apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        // URLRequest timeout is a safety net; primary timeout is handled by async withTimeout wrapper
        // in LLMTransformation. Set this 50% longer to ensure async timeout fires first.
        urlRequest.timeoutInterval = request.timeout * 1.5

        let body = AnthropicMessagesRequest(
            model: request.model,
            maxTokens: request.maxTokens ?? 4096,
            system: request.systemPrompt,
            messages: [AnthropicMessage(role: "user", content: request.text)],
            temperature: request.temperature
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
            throw LLMProviderError.rateLimited(retryAfter: self.parseRetryAfter(httpResponse))
        case 404:
            throw LLMProviderError.modelNotFound
        case 500 ... 599:
            throw LLMProviderError.server("Anthropic server error")
        default:
            throw LLMProviderError.server("HTTP \(httpResponse.statusCode)")
        }
    }

    private func parseRetryAfter(_ response: HTTPURLResponse) -> TimeInterval? {
        guard let retryValue = response.value(forHTTPHeaderField: "Retry-After") else {
            return nil
        }
        return TimeInterval(retryValue)
    }

    private func buildLLMResponse(_ response: AnthropicMessagesResponse, startTime: Date) -> LLMResponse {
        let output = response.content.first?.text ?? ""
        return LLMResponse(
            provider: .anthropic,
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
            .network("Cannot connect to Anthropic API")
        case .dnsLookupFailed:
            .network("DNS lookup failed")
        default:
            .network(error.localizedDescription)
        }
    }
}

// MARK: - Anthropic API Types

private struct AnthropicMessagesRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [AnthropicMessage]
    let temperature: Double

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system, messages, temperature
    }
}

private struct AnthropicMessage: Codable {
    let role: String
    let content: String
}

private struct AnthropicMessagesResponse: Decodable {
    let model: String
    let content: [AnthropicContent]
}

private struct AnthropicContent: Decodable {
    let type: String
    let text: String
}
