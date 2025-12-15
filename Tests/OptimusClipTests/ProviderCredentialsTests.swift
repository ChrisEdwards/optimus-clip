import Foundation
import OptimusClipCore
import Testing
@testable import OptimusClip

@Suite("ProviderCredentialsResolver Tests")
struct ProviderCredentialsResolverTests {
    @Test("Resolves OpenAI key when present")
    func resolvesOpenAIKey() throws {
        let context = self.makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        try context.store.saveOpenAIKey("sk-openai")
        let resolver = ProviderCredentialsResolver(keyStore: context.store, userDefaults: context.defaults)

        let credentials = try resolver.credentials(for: .openAI)
        switch credentials {
        case let .openAI(apiKey):
            #expect(apiKey == "sk-openai")
        default:
            Issue.record("Expected OpenAI credentials")
        }
    }

    @Test("Returns nil when key is missing")
    func returnsNilForMissingKey() throws {
        let context = self.makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        let resolver = ProviderCredentialsResolver(keyStore: context.store, userDefaults: context.defaults)
        let credentials = try resolver.credentials(for: .anthropic)

        if credentials != nil {
            Issue.record("Expected nil credentials for missing key")
        }
    }

    @Test("Resolves Ollama endpoint from settings")
    func resolvesOllamaEndpoint() throws {
        let context = self.makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        context.defaults.set("http://ollama.local", forKey: SettingsKey.ollamaHost)
        context.defaults.set("1234", forKey: SettingsKey.ollamaPort)

        let resolver = ProviderCredentialsResolver(keyStore: context.store, userDefaults: context.defaults)
        let credentials = try resolver.credentials(for: .ollama)

        switch credentials {
        case let .ollama(endpoint):
            #expect(endpoint.absoluteString == "http://ollama.local:1234")
        default:
            Issue.record("Expected Ollama endpoint credentials")
        }
    }

    @Test("Does not duplicate Ollama port when host already includes one")
    func noDuplicateOllamaPort() throws {
        let context = self.makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        context.defaults.set("http://localhost:5555", forKey: SettingsKey.ollamaHost)
        context.defaults.set("5555", forKey: SettingsKey.ollamaPort)

        let resolver = ProviderCredentialsResolver(keyStore: context.store, userDefaults: context.defaults)
        let credentials = try resolver.credentials(for: .ollama)

        switch credentials {
        case let .ollama(endpoint):
            #expect(endpoint.absoluteString == "http://localhost:5555")
        default:
            Issue.record("Expected Ollama endpoint credentials")
        }
    }

    @Test("Prefers AWS bearer token over access/secret")
    func prefersAWSBearerToken() throws {
        let context = self.makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        context.defaults.set("us-east-1", forKey: SettingsKey.awsRegion)
        try context.store.saveAWSAccessKey("ACCESS")
        try context.store.saveAWSSecretKey("SECRET")
        try context.store.saveAWSBearerToken("BEARER")

        let resolver = ProviderCredentialsResolver(keyStore: context.store, userDefaults: context.defaults)
        let credentials = try resolver.credentials(for: .awsBedrock)

        switch credentials {
        case let .awsBedrockBearerToken(token, region):
            #expect(token == "BEARER")
            #expect(region == "us-east-1")
        default:
            Issue.record("Expected bearer-token credentials")
        }
    }

    @Test("Returns nil for incomplete AWS credentials")
    func nilForIncompleteAWS() throws {
        let context = self.makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        try context.store.saveAWSAccessKey("ACCESS")
        // Missing secret and bearer token

        let resolver = ProviderCredentialsResolver(keyStore: context.store, userDefaults: context.defaults)
        let credentials = try resolver.credentials(for: .awsBedrock)

        if credentials != nil {
            Issue.record("Expected nil credentials for incomplete AWS config")
        }
    }

    private func makeContext() -> TestContext {
        let keychain = MockKeychainService()
        let suiteName = "ProviderCredentialsResolverTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)

        let store = APIKeyStore(keychain: keychain, userDefaults: defaults)
        return TestContext(store: store, keychain: keychain, defaults: defaults, suiteName: suiteName)
    }

    private struct TestContext {
        let store: APIKeyStore
        let keychain: MockKeychainService
        let defaults: UserDefaults
        let suiteName: String
    }
}
