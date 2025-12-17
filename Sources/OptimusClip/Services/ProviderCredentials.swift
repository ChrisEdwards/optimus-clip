import Foundation
import OptimusClipCore

/// Resolves provider credentials from the Keychain and non-secret settings.
///
/// Secrets are stored in the Keychain (via APIKeyStore). Non-secret values
/// such as host/port/region remain in UserDefaults.
///
/// ## Usage
/// ```swift
/// let resolver = ProviderCredentialsResolver()
/// if let creds = try resolver.credentials(for: .openAI) {
///     // Use credentials
/// }
/// ```
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
        let region = self.cleanedSetting(self.userDefaults.string(forKey: SettingsKey.awsRegion))
            ?? DefaultSettings.awsRegion

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
        let host = self.cleanedSetting(self.userDefaults.string(forKey: SettingsKey.ollamaHost))
            ?? DefaultSettings.ollamaHost
        let port = self.cleanedSetting(self.userDefaults.string(forKey: SettingsKey.ollamaPort))

        let base = host.hasPrefix("http") ? host : "http://\(host)"
        if let components = URLComponents(string: base), components.port != nil {
            return components.url
        }

        let combined: String = if let port, Self.isValidPort(port) {
            "\(base):\(port)"
        } else {
            base
        }
        return URL(string: combined)
    }

    private func cleanedSetting(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func isValidPort(_ value: String) -> Bool {
        guard let portNumber = Int(value), (1 ... 65535).contains(portNumber) else {
            return false
        }
        return true
    }
}
