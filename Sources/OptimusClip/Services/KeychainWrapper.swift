import Foundation
import Security

// MARK: - Keychain Service Names

enum KeychainServiceName {
    static let openAI = "com.optimusclip.openai"
    static let anthropic = "com.optimusclip.anthropic"
    static let openrouter = "com.optimusclip.openrouter"
    static let awsAccessKey = "com.optimusclip.aws.accesskey"
    static let awsSecretKey = "com.optimusclip.aws.secretkey"
    static let awsBearerToken = "com.optimusclip.aws.bearer"
    static let ollama = "com.optimusclip.ollama"
}

// MARK: - KeychainError

/// Errors that can occur during Keychain operations
enum KeychainError: LocalizedError, Equatable {
    case itemNotFound
    case duplicateItem
    case authFailed
    case userCanceled
    case accessDenied
    case encodingFailed
    case decodingFailed
    case unhandledError(OSStatus)

    init(status: OSStatus) {
        switch status {
        case errSecItemNotFound:
            self = .itemNotFound
        case errSecDuplicateItem:
            self = .duplicateItem
        case errSecAuthFailed:
            self = .authFailed
        case errSecUserCanceled:
            self = .userCanceled
        case errSecInteractionNotAllowed:
            self = .accessDenied
        default:
            self = .unhandledError(status)
        }
    }

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            "The requested item was not found in the Keychain."
        case .duplicateItem:
            "An item with this identifier already exists."
        case .authFailed:
            "Authentication failed. Check your credentials."
        case .userCanceled:
            "The operation was canceled by the user."
        case .accessDenied:
            "Access to the Keychain was denied. The device may be locked."
        case .encodingFailed:
            "Failed to encode the value for storage."
        case .decodingFailed:
            "Failed to decode the stored value."
        case let .unhandledError(status):
            "Keychain error: \(status)"
        }
    }
}

// MARK: - KeychainService Protocol

/// Protocol for Keychain operations (enables mocking in tests)
protocol KeychainService: Sendable {
    func saveString(_ value: String, service: String, account: String) throws
    func getString(service: String, account: String) throws -> String?
    func delete(service: String, account: String) throws
    func exists(service: String, account: String) -> Bool
}

// MARK: - KeychainWrapper

/// Type-safe wrapper for macOS Keychain Services
/// Thread-safe singleton that provides a clean Swift API for credential storage
final class KeychainWrapper: KeychainService, @unchecked Sendable {
    // Singleton is safe because underlying Security APIs are thread-safe
    // and this class holds no mutable state
    static let shared = KeychainWrapper()

    private init() {}

    // MARK: - Save Operations

    /// Save a string value to the Keychain (protocol conformance)
    /// - Parameters:
    ///   - value: The string value to store
    ///   - service: Service identifier (e.g., "com.optimusclip.openai")
    ///   - account: Account identifier (e.g., "api_key")
    func saveString(_ value: String, service: String, account: String) throws {
        try self.saveString(
            value,
            service: service,
            account: account,
            accessibility: kSecAttrAccessibleAfterFirstUnlock
        )
    }

    /// Save a string value to the Keychain with custom accessibility
    /// - Parameters:
    ///   - value: The string value to store
    ///   - service: Service identifier (e.g., "com.optimusclip.openai")
    ///   - account: Account identifier (e.g., "api_key")
    ///   - accessibility: When the item should be accessible (default: after first unlock)
    func saveString(
        _ value: String,
        service: String,
        account: String,
        accessibility: CFString
    ) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        try self.saveData(data, service: service, account: account, accessibility: accessibility)
    }

    /// Save raw data to the Keychain
    /// - Parameters:
    ///   - data: The data to store
    ///   - service: Service identifier
    ///   - account: Account identifier
    ///   - accessibility: When the item should be accessible
    func saveData(
        _ data: Data,
        service: String,
        account: String,
        accessibility: CFString = kSecAttrAccessibleAfterFirstUnlock
    ) throws {
        // First, try to delete existing item (if any) for idempotent updates
        let deleteQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new item
        let addQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessible: accessibility
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError(status: status)
        }
    }

    // MARK: - Retrieve Operations

    /// Retrieve a string value from the Keychain
    /// - Parameters:
    ///   - service: Service identifier
    ///   - account: Account identifier
    /// - Returns: The stored string, or nil if not found
    func getString(service: String, account: String) throws -> String? {
        guard let data = try getData(service: service, account: account) else {
            return nil
        }

        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }

        return string
    }

    /// Retrieve raw data from the Keychain
    /// - Parameters:
    ///   - service: Service identifier
    ///   - account: Account identifier
    /// - Returns: The stored data, or nil if not found
    func getData(service: String, account: String) throws -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError(status: status)
        }
    }

    // MARK: - Delete Operations

    /// Delete an item from the Keychain
    /// - Parameters:
    ///   - service: Service identifier
    ///   - account: Account identifier
    /// - Note: Deleting a non-existent item succeeds (idempotent)
    func delete(service: String, account: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        // Item not found is OK for delete (idempotent behavior)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    // MARK: - Utility Operations

    /// Check if an item exists in the Keychain (without retrieving it)
    /// - Parameters:
    ///   - service: Service identifier
    ///   - account: Account identifier
    /// - Returns: true if the item exists
    func exists(service: String, account: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}

// MARK: - Provider-Specific Convenience Methods

extension KeychainWrapper {
    static let defaultAccount = "api_key"

    // MARK: - OpenAI

    func saveOpenAIKey(_ key: String) throws {
        try self.saveString(key, service: KeychainServiceName.openAI, account: Self.defaultAccount)
    }

    func getOpenAIKey() throws -> String? {
        try self.getString(service: KeychainServiceName.openAI, account: Self.defaultAccount)
    }

    func deleteOpenAIKey() throws {
        try self.delete(service: KeychainServiceName.openAI, account: Self.defaultAccount)
    }

    func hasOpenAIKey() -> Bool {
        self.exists(service: KeychainServiceName.openAI, account: Self.defaultAccount)
    }

    // MARK: - Anthropic

    func saveAnthropicKey(_ key: String) throws {
        try self.saveString(key, service: KeychainServiceName.anthropic, account: Self.defaultAccount)
    }

    func getAnthropicKey() throws -> String? {
        try self.getString(service: KeychainServiceName.anthropic, account: Self.defaultAccount)
    }

    func deleteAnthropicKey() throws {
        try self.delete(service: KeychainServiceName.anthropic, account: Self.defaultAccount)
    }

    func hasAnthropicKey() -> Bool {
        self.exists(service: KeychainServiceName.anthropic, account: Self.defaultAccount)
    }

    // MARK: - OpenRouter

    func saveOpenRouterKey(_ key: String) throws {
        try self.saveString(key, service: KeychainServiceName.openrouter, account: Self.defaultAccount)
    }

    func getOpenRouterKey() throws -> String? {
        try self.getString(service: KeychainServiceName.openrouter, account: Self.defaultAccount)
    }

    func deleteOpenRouterKey() throws {
        try self.delete(service: KeychainServiceName.openrouter, account: Self.defaultAccount)
    }

    func hasOpenRouterKey() -> Bool {
        self.exists(service: KeychainServiceName.openrouter, account: Self.defaultAccount)
    }

    // MARK: - AWS Bedrock

    func saveAWSAccessKey(_ key: String) throws {
        try self.saveString(key, service: KeychainServiceName.awsAccessKey, account: Self.defaultAccount)
    }

    func getAWSAccessKey() throws -> String? {
        try self.getString(service: KeychainServiceName.awsAccessKey, account: Self.defaultAccount)
    }

    func deleteAWSAccessKey() throws {
        try self.delete(service: KeychainServiceName.awsAccessKey, account: Self.defaultAccount)
    }

    func hasAWSAccessKey() -> Bool {
        self.exists(service: KeychainServiceName.awsAccessKey, account: Self.defaultAccount)
    }

    func saveAWSSecretKey(_ key: String) throws {
        try self.saveString(key, service: KeychainServiceName.awsSecretKey, account: Self.defaultAccount)
    }

    func getAWSSecretKey() throws -> String? {
        try self.getString(service: KeychainServiceName.awsSecretKey, account: Self.defaultAccount)
    }

    func deleteAWSSecretKey() throws {
        try self.delete(service: KeychainServiceName.awsSecretKey, account: Self.defaultAccount)
    }

    func hasAWSSecretKey() -> Bool {
        self.exists(service: KeychainServiceName.awsSecretKey, account: Self.defaultAccount)
    }

    // MARK: - Ollama (endpoint configuration, not API key)

    func saveOllamaEndpoint(_ endpoint: String) throws {
        try self.saveString(endpoint, service: KeychainServiceName.ollama, account: "endpoint")
    }

    func getOllamaEndpoint() throws -> String? {
        try self.getString(service: KeychainServiceName.ollama, account: "endpoint")
    }

    func deleteOllamaEndpoint() throws {
        try self.delete(service: KeychainServiceName.ollama, account: "endpoint")
    }
}

// MARK: - MockKeychainService

/// Mock implementation of KeychainService for testing
final class MockKeychainService: KeychainService, @unchecked Sendable {
    private var storage: [String: String] = [:]
    private let lock = NSLock()

    private func key(service: String, account: String) -> String {
        "\(service):\(account)"
    }

    func saveString(_ value: String, service: String, account: String) throws {
        self.lock.lock()
        defer { lock.unlock() }
        self.storage[self.key(service: service, account: account)] = value
    }

    func getString(service: String, account: String) throws -> String? {
        self.lock.lock()
        defer { lock.unlock() }
        return self.storage[self.key(service: service, account: account)]
    }

    func delete(service: String, account: String) throws {
        self.lock.lock()
        defer { lock.unlock() }
        self.storage.removeValue(forKey: self.key(service: service, account: account))
    }

    func exists(service: String, account: String) -> Bool {
        self.lock.lock()
        defer { lock.unlock() }
        return self.storage[self.key(service: service, account: account)] != nil
    }

    /// Clear all stored values (useful in test teardown)
    func reset() {
        self.lock.lock()
        defer { lock.unlock() }
        self.storage.removeAll()
    }
}
