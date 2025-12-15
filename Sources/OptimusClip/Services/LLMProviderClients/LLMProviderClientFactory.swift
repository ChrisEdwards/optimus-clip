import Foundation
import OptimusClipCore

/// Factory for creating LLMProviderClient instances from Keychain credentials.
///
/// This factory bridges the credential storage layer (ProviderCredentialsResolver)
/// with the runtime LLM consumers (LLMTransformation, ModelCatalog).
///
/// ## Usage
/// ```swift
/// let factory = LLMProviderClientFactory()
/// if let client = try factory.client(for: .anthropic) {
///     let transformation = LLMTransformation(
///         providerClient: client,
///         model: "claude-3-haiku-20240307",
///         systemPrompt: "..."
///     )
/// }
/// ```
struct LLMProviderClientFactory {
    private let resolver: ProviderCredentialsResolver

    init(resolver: ProviderCredentialsResolver = ProviderCredentialsResolver()) {
        self.resolver = resolver
    }

    /// Creates an LLMProviderClient for the specified provider using Keychain credentials.
    ///
    /// - Parameter provider: The LLM provider to create a client for.
    /// - Returns: A configured client, or `nil` if credentials are not available.
    /// - Throws: `KeychainError` if credential retrieval fails.
    func client(for provider: LLMProviderKind) throws -> (any LLMProviderClient)? {
        guard let credentials = try self.resolver.credentials(for: provider) else {
            return nil
        }
        return Self.makeClient(from: credentials)
    }

    /// Creates an LLMProviderClient from explicit credentials.
    ///
    /// Use this when you already have credentials (e.g., from settings validation).
    ///
    /// - Parameter credentials: The credentials to use.
    /// - Returns: A configured client.
    static func makeClient(from credentials: LLMCredentials) -> any LLMProviderClient {
        switch credentials {
        case let .openAI(apiKey):
            OpenAIProviderClient(apiKey: apiKey)
        case let .anthropic(apiKey):
            AnthropicProviderClient(apiKey: apiKey)
        case let .openRouter(apiKey):
            OpenRouterProviderClient(apiKey: apiKey)
        case let .ollama(endpoint):
            OllamaProviderClient(endpoint: endpoint)
        case let .awsBedrock(accessKey, secretKey, region):
            AWSBedrockProviderClient(accessKey: accessKey, secretKey: secretKey, region: region)
        case let .awsBedrockBearerToken(bearerToken, region):
            AWSBedrockProviderClient(bearerToken: bearerToken, region: region)
        }
    }

    /// Returns all configured providers with their clients.
    ///
    /// Useful for building provider selection UI or determining available options.
    ///
    /// - Returns: Dictionary mapping provider kinds to their clients.
    func configuredClients() throws -> [LLMProviderKind: any LLMProviderClient] {
        var clients: [LLMProviderKind: any LLMProviderClient] = [:]

        for provider in [LLMProviderKind.openAI, .anthropic, .openRouter, .ollama, .awsBedrock] {
            if let client = try self.client(for: provider), client.isConfigured() {
                clients[provider] = client
            }
        }

        return clients
    }

    /// Checks if a specific provider is configured.
    ///
    /// - Parameter provider: The provider to check.
    /// - Returns: `true` if credentials are available and valid.
    func isConfigured(_ provider: LLMProviderKind) throws -> Bool {
        guard let client = try self.client(for: provider) else {
            return false
        }
        return client.isConfigured()
    }
}

// MARK: - ModelProviderConfig Extension

extension LLMProviderClientFactory {
    /// Creates a ModelProviderConfig for the specified provider using Keychain credentials.
    ///
    /// This is useful for ModelCatalog integration.
    ///
    /// - Parameter provider: The provider to create config for.
    /// - Returns: A configured ModelProviderConfig, or `nil` if credentials unavailable.
    func modelProviderConfig(for provider: LLMProviderKind) throws -> ModelProviderConfig? {
        guard let credentials = try self.resolver.credentials(for: provider) else {
            return nil
        }

        switch credentials {
        case let .openAI(apiKey):
            return .openAI(apiKey: apiKey)
        case .anthropic:
            return .anthropic()
        case let .openRouter(apiKey):
            return .openRouter(apiKey: apiKey)
        case let .ollama(endpoint):
            return .ollama(host: endpoint)
        case let .awsBedrock(_, _, region):
            return .awsBedrock(region: region)
        case let .awsBedrockBearerToken(_, region):
            return .awsBedrock(region: region)
        }
    }
}
