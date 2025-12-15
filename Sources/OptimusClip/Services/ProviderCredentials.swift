import Foundation
import OptimusClipCore

/// Resolves provider credentials from the Keychain and non-secret settings.
///
/// Secrets are stored in the Keychain (via APIKeyStore). Non-secret values
/// such as host/port/region remain in UserDefaults.
struct ProviderCredentialsResolver {
    private let keyStore: APIKeyStore
    private let userDefaults: UserDefaults

    init(
        keyStore: APIKeyStore = APIKeyStore(),
        userDefaults: UserDefaults = .standard
    ) {
        self.keyStore = keyStore
        self.userDefaults = userDefaults
    }

    /// Returns credentials for a provider if configured; otherwise `nil`.
    func credentials(for provider: LLMProviderKind) throws -> LLMCredentials? {
        switch provider {
        case .openAI:
            try self.openAICredentials()
        case .anthropic:
            try self.anthropicCredentials()
        case .openRouter:
            try self.openRouterCredentials()
        case .ollama:
            self.ollamaCredentials()
        case .awsBedrock:
            try self.awsCredentials()
        }
    }

    // MARK: - Helpers

    private func openAICredentials() throws -> LLMCredentials? {
        guard let key = try self.keyStore.loadOpenAIKey(), key.isEmpty == false else { return nil }
        return .openAI(apiKey: key)
    }

    private func anthropicCredentials() throws -> LLMCredentials? {
        guard let key = try self.keyStore.loadAnthropicKey(), key.isEmpty == false else { return nil }
        return .anthropic(apiKey: key)
    }

    private func openRouterCredentials() throws -> LLMCredentials? {
        guard let key = try self.keyStore.loadOpenRouterKey(), key.isEmpty == false else { return nil }
        return .openRouter(apiKey: key)
    }

    private func ollamaCredentials() -> LLMCredentials? {
        guard let endpoint = self.ollamaEndpointURL() else { return nil }
        return .ollama(endpoint: endpoint)
    }

    private func awsCredentials() throws -> LLMCredentials? {
        let region = self.userDefaults.string(forKey: SettingsKey.awsRegion) ?? DefaultSettings.awsRegion

        if let bearer = try self.keyStore.loadAWSBearerToken(), bearer.isEmpty == false {
            return .awsBedrockBearerToken(bearerToken: bearer, region: region)
        }

        guard
            let access = try self.keyStore.loadAWSAccessKey(),
            access.isEmpty == false,
            let secret = try self.keyStore.loadAWSSecretKey(),
            secret.isEmpty == false else {
            return nil
        }

        return .awsBedrock(accessKey: access, secretKey: secret, region: region)
    }

    private func ollamaEndpointURL() -> URL? {
        let host = (self.userDefaults.string(forKey: SettingsKey.ollamaHost) ?? DefaultSettings.ollamaHost)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let port = (self.userDefaults.string(forKey: SettingsKey.ollamaPort) ?? DefaultSettings.ollamaPort)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let base = host.hasPrefix("http") ? host : "http://\(host)"
        if let components = URLComponents(string: base), components.port != nil {
            return components.url
        }

        let combined = port.isEmpty ? base : "\(base):\(port)"
        return URL(string: combined)
    }
}
