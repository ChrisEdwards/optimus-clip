import Foundation
import Testing
@testable import OptimusClip

@Suite("APIKeyStore Tests")
struct APIKeyStoreTests {
    @Test("Saves and loads OpenAI key via Keychain")
    func saveAndLoadOpenAIKey() throws {
        let context = self.makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        try context.store.saveOpenAIKey("sk-test")

        let loaded = try context.store.loadOpenAIKey()

        #expect(loaded == "sk-test")
        #expect(context.keychain
            .exists(service: KeychainServiceName.openAI, account: KeychainWrapper.defaultAccount) == true)
        #expect(context.defaults.string(forKey: SettingsKey.openAIKey) == nil)
    }

    @Test("Migrates legacy UserDefaults entries into Keychain")
    func migratesLegacyDefaults() throws {
        let context = self.makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        context.defaults.set("legacy-key", forKey: SettingsKey.openAIKey)

        let loaded = try context.store.loadOpenAIKey()

        #expect(loaded == "legacy-key")
        #expect(context.keychain
            .exists(service: KeychainServiceName.openAI, account: KeychainWrapper.defaultAccount) == true)
        #expect(context.defaults.string(forKey: SettingsKey.openAIKey) == nil)
    }

    @Test("Delete clears Keychain and legacy defaults")
    func deleteClearsStorage() throws {
        let context = self.makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        try context.store.saveOpenAIKey("sk-test")
        context.defaults.set("stale", forKey: SettingsKey.openAIKey)

        try context.store.deleteOpenAIKey()

        #expect(context.keychain
            .exists(service: KeychainServiceName.openAI, account: KeychainWrapper.defaultAccount) == false)
        #expect(context.defaults.string(forKey: SettingsKey.openAIKey) == nil)
    }

    @Test("AWS secrets are stored in distinct services")
    func storesAWSSecretsSeparately() throws {
        let context = self.makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        try context.store.saveAWSAccessKey("AKIA_TEST")
        try context.store.saveAWSSecretKey("SECRET_TEST")
        try context.store.saveAWSBearerToken("BEARER_TEST")

        #expect(try context.store.loadAWSAccessKey() == "AKIA_TEST")
        #expect(try context.store.loadAWSSecretKey() == "SECRET_TEST")
        #expect(try context.store.loadAWSBearerToken() == "BEARER_TEST")

        #expect(context.keychain
            .exists(service: KeychainServiceName.awsAccessKey, account: KeychainWrapper.defaultAccount) == true)
        #expect(context.keychain
            .exists(service: KeychainServiceName.awsSecretKey, account: KeychainWrapper.defaultAccount) == true)
        #expect(context.keychain
            .exists(service: KeychainServiceName.awsBearerToken, account: KeychainWrapper.defaultAccount) == true)
        #expect(context.defaults.string(forKey: SettingsKey.awsAccessKey) == nil)
        #expect(context.defaults.string(forKey: SettingsKey.awsSecretKey) == nil)
        #expect(context.defaults.string(forKey: SettingsKey.awsBearerToken) == nil)
    }

    private func makeContext() -> TestContext {
        let keychain = MockKeychainService()
        let suiteName = "APIKeyStoreTests.\(UUID().uuidString)"
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
