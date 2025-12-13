import Foundation

// MARK: - LLM Provider Types

/// Supported LLM providers for transformations.
enum LLMProvider: String, CaseIterable, Identifiable {
    case openai
    case anthropic
    case openRouter
    case ollama
    case awsBedrock

    var id: String { self.rawValue }

    /// Display name for the provider.
    var displayName: String {
        switch self {
        case .openai: "OpenAI"
        case .anthropic: "Anthropic"
        case .openRouter: "OpenRouter"
        case .ollama: "Ollama"
        case .awsBedrock: "AWS Bedrock"
        }
    }

    /// Help URL for getting API credentials.
    var helpURL: URL? {
        switch self {
        case .openai:
            URL(string: "https://platform.openai.com/api-keys")
        case .anthropic:
            URL(string: "https://console.anthropic.com/settings/keys")
        case .openRouter:
            URL(string: "https://openrouter.ai/keys")
        case .ollama:
            URL(string: "https://ollama.ai/download")
        case .awsBedrock:
            URL(string: "https://console.aws.amazon.com/bedrock")
        }
    }
}

/// AWS authentication method options.
enum AWSAuthMethod: String, CaseIterable, Identifiable {
    case profile
    case keys

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .profile: "AWS Profile"
        case .keys: "Access Keys"
        }
    }
}

/// Validation state for provider credentials.
enum ValidationState: Equatable {
    case idle
    case validating
    case success(message: String)
    case failure(error: String)
}
