import Foundation
import OptimusClipCore

/// OpenAI provider client using direct HTTP calls to OpenAI Chat Completions API.
public struct OpenAIProviderClient: LLMProviderClient, Sendable {
    public let provider: LLMProviderKind = .openAI

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

        try self.validateResponse(response, data: data)

        let chatResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        return self.buildLLMResponse(chatResponse, startTime: startTime)
    }

    // MARK: - Helpers

    private func buildRequest(_ request: LLMRequest) throws -> URLRequest {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw LLMProviderError.invalidResponse("Invalid URL")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
        // URLRequest timeout is a safety net; primary timeout is handled by async withTimeout wrapper
        // in LLMTransformation. Set this 50% longer to ensure async timeout fires first.
        urlRequest.timeoutInterval = request.timeout * 1.5

        let body = OpenAIChatRequest(
            model: request.model,
            messages: [
                OpenAIMessage(role: "system", content: LLMRequest.genericSystemPrompt),
                OpenAIMessage(role: "user", content: request.formattedUserMessage)
            ],
            temperature: request.temperature,
            maxTokens: 12000
        )
        urlRequest.httpBody = try JSONEncoder().encode(body)
        return urlRequest
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
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
            throw LLMProviderError.server("OpenAI server error")
        default:
            // Try to parse error message from OpenAI's response
            let errorMessage = self.parseErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
            throw LLMProviderError.server(errorMessage)
        }
    }

    private func parseErrorMessage(from data: Data) -> String? {
        // OpenAI error format: {"error":{"message":"...","type":"...","code":"..."}}
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let errorObj = json["error"] as? [String: Any],
              let message = errorObj["message"] as? String else {
            return nil
        }
        return message
    }

    private func parseRetryAfter(_ response: HTTPURLResponse) -> TimeInterval? {
        guard let retryValue = response.value(forHTTPHeaderField: "Retry-After") else {
            return nil
        }
        return TimeInterval(retryValue)
    }

    private func buildLLMResponse(_ chatResponse: OpenAIChatResponse, startTime: Date) -> LLMResponse {
        let output = chatResponse.choices.first?.message.content ?? ""
        return LLMResponse(
            provider: .openAI,
            model: chatResponse.model,
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
            .network("Cannot connect to OpenAI API")
        case .dnsLookupFailed:
            .network("DNS lookup failed")
        default:
            .network(error.localizedDescription)
        }
    }
}

// MARK: - OpenAI API Types

private struct OpenAIChatRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

private struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

private struct OpenAIChatResponse: Decodable {
    let model: String
    let choices: [OpenAIChoice]
}

private struct OpenAIChoice: Decodable {
    let message: OpenAIMessage
}
