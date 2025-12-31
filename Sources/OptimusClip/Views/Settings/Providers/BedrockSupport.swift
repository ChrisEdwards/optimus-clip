import Foundation

// MARK: - Model Request Formats

/// Handles different request body formats for various Bedrock model providers.
enum ModelRequestFormat {
    case anthropic
    case amazonTitan
    case meta
    case mistral
    case cohere
    case ai21
    case unknown

    /// Detects the provider from a model ID.
    static func detect(from modelId: String) -> ModelRequestFormat {
        let lowercased = modelId.lowercased()
        if lowercased.contains("anthropic") || lowercased.contains("claude") {
            return .anthropic
        } else if lowercased.contains("amazon") || lowercased.contains("titan") {
            return .amazonTitan
        } else if lowercased.contains("meta") || lowercased.contains("llama") {
            return .meta
        } else if lowercased.contains("mistral") {
            return .mistral
        } else if lowercased.contains("cohere") {
            return .cohere
        } else if lowercased.contains("ai21") || lowercased.contains("jamba") || lowercased.contains("jurassic") {
            return .ai21
        }
        return .unknown
    }

    /// Returns the appropriate request body for this provider.
    var requestBody: [String: Any] {
        switch self {
        case .anthropic:
            [
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": 10,
                "messages": [["role": "user", "content": "Hi"]]
            ]
        case .amazonTitan:
            [
                "inputText": "Hi",
                "textGenerationConfig": [
                    "maxTokenCount": 10,
                    "temperature": 0.0
                ]
            ]
        case .meta:
            [
                "prompt": "Hi",
                "max_gen_len": 10,
                "temperature": 0.0
            ]
        case .mistral:
            [
                "prompt": "<s>[INST] Hi [/INST]",
                "max_tokens": 10,
                "temperature": 0.0
            ]
        case .cohere:
            [
                "message": "Hi",
                "max_tokens": 10,
                "temperature": 0.0
            ]
        case .ai21:
            [
                "messages": [["role": "user", "content": "Hi"]],
                "max_tokens": 10,
                "temperature": 0.0
            ]
        case .unknown:
            // Default to Anthropic format as it's most common on Bedrock
            [
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": 10,
                "messages": [["role": "user", "content": "Hi"]]
            ]
        }
    }
}

// MARK: - Inference Profile Helper

/// Converts model IDs to cross-region inference profile format.
/// Newer AWS Bedrock models require inference profiles like `us.anthropic.claude-3-5-haiku-20241022-v1:0`.
enum InferenceProfileHelper {
    /// Converts a model ID to cross-region inference profile format if needed.
    static func profileId(for modelId: String, region: String) -> String {
        if modelId.hasPrefix("us.") || modelId.hasPrefix("eu.") || modelId.hasPrefix("apac.") {
            return modelId
        }
        if modelId.hasPrefix("arn:") {
            return modelId
        }
        let regionPrefix = self.regionPrefix(for: region)
        return "\(regionPrefix)\(modelId)"
    }

    private static func regionPrefix(for region: String) -> String {
        if region.hasPrefix("us-") {
            return "us."
        } else if region.hasPrefix("eu-") {
            return "eu."
        } else if region.hasPrefix("ap-") {
            return "apac."
        }
        return "us."
    }
}

// MARK: - Supporting Types

/// Represents an AWS Bedrock foundation model.
struct BedrockModel: Identifiable, Hashable {
    let id: String
    let name: String
    let provider: String

    var displayName: String {
        "\(self.provider): \(self.name)"
    }
}

struct AWSCredentials {
    let accessKey: String
    let secretKey: String
}

/// Errors that can occur during AWS Bedrock credential validation.
enum BedrockValidationError: LocalizedError {
    case invalidProfile
    case profileNotFound(String)
    case invalidAccessKeyFormat
    case missingSecretKey
    case missingBearerToken
    case invalidCredentials
    case modelAccessNotEnabled
    case modelNotAvailable
    case rateLimited
    case networkError
    case timeout
    case invalidEndpoint
    case serverError(String)
    case apiError(String)
    case invalidResponse(String)
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .invalidProfile:
            "Profile name is required"
        case let .profileNotFound(profile):
            "AWS profile '\(profile)' not found. Check ~/.aws/credentials"
        case .invalidAccessKeyFormat:
            "Invalid access key format (should start with AKIA or ASIA)"
        case .missingSecretKey:
            "Secret access key is required"
        case .missingBearerToken:
            "Bearer token is required"
        case .invalidCredentials:
            "Invalid AWS credentials. Check your access key and secret key"
        case .modelAccessNotEnabled:
            "Model access not enabled. Enable in AWS Bedrock Console"
        case .modelNotAvailable:
            "Model not available in selected region. Try us-east-1"
        case .rateLimited:
            "Rate limited. Please wait a moment and try again"
        case .networkError:
            "Network error. Check your internet connection"
        case .timeout:
            "Connection timed out. Check region and network"
        case .invalidEndpoint:
            "Invalid AWS endpoint configuration"
        case let .serverError(message):
            "AWS Bedrock server error: \(message)"
        case let .apiError(message):
            "API error: \(message)"
        case let .invalidResponse(message):
            "Invalid response: \(message)"
        case .unexpectedResponse:
            "Unexpected response from AWS Bedrock"
        }
    }
}
