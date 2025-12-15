import Foundation
import LLMChatOpenAI

// MARK: - OpenAI API Validator

/// Validates OpenAI API credentials by making a test API call.
enum OpenAIValidator {
    /// Validates an OpenAI API key by making a minimal test request.
    /// - Parameter apiKey: The API key to validate.
    /// - Parameter modelId: Optional model ID to use for validation.
    /// - Returns: A success message describing the validated key.
    /// - Throws: An error if validation fails.
    static func validateAPIKey(_ apiKey: String, modelId: String? = nil) async throws -> String {
        // Basic format validation
        guard apiKey.hasPrefix("sk-") else {
            throw OpenAIValidationError.invalidFormat
        }

        // Make a minimal API call to validate the key
        let chat = LLMChatOpenAI(apiKey: apiKey)
        let messages = [ChatMessage(role: .user, content: "Hi")]

        do {
            // Use specified model or default to gpt-4o-mini for validation
            let model = modelId ?? "gpt-4o-mini"
            let completion = try await chat.send(model: model, messages: messages)

            // Extract model info from response
            let modelUsed = completion.model
            return "Connected to OpenAI (\(modelUsed))"
        } catch let error as LLMChatOpenAIError {
            throw Self.mapError(error)
        }
    }

    /// Fetches available models from OpenAI API.
    /// - Parameter apiKey: The API key to use.
    /// - Returns: Array of available model IDs.
    static func listModels(apiKey: String) async throws -> [OpenAIModel] {
        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            throw OpenAIValidationError.unexpectedResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIValidationError.unexpectedResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw OpenAIValidationError.invalidAPIKey
            }
            throw OpenAIValidationError.apiError(httpResponse.statusCode, "Failed to fetch models")
        }

        let modelsResponse = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
        // Filter to only chat/completion models, sorted by ID
        return modelsResponse.data
            .filter { Self.isChatModel($0.id) }
            .sorted { $0.id < $1.id }
    }

    /// Checks if a model ID is a chat/completion model (not embedding, tts, etc.)
    private static func isChatModel(_ modelId: String) -> Bool {
        let chatPrefixes = ["gpt-", "o1-", "o3-", "chatgpt-"]
        let excludePrefixes = ["gpt-4-vision", "whisper", "tts", "dall-e", "text-embedding"]

        let isChat = chatPrefixes.contains { modelId.lowercased().hasPrefix($0) }
        let isExcluded = excludePrefixes.contains { modelId.lowercased().contains($0) }

        return isChat && !isExcluded
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

// MARK: - OpenAI API Response Types

/// Response from OpenAI /v1/models endpoint.
struct OpenAIModelsResponse: Decodable {
    let data: [OpenAIModel]
}

/// Model information from OpenAI API.
struct OpenAIModel: Decodable, Identifiable, Hashable {
    let id: String
    let ownedBy: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownedBy = "owned_by"
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
    ///   - modelId: Optional model ID to validate
    /// - Returns: A success message with model count.
    /// - Throws: An error if connection fails.
    static func testConnection(host: String, port: String, modelId: String? = nil) async throws -> String {
        let models = try await self.listModels(host: host, port: port)
        let message = self.formatModelList(models)

        // If a model is specified, verify it exists
        if let modelId, !modelId.isEmpty {
            let exists = models.contains { $0.name == modelId || $0.name.hasPrefix(modelId) }
            if !exists {
                return "\(message) - Warning: '\(modelId)' not found locally"
            }
        }

        return message
    }

    /// Fetches available models from Ollama server.
    /// - Parameters:
    ///   - host: The Ollama server host (e.g., "http://localhost")
    ///   - port: The Ollama server port (e.g., "11434")
    /// - Returns: Array of available models.
    static func listModels(host: String, port: String) async throws -> [OllamaModel] {
        let url = try self.buildURL(host: host, port: port)
        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw OllamaValidationError.unexpectedResponse
            }
            guard httpResponse.statusCode == 200 else {
                throw OllamaValidationError.serverError(httpResponse.statusCode)
            }

            let tagsResponse = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
            return tagsResponse.models.sorted { $0.name < $1.name }
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
