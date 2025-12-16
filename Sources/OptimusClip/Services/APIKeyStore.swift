import Foundation

/// Stores provider credentials using AES-GCM encrypted storage in UserDefaults.
/// Falls back to migrating legacy @AppStorage values and Keychain entries.
///
/// Uses `EncryptedStorageService` instead of Keychain to avoid repeated password
/// prompts during development (debug builds have unstable code signatures).
struct APIKeyStore {
    private let keychain: KeychainService
    private let userDefaults: UserDefaults
    private let account = KeychainWrapper.defaultAccount

    init(
        keychain: KeychainService = EncryptedStorageService.shared,
        userDefaults: UserDefaults = .standard
    ) {
        self.keychain = keychain
        self.userDefaults = userDefaults
    }

    // MARK: - OpenAI

    func loadOpenAIKey() throws -> String? {
        try self.loadKey(
            service: KeychainServiceName.openAI,
            legacyDefaultsKey: SettingsKey.openAIKey
        )
    }

    func saveOpenAIKey(_ key: String) throws {
        try self.saveKey(
            key,
            service: KeychainServiceName.openAI,
            legacyDefaultsKey: SettingsKey.openAIKey
        )
    }

    func deleteOpenAIKey() throws {
        try self.deleteKey(
            service: KeychainServiceName.openAI,
            legacyDefaultsKey: SettingsKey.openAIKey
        )
    }

    // MARK: - Anthropic

    func loadAnthropicKey() throws -> String? {
        try self.loadKey(
            service: KeychainServiceName.anthropic,
            legacyDefaultsKey: SettingsKey.anthropicKey
        )
    }

    func saveAnthropicKey(_ key: String) throws {
        try self.saveKey(
            key,
            service: KeychainServiceName.anthropic,
            legacyDefaultsKey: SettingsKey.anthropicKey
        )
    }

    func deleteAnthropicKey() throws {
        try self.deleteKey(
            service: KeychainServiceName.anthropic,
            legacyDefaultsKey: SettingsKey.anthropicKey
        )
    }

    // MARK: - OpenRouter

    func loadOpenRouterKey() throws -> String? {
        try self.loadKey(
            service: KeychainServiceName.openrouter,
            legacyDefaultsKey: SettingsKey.openRouterKey
        )
    }

    func saveOpenRouterKey(_ key: String) throws {
        try self.saveKey(
            key,
            service: KeychainServiceName.openrouter,
            legacyDefaultsKey: SettingsKey.openRouterKey
        )
    }

    func deleteOpenRouterKey() throws {
        try self.deleteKey(
            service: KeychainServiceName.openrouter,
            legacyDefaultsKey: SettingsKey.openRouterKey
        )
    }

    // MARK: - AWS

    func loadAWSAccessKey() throws -> String? {
        try self.loadKey(
            service: KeychainServiceName.awsAccessKey,
            legacyDefaultsKey: SettingsKey.awsAccessKey
        )
    }

    func saveAWSAccessKey(_ key: String) throws {
        try self.saveKey(
            key,
            service: KeychainServiceName.awsAccessKey,
            legacyDefaultsKey: SettingsKey.awsAccessKey
        )
    }

    func deleteAWSAccessKey() throws {
        try self.deleteKey(
            service: KeychainServiceName.awsAccessKey,
            legacyDefaultsKey: SettingsKey.awsAccessKey
        )
    }

    func loadAWSSecretKey() throws -> String? {
        try self.loadKey(
            service: KeychainServiceName.awsSecretKey,
            legacyDefaultsKey: SettingsKey.awsSecretKey
        )
    }

    func saveAWSSecretKey(_ key: String) throws {
        try self.saveKey(
            key,
            service: KeychainServiceName.awsSecretKey,
            legacyDefaultsKey: SettingsKey.awsSecretKey
        )
    }

    func deleteAWSSecretKey() throws {
        try self.deleteKey(
            service: KeychainServiceName.awsSecretKey,
            legacyDefaultsKey: SettingsKey.awsSecretKey
        )
    }

    func loadAWSBearerToken() throws -> String? {
        try self.loadKey(
            service: KeychainServiceName.awsBearerToken,
            legacyDefaultsKey: SettingsKey.awsBearerToken
        )
    }

    func saveAWSBearerToken(_ token: String) throws {
        try self.saveKey(
            token,
            service: KeychainServiceName.awsBearerToken,
            legacyDefaultsKey: SettingsKey.awsBearerToken
        )
    }

    func deleteAWSBearerToken() throws {
        try self.deleteKey(
            service: KeychainServiceName.awsBearerToken,
            legacyDefaultsKey: SettingsKey.awsBearerToken
        )
    }

    // MARK: - Internal helpers

    private func loadKey(service: String, legacyDefaultsKey: String?) throws -> String? {
        if let value = try self.keychain.getString(service: service, account: self.account) {
            if let legacyDefaultsKey {
                self.userDefaults.removeObject(forKey: legacyDefaultsKey)
            }
            return value
        }

        guard let legacyDefaultsKey,
              let legacyValue = self.userDefaults.string(forKey: legacyDefaultsKey),
              legacyValue.isEmpty == false else {
            return nil
        }

        try self.keychain.saveString(legacyValue, service: service, account: self.account)
        self.userDefaults.removeObject(forKey: legacyDefaultsKey)
        return legacyValue
    }

    private func saveKey(
        _ key: String,
        service: String,
        legacyDefaultsKey: String?
    ) throws {
        if key.isEmpty {
            try self.deleteKey(service: service, legacyDefaultsKey: legacyDefaultsKey)
            return
        }

        try self.keychain.saveString(key, service: service, account: self.account)
        if let legacyDefaultsKey {
            self.userDefaults.removeObject(forKey: legacyDefaultsKey)
        }
    }

    private func deleteKey(service: String, legacyDefaultsKey: String?) throws {
        try self.keychain.delete(service: service, account: self.account)
        if let legacyDefaultsKey {
            self.userDefaults.removeObject(forKey: legacyDefaultsKey)
        }
    }
}
