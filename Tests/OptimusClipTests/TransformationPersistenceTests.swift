import Foundation
import Testing
@testable import OptimusClip
@testable import OptimusClipCore

@Suite("Transformation Persistence")
struct TransformationPersistenceTests {
    @Test("Throws on invalid transformation data")
    func throwsOnInvalidData() {
        let invalidData = Data([0x00, 0x01])

        #expect(throws: Error.self) {
            _ = try TransformationConfig.decodeStoredTransformations(from: invalidData)
        }
    }

    @Test("Loads stored Format As Markdown configuration")
    func loadsStoredFormatAsMarkdownConfig() async throws {
        let suiteName = "test-format-as-markdown-config"
        let stored = TransformationConfig(
            id: TransformationConfig.formatAsMarkdownDefaultID,
            name: "Format As Markdown",
            type: .llm,
            isEnabled: true,
            provider: "openai",
            model: "gpt-4o",
            systemPrompt: "custom prompt"
        )

        let data = try JSONEncoder().encode([stored])

        let loaded = try await MainActor.run { () -> TransformationConfig? in
            let defaults = try #require(UserDefaults(suiteName: suiteName))
            defer { defaults.removePersistentDomain(forName: suiteName) }
            defaults.set(data, forKey: SettingsKey.transformationsData)

            let manager = HotkeyManager(userDefaults: defaults)
            return manager.formatAsMarkdownTransformation()
        }

        #expect(loaded?.systemPrompt == "custom prompt")
        #expect(loaded?.provider == "openai")
        #expect(loaded?.model == "gpt-4o")
    }
}
