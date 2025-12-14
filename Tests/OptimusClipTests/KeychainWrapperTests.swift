import Foundation
import Security
import Testing
@testable import OptimusClip

// MARK: - MockKeychainService Tests

@Suite("MockKeychainService Tests")
struct MockKeychainServiceTests {
    @Test("Save and retrieve string value")
    func saveAndRetrieveString() throws {
        let mock = MockKeychainService()

        try mock.saveString("test-api-key", service: "test.service", account: "api_key")
        let retrieved = try mock.getString(service: "test.service", account: "api_key")

        #expect(retrieved == "test-api-key")
    }

    @Test("Retrieve non-existent value returns nil")
    func retrieveNonExistent() throws {
        let mock = MockKeychainService()

        let retrieved = try mock.getString(service: "nonexistent.service", account: "api_key")

        #expect(retrieved == nil)
    }

    @Test("Delete removes value")
    func deleteRemovesValue() throws {
        let mock = MockKeychainService()

        try mock.saveString("test-value", service: "test.service", account: "api_key")
        try mock.delete(service: "test.service", account: "api_key")
        let retrieved = try mock.getString(service: "test.service", account: "api_key")

        #expect(retrieved == nil)
    }

    @Test("Delete non-existent value succeeds (idempotent)")
    func deleteNonExistent() throws {
        let mock = MockKeychainService()

        // Should not throw
        try mock.delete(service: "nonexistent.service", account: "api_key")
    }

    @Test("Exists returns true for stored value")
    func existsReturnsTrue() throws {
        let mock = MockKeychainService()

        try mock.saveString("test-value", service: "test.service", account: "api_key")

        #expect(mock.exists(service: "test.service", account: "api_key") == true)
    }

    @Test("Exists returns false for missing value")
    func existsReturnsFalse() {
        let mock = MockKeychainService()

        #expect(mock.exists(service: "nonexistent.service", account: "api_key") == false)
    }

    @Test("Overwrite existing value")
    func overwriteValue() throws {
        let mock = MockKeychainService()

        try mock.saveString("original-value", service: "test.service", account: "api_key")
        try mock.saveString("new-value", service: "test.service", account: "api_key")
        let retrieved = try mock.getString(service: "test.service", account: "api_key")

        #expect(retrieved == "new-value")
    }

    @Test("Different services are isolated")
    func servicesIsolated() throws {
        let mock = MockKeychainService()

        try mock.saveString("value-1", service: "service.one", account: "api_key")
        try mock.saveString("value-2", service: "service.two", account: "api_key")

        let value1 = try mock.getString(service: "service.one", account: "api_key")
        let value2 = try mock.getString(service: "service.two", account: "api_key")

        #expect(value1 == "value-1")
        #expect(value2 == "value-2")
    }

    @Test("Different accounts are isolated")
    func accountsIsolated() throws {
        let mock = MockKeychainService()

        try mock.saveString("value-1", service: "test.service", account: "account_1")
        try mock.saveString("value-2", service: "test.service", account: "account_2")

        let value1 = try mock.getString(service: "test.service", account: "account_1")
        let value2 = try mock.getString(service: "test.service", account: "account_2")

        #expect(value1 == "value-1")
        #expect(value2 == "value-2")
    }

    @Test("Reset clears all values")
    func resetClearsAll() throws {
        let mock = MockKeychainService()

        try mock.saveString("value-1", service: "service.one", account: "api_key")
        try mock.saveString("value-2", service: "service.two", account: "api_key")

        mock.reset()

        #expect(mock.exists(service: "service.one", account: "api_key") == false)
        #expect(mock.exists(service: "service.two", account: "api_key") == false)
    }

    @Test("Unicode characters handled correctly")
    func unicodeCharacters() throws {
        let mock = MockKeychainService()
        let unicodeValue = "api-key-with-unicode-\u{1F511}-\u{1F512}"

        try mock.saveString(unicodeValue, service: "test.service", account: "api_key")
        let retrieved = try mock.getString(service: "test.service", account: "api_key")

        #expect(retrieved == unicodeValue)
    }

    @Test("Empty string handled correctly")
    func emptyString() throws {
        let mock = MockKeychainService()

        try mock.saveString("", service: "test.service", account: "api_key")
        let retrieved = try mock.getString(service: "test.service", account: "api_key")

        #expect(retrieved == "")
        #expect(mock.exists(service: "test.service", account: "api_key") == true)
    }
}

// MARK: - KeychainError Tests

@Suite("KeychainError Tests")
struct KeychainErrorTests {
    @Test("Error from errSecItemNotFound")
    func errorItemNotFound() {
        let error = KeychainError(status: errSecItemNotFound)

        #expect(error == .itemNotFound)
        #expect(error.errorDescription?.contains("not found") == true)
    }

    @Test("Error from errSecDuplicateItem")
    func errorDuplicateItem() {
        let error = KeychainError(status: errSecDuplicateItem)

        #expect(error == .duplicateItem)
        #expect(error.errorDescription?.contains("already exists") == true)
    }

    @Test("Error from errSecAuthFailed")
    func errorAuthFailed() {
        let error = KeychainError(status: errSecAuthFailed)

        #expect(error == .authFailed)
        #expect(error.errorDescription?.contains("Authentication") == true)
    }

    @Test("Error from errSecUserCanceled")
    func errorUserCanceled() {
        let error = KeychainError(status: errSecUserCanceled)

        #expect(error == .userCanceled)
        #expect(error.errorDescription?.contains("canceled") == true)
    }

    @Test("Error from errSecInteractionNotAllowed")
    func errorAccessDenied() {
        let error = KeychainError(status: errSecInteractionNotAllowed)

        #expect(error == .accessDenied)
        #expect(error.errorDescription?.contains("denied") == true)
    }

    @Test("Unhandled error includes status code")
    func errorUnhandled() {
        let unknownStatus: OSStatus = -12345
        let error = KeychainError(status: unknownStatus)

        if case let .unhandledError(status) = error {
            #expect(status == unknownStatus)
            #expect(error.errorDescription?.contains("-12345") == true)
        } else {
            Issue.record("Expected unhandledError case")
        }
    }

    @Test("Encoding failed error message")
    func errorEncodingFailed() {
        let error = KeychainError.encodingFailed

        #expect(error.errorDescription?.contains("encode") == true)
    }

    @Test("Decoding failed error message")
    func errorDecodingFailed() {
        let error = KeychainError.decodingFailed

        #expect(error.errorDescription?.contains("decode") == true)
    }
}

// MARK: - KeychainWrapper Integration Tests

// Note: These tests use the real Keychain and should only run in development
// environments where Keychain access is available.

@Suite("KeychainWrapper Integration Tests", .disabled("Requires real Keychain access"))
struct KeychainWrapperIntegrationTests {
    // Test prefix to avoid conflicts with real app data
    let testService = "com.optimusclip.test.\(UUID().uuidString)"

    @Test("Save and retrieve from real Keychain")
    func saveAndRetrieve() throws {
        let wrapper = KeychainWrapper.shared

        try wrapper.saveString("test-api-key", service: self.testService, account: "api_key")
        let retrieved = try wrapper.getString(service: self.testService, account: "api_key")

        #expect(retrieved == "test-api-key")

        // Cleanup
        try wrapper.delete(service: self.testService, account: "api_key")
    }
}
