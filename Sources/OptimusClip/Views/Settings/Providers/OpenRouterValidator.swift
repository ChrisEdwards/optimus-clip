import Foundation
import LLMChatOpenAI

// MARK: - OpenRouter API Validator

/// Validates OpenRouter API credentials by making a test API call.
/// OpenRouter provides access to 100+ models through an OpenAI-compatible API.
enum OpenRouterValidator {
    /// The OpenRouter API base URL.
    private static let baseURL = "https://openrouter.ai/api/v1"

    /// Validates an OpenRouter API key by making a minimal test request.
    /// - Parameter apiKey: The API key to validate.
    /// - Returns: A success message with model count.
    /// - Throws: An error if validation fails.
    static func validateAPIKey(_ apiKey: String) async throws -> String {
        // Basic format validation
        guard apiKey.hasPrefix("sk-or-") else {
            throw OpenRouterValidationError.invalidFormat
        }

        // Fetch models to validate the key and get model count
        let modelCount = try await Self.fetchModelCount(apiKey: apiKey)
        return "Connected (\(modelCount) models available)"
    }

    /// Fetches the count of available models from OpenRouter.
    /// - Parameter apiKey: The API key to use.
    /// - Returns: The number of available models.
    /// - Throws: An error if the request fails.
    private static func fetchModelCount(apiKey: String) async throws -> Int {
        let request = try buildModelsRequest(apiKey: apiKey)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            return try self.parseModelsResponse(data: data, response: response)
        } catch let error as OpenRouterValidationError {
            throw error
        } catch {
            throw self.mapNetworkError(error)
        }
    }

    private static func buildModelsRequest(apiKey: String) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/models") else {
            throw OpenRouterValidationError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15
        return request
    }

    private static func parseModelsResponse(data: Data, response: URLResponse) throws -> Int {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenRouterValidationError.unexpectedResponse
        }

        try self.validateStatusCode(httpResponse.statusCode)

        let modelsResponse = try JSONDecoder().decode(OpenRouterModelsResponse.self, from: data)
        return modelsResponse.data.count
    }

    private static func validateStatusCode(_ statusCode: Int) throws {
        switch statusCode {
        case 200:
            return
        case 401:
            throw OpenRouterValidationError.invalidAPIKey
        case 402:
            throw OpenRouterValidationError.insufficientCredits
        case 429:
            throw OpenRouterValidationError.rateLimited
        case 500 ... 599:
            throw OpenRouterValidationError.serverError(statusCode)
        default:
            throw OpenRouterValidationError.apiError(statusCode)
        }
    }

    private static func mapNetworkError(_ error: Error) -> OpenRouterValidationError {
        if let urlError = error as? URLError {
            return self.mapURLError(urlError)
        }
        if error is DecodingError {
            return .invalidResponse(error.localizedDescription)
        }
        return .networkError(error.localizedDescription)
    }

    private static func mapURLError(_ error: URLError) -> OpenRouterValidationError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            .noInternet
        case .timedOut:
            .timeout
        case .cannotFindHost, .cannotConnectToHost:
            .serverUnreachable
        default:
            .networkError(error.localizedDescription)
        }
    }
}

// MARK: - OpenRouter API Response Types

/// Response from OpenRouter /api/v1/models endpoint.
struct OpenRouterModelsResponse: Decodable {
    let data: [OpenRouterModel]
}

/// Model information from OpenRouter API.
struct OpenRouterModel: Decodable, Identifiable {
    let id: String
    let name: String?
    let description: String?
    let contextLength: Int?
    let pricing: Pricing?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case contextLength = "context_length"
        case pricing
    }

    struct Pricing: Decodable {
        let prompt: String?
        let completion: String?
    }
}

// MARK: - OpenRouter Validation Errors

/// Errors that can occur during OpenRouter API key validation.
enum OpenRouterValidationError: LocalizedError {
    case invalidFormat
    case invalidAPIKey
    case insufficientCredits
    case rateLimited
    case timeout
    case noInternet
    case serverUnreachable
    case serverError(Int)
    case apiError(Int)
    case networkError(String)
    case invalidResponse(String)
    case unexpectedResponse
    case invalidEndpoint

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            "Invalid API key format (should start with sk-or-)"
        case .invalidAPIKey:
            "Invalid API key. Get one at openrouter.ai/keys"
        case .insufficientCredits:
            "Insufficient credits. Add credits at openrouter.ai/credits"
        case .rateLimited:
            "Rate limited. Please wait a moment and try again"
        case .timeout:
            "Request timed out. Please try again"
        case .noInternet:
            "No internet connection. Check your network"
        case .serverUnreachable:
            "Cannot reach OpenRouter. Check your connection"
        case let .serverError(code):
            "OpenRouter server error (\(code)). Try again later"
        case let .apiError(code):
            "API error (\(code)). Check your API key"
        case let .networkError(message):
            "Network error: \(message)"
        case let .invalidResponse(message):
            "Invalid response: \(message)"
        case .unexpectedResponse:
            "Unexpected response from OpenRouter"
        case .invalidEndpoint:
            "Invalid OpenRouter endpoint"
        }
    }
}
