import Foundation
import OptimusClipCore

/// Ollama provider client that communicates with local Ollama server via HTTP.
public struct OllamaProviderClient: LLMProviderClient, Sendable {
    public let provider: LLMProviderKind = .ollama

    private let endpoint: URL

    public init(endpoint: URL) {
        self.endpoint = endpoint
    }

    public func isConfigured() -> Bool {
        true // Ollama is always "configured" if endpoint is set
    }

    public func transform(_ request: LLMRequest) async throws -> LLMResponse {
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

        let chatResponse = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
        return self.buildLLMResponse(chatResponse, startTime: startTime)
    }

    // MARK: - Helpers

    private func buildRequest(_ request: LLMRequest) throws -> URLRequest {
        let chatURL = self.endpoint.appendingPathComponent("api/chat")
        var urlRequest = URLRequest(url: chatURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // URLRequest timeout is a safety net; primary timeout is handled by async withTimeout wrapper
        // in LLMTransformation. Set this 50% longer to ensure async timeout fires first.
        urlRequest.timeoutInterval = request.timeout * 1.5

        let body = OllamaChatRequest(
            model: request.model,
            messages: [
                OllamaMessage(role: "system", content: LLMRequest.genericSystemPrompt),
                OllamaMessage(role: "user", content: request.formattedUserMessage)
            ],
            stream: false,
            options: OllamaOptions(temperature: request.temperature)
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
        case 404:
            throw LLMProviderError.modelNotFound
        case 500 ... 599:
            throw LLMProviderError.server("Ollama server error")
        default:
            throw LLMProviderError.server("HTTP \(httpResponse.statusCode)")
        }
    }

    private func buildLLMResponse(_ response: OllamaChatResponse, startTime: Date) -> LLMResponse {
        LLMResponse(
            provider: .ollama,
            model: response.model,
            output: response.message.content,
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
            .network("Cannot connect to Ollama server. Is it running?")
        case .dnsLookupFailed:
            .network("DNS lookup failed")
        default:
            .network(error.localizedDescription)
        }
    }
}

// MARK: - Ollama API Types

private struct OllamaChatRequest: Encodable {
    let model: String
    let messages: [OllamaMessage]
    let stream: Bool
    let options: OllamaOptions
}

private struct OllamaMessage: Codable {
    let role: String
    let content: String
}

private struct OllamaOptions: Encodable {
    let temperature: Double
}

private struct OllamaChatResponse: Decodable {
    let model: String
    let message: OllamaMessage
}
