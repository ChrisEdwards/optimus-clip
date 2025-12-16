import CryptoKit
import Foundation

/// Encrypted storage service that stores AES-GCM encrypted data in UserDefaults.
/// Implements `KeychainService` protocol as a drop-in replacement for `KeychainWrapper`.
///
/// This avoids the repeated Keychain password prompts that occur during development
/// due to code signature changes on debug builds.
final class EncryptedStorageService: KeychainService, @unchecked Sendable {
    static let shared = EncryptedStorageService()

    private let defaults: UserDefaults
    private let encryptionKey: SymmetricKey
    private let keyPrefix = "com.optimusclip.encrypted."

    init(defaults: UserDefaults = .standard, keySeed: String = "com.optimusclip.secure.storage.v1") {
        self.defaults = defaults
        // Derive a stable encryption key from a fixed seed + device identifier
        // This ensures the key survives app restarts but is unique per device
        let deviceID = Self.getDeviceIdentifier()
        let combinedSeed = "\(keySeed).\(deviceID)"
        let keyData = SHA256.hash(data: Data(combinedSeed.utf8))
        self.encryptionKey = SymmetricKey(data: keyData)
    }

    // MARK: - KeychainService Protocol

    func saveString(_ value: String, service: String, account: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw EncryptedStorageError.encodingFailed
        }

        let sealed = try AES.GCM.seal(data, using: self.encryptionKey)
        guard let combined = sealed.combined else {
            throw EncryptedStorageError.encryptionFailed
        }

        let key = self.storageKey(service: service, account: account)
        self.defaults.set(combined, forKey: key)
    }

    func getString(service: String, account: String) throws -> String? {
        let key = self.storageKey(service: service, account: account)
        guard let combined = self.defaults.data(forKey: key) else {
            return nil
        }

        let sealedBox = try AES.GCM.SealedBox(combined: combined)
        let decrypted = try AES.GCM.open(sealedBox, using: self.encryptionKey)

        guard let string = String(data: decrypted, encoding: .utf8) else {
            throw EncryptedStorageError.decodingFailed
        }

        return string
    }

    func delete(service: String, account: String) throws {
        let key = self.storageKey(service: service, account: account)
        self.defaults.removeObject(forKey: key)
    }

    func exists(service: String, account: String) -> Bool {
        let key = self.storageKey(service: service, account: account)
        return self.defaults.data(forKey: key) != nil
    }

    // MARK: - Private Helpers

    private func storageKey(service: String, account: String) -> String {
        "\(self.keyPrefix)\(service).\(account)"
    }

    /// Get a stable device identifier for key derivation.
    /// Falls back to a random UUID stored in UserDefaults if hardware ID unavailable.
    private static func getDeviceIdentifier() -> String {
        let fallbackKey = "com.optimusclip.device.id"

        // Try to get hardware UUID (stable across reinstalls)
        if let hardwareUUID = getHardwareUUID() {
            return hardwareUUID
        }

        // Fallback: use a stored random UUID
        if let stored = UserDefaults.standard.string(forKey: fallbackKey) {
            return stored
        }

        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: fallbackKey)
        return newID
    }

    /// Attempt to get the hardware UUID from IOKit
    private static func getHardwareUUID() -> String? {
        let platformExpert = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )

        guard platformExpert != 0 else { return nil }
        defer { IOObjectRelease(platformExpert) }

        guard let uuidData = IORegistryEntryCreateCFProperty(
            platformExpert,
            kIOPlatformUUIDKey as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String else {
            return nil
        }

        return uuidData
    }
}

// MARK: - Errors

enum EncryptedStorageError: LocalizedError, Equatable {
    case encodingFailed
    case decodingFailed
    case encryptionFailed
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            "Failed to encode value for encryption."
        case .decodingFailed:
            "Failed to decode decrypted value."
        case .encryptionFailed:
            "Failed to encrypt value."
        case .decryptionFailed:
            "Failed to decrypt value."
        }
    }
}

// MARK: - Migration Helper

extension EncryptedStorageService {
    /// Migrate existing Keychain values to encrypted storage.
    /// Call this once at app startup to preserve existing credentials.
    func migrateFromKeychain(_ keychain: KeychainWrapper = .shared) {
        let migrations: [(service: String, account: String)] = [
            (KeychainServiceName.openAI, KeychainWrapper.defaultAccount),
            (KeychainServiceName.anthropic, KeychainWrapper.defaultAccount),
            (KeychainServiceName.openrouter, KeychainWrapper.defaultAccount),
            (KeychainServiceName.awsAccessKey, KeychainWrapper.defaultAccount),
            (KeychainServiceName.awsSecretKey, KeychainWrapper.defaultAccount),
            (KeychainServiceName.awsBearerToken, KeychainWrapper.defaultAccount),
            (KeychainServiceName.ollama, "endpoint")
        ]

        for (service, account) in migrations {
            do {
                // Skip if already migrated
                if self.exists(service: service, account: account) {
                    continue
                }

                // Try to get from Keychain
                guard let value = try keychain.getString(service: service, account: account) else {
                    continue
                }

                // Save to encrypted storage
                try self.saveString(value, service: service, account: account)

                // Delete from Keychain (optional - keeps things clean)
                try? keychain.delete(service: service, account: account)

                print("[Migration] Migrated \(service) from Keychain to encrypted storage")
            } catch {
                print("[Migration] Failed to migrate \(service): \(error)")
            }
        }
    }
}
