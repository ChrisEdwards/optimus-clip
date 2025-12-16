import Foundation
import Testing
@testable import OptimusClip

@Suite("EncryptedStorageService Tests")
struct EncryptedStorageServiceTests {
    @Test("Save and retrieve string value")
    func saveAndRetrieveString() throws {
        let defaults = UserDefaults(suiteName: "test.encrypted.storage.\(UUID().uuidString)") ?? .standard
        let storage = EncryptedStorageService(defaults: defaults, keySeed: "test-key-seed")

        let testValue = "sk-test-api-key-12345"
        let service = "com.test.service"
        let account = "api_key"

        try storage.saveString(testValue, service: service, account: account)
        let retrieved = try storage.getString(service: service, account: account)

        #expect(retrieved == testValue)

        defaults.removePersistentDomain(forName: "test.encrypted.storage")
    }

    @Test("Returns nil for non-existent key")
    func returnsNilForNonExistent() throws {
        let defaults = UserDefaults(suiteName: "test.encrypted.storage.\(UUID().uuidString)") ?? .standard
        let storage = EncryptedStorageService(defaults: defaults, keySeed: "test-key-seed")

        let retrieved = try storage.getString(service: "nonexistent", account: "test")

        #expect(retrieved == nil)
    }

    @Test("Delete removes stored value")
    func deleteRemovesValue() throws {
        let defaults = UserDefaults(suiteName: "test.encrypted.storage.\(UUID().uuidString)") ?? .standard
        let storage = EncryptedStorageService(defaults: defaults, keySeed: "test-key-seed")

        let service = "com.test.service"
        let account = "api_key"

        try storage.saveString("test-value", service: service, account: account)
        #expect(storage.exists(service: service, account: account) == true)

        try storage.delete(service: service, account: account)
        #expect(storage.exists(service: service, account: account) == false)

        let retrieved = try storage.getString(service: service, account: account)
        #expect(retrieved == nil)
    }

    @Test("Exists returns correct state")
    func existsReturnsCorrectState() throws {
        let defaults = UserDefaults(suiteName: "test.encrypted.storage.\(UUID().uuidString)") ?? .standard
        let storage = EncryptedStorageService(defaults: defaults, keySeed: "test-key-seed")

        let service = "com.test.service"
        let account = "api_key"

        #expect(storage.exists(service: service, account: account) == false)

        try storage.saveString("test-value", service: service, account: account)
        #expect(storage.exists(service: service, account: account) == true)
    }

    @Test("Overwrite replaces existing value")
    func overwriteReplacesValue() throws {
        let defaults = UserDefaults(suiteName: "test.encrypted.storage.\(UUID().uuidString)") ?? .standard
        let storage = EncryptedStorageService(defaults: defaults, keySeed: "test-key-seed")

        let service = "com.test.service"
        let account = "api_key"

        try storage.saveString("original-value", service: service, account: account)
        try storage.saveString("new-value", service: service, account: account)

        let retrieved = try storage.getString(service: service, account: account)
        #expect(retrieved == "new-value")
    }

    @Test("Different services are isolated")
    func differentServicesIsolated() throws {
        let defaults = UserDefaults(suiteName: "test.encrypted.storage.\(UUID().uuidString)") ?? .standard
        let storage = EncryptedStorageService(defaults: defaults, keySeed: "test-key-seed")

        try storage.saveString("value-a", service: "service-a", account: "key")
        try storage.saveString("value-b", service: "service-b", account: "key")

        let valueA = try storage.getString(service: "service-a", account: "key")
        let valueB = try storage.getString(service: "service-b", account: "key")

        #expect(valueA == "value-a")
        #expect(valueB == "value-b")
    }

    @Test("Conforms to KeychainService protocol")
    func conformsToKeychainService() throws {
        let defaults = UserDefaults(suiteName: "test.encrypted.storage.\(UUID().uuidString)") ?? .standard
        let storage: KeychainService = EncryptedStorageService(defaults: defaults, keySeed: "test-key-seed")

        try storage.saveString("test", service: "svc", account: "acc")
        let value = try storage.getString(service: "svc", account: "acc")
        #expect(value == "test")
    }

    @Test("Handles special characters in values")
    func handlesSpecialCharacters() throws {
        let defaults = UserDefaults(suiteName: "test.encrypted.storage.\(UUID().uuidString)") ?? .standard
        let storage = EncryptedStorageService(defaults: defaults, keySeed: "test-key-seed")

        let specialValue = "sk-test_KEY.with:special/chars!@#$%^&*()"
        try storage.saveString(specialValue, service: "test", account: "key")

        let retrieved = try storage.getString(service: "test", account: "key")
        #expect(retrieved == specialValue)
    }

    @Test("Handles unicode in values")
    func handlesUnicode() throws {
        let defaults = UserDefaults(suiteName: "test.encrypted.storage.\(UUID().uuidString)") ?? .standard
        let storage = EncryptedStorageService(defaults: defaults, keySeed: "test-key-seed")

        let unicodeValue = "API密钥🔑émoji"
        try storage.saveString(unicodeValue, service: "test", account: "key")

        let retrieved = try storage.getString(service: "test", account: "key")
        #expect(retrieved == unicodeValue)
    }
}
