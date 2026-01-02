import Foundation
import Testing
@testable import OptimusClip

/// Test suite for TransformationConfig model.
///
/// Tests JSON encoding/decoding and static factory properties.
@Suite("TransformationConfig Tests")
struct TransformationConfigTests {
    // MARK: - Basic Properties Tests

    @Test("TransformationConfig has correct default values")
    func defaultValues() {
        let config = TransformationConfig(name: "Test")

        #expect(config.name == "Test")
        #expect(config.isEnabled == true)
        #expect(config.provider == nil)
        #expect(config.model == nil)
        #expect(config.systemPrompt == "")
    }

    @Test("TransformationConfig can be created with all properties")
    func fullInitialization() {
        let config = TransformationConfig(
            name: "Full Config",
            isEnabled: false,
            provider: "anthropic",
            model: "claude-3-sonnet",
            systemPrompt: "Test prompt"
        )

        #expect(config.name == "Full Config")
        #expect(config.isEnabled == false)
        #expect(config.provider == "anthropic")
        #expect(config.model == "claude-3-sonnet")
        #expect(config.systemPrompt == "Test prompt")
    }

    // MARK: - JSON Encoding/Decoding Tests

    @Test("TransformationConfig round-trips through JSON")
    func jsonRoundTrip() throws {
        let original = TransformationConfig(
            name: "Test",
            isEnabled: true,
            provider: "openai",
            model: "gpt-4",
            systemPrompt: "Do something"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TransformationConfig.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.isEnabled == original.isEnabled)
        #expect(decoded.provider == original.provider)
        #expect(decoded.model == original.model)
        #expect(decoded.systemPrompt == original.systemPrompt)
    }

    @Test("TransformationConfig decodes with missing optional fields")
    func decodingWithMissingOptionals() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000099",
            "name": "Minimal Transform",
            "isEnabled": true,
            "systemPrompt": ""
        }
        """
        let data = try #require(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(TransformationConfig.self, from: data)

        #expect(decoded.name == "Minimal Transform")
        #expect(decoded.provider == nil)
        #expect(decoded.model == nil)
    }

    // MARK: - Stable UUID Tests

    @Test("cleanTerminalTextDefaultID is stable UUID")
    func cleanTerminalTextDefaultIDIsStable() throws {
        let expectedUUID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        #expect(TransformationConfig.cleanTerminalTextDefaultID == expectedUUID)
    }

    @Test("formatAsMarkdownDefaultID is stable UUID")
    func formatAsMarkdownDefaultIDIsStable() throws {
        let expectedUUID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        #expect(TransformationConfig.formatAsMarkdownDefaultID == expectedUUID)
    }

    // MARK: - Default Transformations Tests

    @Test("defaultTransformations contains Clean Terminal Text")
    func defaultTransformationsContainsCleanTerminalText() {
        let defaults = TransformationConfig.defaultTransformations

        let cleanTerminal = defaults.first { $0.id == TransformationConfig.cleanTerminalTextDefaultID }
        #expect(cleanTerminal != nil)
        #expect(cleanTerminal?.name == "Clean Terminal Text")
        #expect(cleanTerminal?.provider == "anthropic")
        #expect(cleanTerminal?.systemPrompt.isEmpty == false)
    }

    @Test("defaultTransformations contains Format As Markdown")
    func defaultTransformationsContainsFormatAsMarkdown() {
        let defaults = TransformationConfig.defaultTransformations

        let formatAsMarkdown = defaults.first { $0.id == TransformationConfig.formatAsMarkdownDefaultID }
        #expect(formatAsMarkdown != nil)
        #expect(formatAsMarkdown?.name == "Format As Markdown")
        #expect(formatAsMarkdown?.provider == "anthropic")
        #expect(formatAsMarkdown?.systemPrompt.isEmpty == false)
    }

    @Test("Clean Terminal Text has prompt for LLM processing")
    func cleanTerminalTextHasLLMPrompt() {
        let defaults = TransformationConfig.defaultTransformations
        let cleanTerminal = defaults.first { $0.id == TransformationConfig.cleanTerminalTextDefaultID }

        #expect(cleanTerminal?.systemPrompt.contains("terminal") == true)
        #expect(cleanTerminal?.systemPrompt.contains("whitespace") == true)
    }

    // MARK: - Persistence Tests

    @Test("decodeStoredTransformations returns defaults when data is nil")
    func decodesDefaultsWhenNil() throws {
        let decoded = try TransformationConfig.decodeStoredTransformations(from: nil)

        #expect(decoded.isEmpty == false)
        #expect(decoded.first?.id == TransformationConfig.cleanTerminalTextDefaultID)
    }

    @Test("decodeStoredTransformations returns defaults when data is empty")
    func decodesDefaultsWhenEmpty() throws {
        let decoded = try TransformationConfig.decodeStoredTransformations(from: Data())

        #expect(decoded.isEmpty == false)
        #expect(decoded.first?.id == TransformationConfig.cleanTerminalTextDefaultID)
    }

    @Test("decodeStoredTransformations decodes valid stored data")
    func decodesStoredData() throws {
        let stored = [
            TransformationConfig(
                name: "Custom Transform",
                provider: "openai",
                systemPrompt: "Custom prompt"
            )
        ]
        let data = try JSONEncoder().encode(stored)

        let decoded = try TransformationConfig.decodeStoredTransformations(from: data)

        #expect(decoded.count == 1)
        #expect(decoded.first?.name == "Custom Transform")
    }
}
