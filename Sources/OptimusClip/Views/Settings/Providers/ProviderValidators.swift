import Foundation
import LLMChatOpenAI

// MARK: - OpenAI API Validator

/// Validates OpenAI API credentials by making a test API call.
enum OpenAIValidator {
    /// Validates an OpenAI API key by making a minimal test request.
    /// - Parameter apiKey: The API key to validate.
    /// - Returns: A success message describing the validated key.
    /// - Throws: An error if validation fails.
    static func validateAPIKey(_ apiKey: String) async throws -> String {
        // Basic format validation
        guard apiKey.hasPrefix("sk-") else {
            throw OpenAIValidationError.invalidFormat
        }

        // Make a minimal API call to validate the key
        let chat = LLMChatOpenAI(apiKey: apiKey)
        let messages = [ChatMessage(role: .user, content: "Hi")]

        do {
            // Use a cheap, fast model for validation
            let completion = try await chat.send(model: "gpt-4o-mini", messages: messages)

            // Extract model info from response
            let modelUsed = completion.model
            return "Connected to OpenAI (\(modelUsed))"
        } catch let error as LLMChatOpenAIError {
            throw Self.mapError(error)
        }
    }

    private static func mapError(_ error: LLMChatOpenAIError) -> OpenAIValidationError {
        switch error {
        case let .serverError(statusCode, message):
            switch statusCode {
            case 401:
                .invalidAPIKey
            case 429:
                .rateLimited
            case 500 ... 599:
                .serverError(message)
            default:
                .apiError(statusCode, message)
            }
        case .networkError:
            .networkError
        case .cancelled:
            .cancelled
        case .decodingError:
            .unexpectedResponse
        case .streamError:
            .unexpectedResponse
        }
    }
}

/// Errors that can occur during OpenAI API key validation.
enum OpenAIValidationError: LocalizedError {
    case invalidFormat
    case invalidAPIKey
    case rateLimited
    case networkError
    case serverError(String)
    case apiError(Int, String)
    case unexpectedResponse
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            "Invalid API key format (should start with sk-)"
        case .invalidAPIKey:
            "Invalid API key. Check your key at platform.openai.com"
        case .rateLimited:
            "Rate limited. Please wait a moment and try again"
        case .networkError:
            "Network error. Check your internet connection"
        case let .serverError(message):
            "OpenAI server error: \(message)"
        case let .apiError(code, message):
            "API error (\(code)): \(message)"
        case .unexpectedResponse:
            "Unexpected response from OpenAI"
        case .cancelled:
            "Validation cancelled"
        }
    }
}

// MARK: - Ollama Connection Validator

/// Validates Ollama connection by fetching available models from the local server.
enum OllamaValidator {
    /// Tests connection to Ollama server and returns available model count.
    /// - Parameters:
    ///   - host: The Ollama server host (e.g., "http://localhost")
    ///   - port: The Ollama server port (e.g., "11434")
    /// - Returns: A success message with model count.
    /// - Throws: An error if connection fails.
    static func testConnection(host: String, port: String) async throws -> String {
        let url = try buildURL(host: host, port: port)
        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            return try self.parseResponse(data: data, response: response)
        } catch let error as OllamaValidationError {
            throw error
        } catch {
            throw self.mapError(error)
        }
    }

    private static func buildURL(host: String, port: String) throws -> URL {
        let baseHost = host.hasPrefix("http") ? host : "http://\(host)"
        let urlString = "\(baseHost):\(port)/api/tags"
        guard let url = URL(string: urlString) else {
            throw OllamaValidationError.invalidEndpoint
        }
        return url
    }

    private static func parseResponse(data: Data, response: URLResponse) throws -> String {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaValidationError.unexpectedResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw OllamaValidationError.serverError(httpResponse.statusCode)
        }

        let tagsResponse = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
        return self.formatModelList(tagsResponse.models)
    }

    private static func formatModelList(_ models: [OllamaModel]) -> String {
        if models.isEmpty {
            return "Connected (no models installed - run: ollama pull llama3.2)"
        }
        let modelNames = models.prefix(3).map(\.name).joined(separator: ", ")
        let suffix = models.count > 3 ? "..." : ""
        return "Connected (\(models.count) models: \(modelNames)\(suffix))"
    }

    private static func mapError(_ error: Error) -> OllamaValidationError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotConnectToHost, .networkConnectionLost:
                return .notRunning
            case .timedOut:
                return .timeout
            default:
                return .networkError(urlError.localizedDescription)
            }
        }
        if error is DecodingError {
            return .invalidResponse(error.localizedDescription)
        }
        return .networkError(error.localizedDescription)
    }
}

/// Response from Ollama /api/tags endpoint.
struct OllamaTagsResponse: Decodable {
    let models: [OllamaModel]
}

/// Model info from Ollama /api/tags response.
struct OllamaModel: Decodable {
    let name: String
    let size: Int64?
    let digest: String?
}

/// Errors that can occur during Ollama connection validation.
enum OllamaValidationError: LocalizedError {
    case invalidEndpoint
    case notRunning
    case timeout
    case serverError(Int)
    case networkError(String)
    case invalidResponse(String)
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            "Invalid Ollama endpoint. Check host and port."
        case .notRunning:
            "Ollama not running. Start with: ollama serve"
        case .timeout:
            "Connection timed out. Check if Ollama is running."
        case let .serverError(code):
            "Ollama server error (\(code))"
        case let .networkError(message):
            "Network error: \(message)"
        case let .invalidResponse(message):
            "Invalid response: \(message)"
        case .unexpectedResponse:
            "Unexpected response from Ollama"
        }
    }
}
