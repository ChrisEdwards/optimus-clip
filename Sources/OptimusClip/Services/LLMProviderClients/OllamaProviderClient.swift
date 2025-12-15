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
        let chatURL = self.endpoint.appendingPathComponent("api/chat")

        var urlRequest = URLRequest(url: chatURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = request.timeout

        let body = OllamaChatRequest(
            model: request.model,
            messages: [
                OllamaMessage(role: "system", content: request.systemPrompt),
                OllamaMessage(role: "user", content: request.text)
            ],
            stream: false,
            options: OllamaOptions(temperature: request.temperature)
        )

        urlRequest.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMProviderError.invalidResponse("Invalid response type")
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 404:
            throw LLMProviderError.modelNotFound
        case 500 ... 599:
            throw LLMProviderError.server("Ollama server error")
        default:
            throw LLMProviderError.server("HTTP \(httpResponse.statusCode)")
        }

        let chatResponse = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
        let duration = Date().timeIntervalSince(startTime)

        return LLMResponse(
            provider: .ollama,
            model: chatResponse.model,
            output: chatResponse.message.content,
            duration: duration
        )
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
