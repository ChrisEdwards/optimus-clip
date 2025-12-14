import Foundation
import LLMChatAnthropic

// MARK: - Anthropic API Validator

/// Validates Anthropic API credentials by making a test API call.
enum AnthropicValidator {
    /// Validates an Anthropic API key by making a minimal test request.
    /// - Parameter apiKey: The API key to validate.
    /// - Returns: A success message describing the validated key.
    /// - Throws: An error if validation fails.
    static func validateAPIKey(_ apiKey: String) async throws -> String {
        // Basic format validation
        guard apiKey.hasPrefix("sk-ant-") else {
            throw AnthropicValidationError.invalidFormat
        }

        // Make a minimal API call to validate the key
        let chat = LLMChatAnthropic(apiKey: apiKey)
        let messages = [ChatMessage(role: .user, content: "Hi")]

        do {
            // Use a cheap, fast model for validation
            let completion = try await chat.send(model: "claude-3-haiku-20240307", messages: messages)

            // Extract model info from response
            let modelUsed = completion.model
            return "Connected to Anthropic (\(modelUsed))"
        } catch let error as LLMChatAnthropicError {
            throw Self.mapError(error)
        }
    }

    private static func mapError(_ error: LLMChatAnthropicError) -> AnthropicValidationError {
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

/// Errors that can occur during Anthropic API key validation.
enum AnthropicValidationError: LocalizedError {
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
            "Invalid API key format (should start with sk-ant-)"
        case .invalidAPIKey:
            "Invalid API key. Check your key at console.anthropic.com"
        case .rateLimited:
            "Rate limited. Please wait a moment and try again"
        case .networkError:
            "Network error. Check your internet connection"
        case let .serverError(message):
            "Anthropic server error: \(message)"
        case let .apiError(code, message):
            "API error (\(code)): \(message)"
        case .unexpectedResponse:
            "Unexpected response from Anthropic"
        case .cancelled:
            "Validation cancelled"
        }
    }
}
