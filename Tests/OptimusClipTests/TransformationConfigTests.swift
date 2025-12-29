import Foundation
import Testing
@testable import OptimusClip

/// Test suite for TransformationConfig model.
///
/// Tests the isBuiltIn property, JSON encoding/decoding,
/// and static factory properties for built-in transformations.
@Suite("TransformationConfig Tests")
struct TransformationConfigTests {
    // MARK: - isBuiltIn Property Tests

    @Test("isBuiltIn defaults to false")
    func isBuiltInDefaultsFalse() {
        let config = TransformationConfig(name: "Test")
        #expect(config.isBuiltIn == false)
    }

    @Test("isBuiltIn can be set to true")
    func isBuiltInCanBeTrue() {
        let config = TransformationConfig(name: "Test", isBuiltIn: true)
        #expect(config.isBuiltIn == true)
    }

    // MARK: - JSON Encoding/Decoding Tests

    @Test("TransformationConfig encodes isBuiltIn")
    func encodesIsBuiltIn() throws {
        let config = TransformationConfig(name: "Test", isBuiltIn: true)
        let data = try JSONEncoder().encode(config)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains("\"isBuiltIn\":true"))
    }

    @Test("TransformationConfig decodes isBuiltIn true")
    func decodesIsBuiltInTrue() throws {
        let config = TransformationConfig(name: "Test", isBuiltIn: true)
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TransformationConfig.self, from: data)

        #expect(decoded.isBuiltIn == true)
    }

    @Test("TransformationConfig decodes isBuiltIn false")
    func decodesIsBuiltInFalse() throws {
        let config = TransformationConfig(name: "Test", isBuiltIn: false)
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TransformationConfig.self, from: data)

        #expect(decoded.isBuiltIn == false)
    }

    @Test("Pre-update JSON without isBuiltIn decodes with default false")
    func backwardCompatibility() throws {
        // Simulate JSON from before isBuiltIn was added
        let legacyJSON = """
        {
            "id": "00000000-0000-0000-0000-000000000099",
            "name": "Legacy Transform",
            "type": "llm",
            "isEnabled": true,
            "systemPrompt": ""
        }
        """
        let data = try #require(legacyJSON.data(using: .utf8))
        let decoded = try JSONDecoder().decode(TransformationConfig.self, from: data)

        #expect(decoded.name == "Legacy Transform")
        #expect(decoded.isBuiltIn == false)
    }

    // MARK: - Static Factory Tests

    @Test("builtInCleanTerminalText has correct properties")
    func builtInCleanTerminalTextProperties() {
        let builtIn = TransformationConfig.builtInCleanTerminalText

        #expect(builtIn.name == "Clean Terminal Text")
        #expect(builtIn.type == .algorithmic)
        #expect(builtIn.isBuiltIn == true)
        #expect(builtIn.isEnabled == true)
        #expect(builtIn.id == TransformationConfig.cleanTerminalTextDefaultID)
    }

    @Test("cleanTerminalTextDefaultID is stable UUID")
    func cleanTerminalTextDefaultIDIsStable() throws {
        let expectedUUID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        #expect(TransformationConfig.cleanTerminalTextDefaultID == expectedUUID)
    }

    @Test("defaultTransformations contains built-in as first item")
    func defaultTransformationsContainsBuiltIn() {
        let defaults = TransformationConfig.defaultTransformations

        #expect(defaults.count >= 1)
        #expect(defaults[0].isBuiltIn == true)
        #expect(defaults[0].id == TransformationConfig.cleanTerminalTextDefaultID)
    }

    @Test("defaultTransformations Format As Markdown is not built-in")
    func formatAsMarkdownNotBuiltIn() {
        let defaults = TransformationConfig.defaultTransformations
        let formatAsMarkdown = defaults.first { $0.name == "Format As Markdown" }

        #expect(formatAsMarkdown != nil)
        #expect(formatAsMarkdown?.isBuiltIn == false)
    }
}

// MARK: - Storage Tests

/// Tests for TransformationConfig storage methods.
///
/// These tests verify that loadFromStorage and saveToStorage work correctly
/// and that all decode paths in the app use consistent logic.
@Suite("TransformationConfig Storage Tests")
struct TransformationConfigStorageTests {
    /// Test key used to avoid polluting real UserDefaults.
    private let testKey = SettingsKey.transformationsData

    /// Clears test data before each test.
    private func clearTestData() {
        UserDefaults.standard.removeObject(forKey: self.testKey)
    }

    @Test("loadFromStorage returns defaults when storage is empty")
    func loadFromStorageReturnsDefaultsWhenEmpty() {
        self.clearTestData()

        let loaded = TransformationConfig.loadFromStorage()

        #expect(loaded == TransformationConfig.defaultTransformations)
    }

    @Test("loadFromStorage decodes valid stored data")
    func loadFromStorageDecodesValidData() throws {
        self.clearTestData()

        // Store custom transformations
        let custom = [
            TransformationConfig(name: "Custom One", type: .llm, systemPrompt: "Test prompt 1"),
            TransformationConfig(name: "Custom Two", type: .algorithmic)
        ]
        let data = try JSONEncoder().encode(custom)
        UserDefaults.standard.set(data, forKey: self.testKey)

        let loaded = TransformationConfig.loadFromStorage()

        #expect(loaded.count == 2)
        #expect(loaded[0].name == "Custom One")
        #expect(loaded[0].systemPrompt == "Test prompt 1")
        #expect(loaded[1].name == "Custom Two")

        self.clearTestData()
    }

    @Test("loadFromStorage returns defaults on corrupted data")
    func loadFromStorageReturnsDefaultsOnCorruptedData() {
        self.clearTestData()

        // Store invalid JSON
        let corruptedData = Data("not valid json".utf8)
        UserDefaults.standard.set(corruptedData, forKey: self.testKey)

        let loaded = TransformationConfig.loadFromStorage()

        #expect(loaded == TransformationConfig.defaultTransformations)

        self.clearTestData()
    }

    @Test("saveToStorage and loadFromStorage round-trip correctly")
    func saveAndLoadRoundTrip() {
        self.clearTestData()

        let original = [
            TransformationConfig(
                name: "Round Trip Test",
                type: .llm,
                isEnabled: true,
                provider: "anthropic",
                model: "claude-3-opus",
                systemPrompt: "You are a helpful assistant.",
                isBuiltIn: false
            )
        ]

        TransformationConfig.saveToStorage(original)
        let loaded = TransformationConfig.loadFromStorage()

        #expect(loaded.count == 1)
        #expect(loaded[0].name == original[0].name)
        #expect(loaded[0].type == original[0].type)
        #expect(loaded[0].isEnabled == original[0].isEnabled)
        #expect(loaded[0].provider == original[0].provider)
        #expect(loaded[0].model == original[0].model)
        #expect(loaded[0].systemPrompt == original[0].systemPrompt)
        #expect(loaded[0].isBuiltIn == original[0].isBuiltIn)

        self.clearTestData()
    }

    @Test("Edited prompt persists and loads correctly")
    func editedPromptPersistsCorrectly() {
        self.clearTestData()

        // Start with defaults
        var transformations = TransformationConfig.defaultTransformations

        // Find Format As Markdown and edit its prompt
        if let index = transformations.firstIndex(where: { $0.name == "Format As Markdown" }) {
            transformations[index].systemPrompt = "CUSTOM EDITED PROMPT"
        }

        // Save
        TransformationConfig.saveToStorage(transformations)

        // Load fresh
        let loaded = TransformationConfig.loadFromStorage()

        // Verify the edit persisted
        let formatAsMarkdown = loaded.first { $0.name == "Format As Markdown" }
        #expect(formatAsMarkdown?.systemPrompt == "CUSTOM EDITED PROMPT")

        self.clearTestData()
    }
}
