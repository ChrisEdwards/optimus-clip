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

    // MARK: - Migration Logic Tests

    @Test("Migration adds built-in when missing from array")
    func migrationAddsBuiltInWhenMissing() throws {
        // Simulate user who deleted Clean Terminal Text before update
        let stored: [TransformationConfig] = [
            TransformationConfig(name: "My Custom Transform", type: .llm)
        ]

        let data = try JSONEncoder().encode(stored)
        let migrated = try TransformationConfig.decodeStoredTransformations(from: data)

        let builtInID = TransformationConfig.cleanTerminalTextDefaultID
        #expect(migrated.count == 2)
        #expect(migrated.first?.id == builtInID)
        #expect(migrated.first?.isBuiltIn == true)
    }

    @Test("Migration sets isBuiltIn flag on existing Clean Terminal Text")
    func migrationSetsIsBuiltInFlag() throws {
        // Simulate existing data without isBuiltIn flag
        let stored: [TransformationConfig] = [
            TransformationConfig(
                id: TransformationConfig.cleanTerminalTextDefaultID,
                name: "Clean Terminal Text",
                type: .algorithmic,
                isBuiltIn: false // Pre-update data
            )
        ]

        let data = try JSONEncoder().encode(stored)
        let migrated = try TransformationConfig.decodeStoredTransformations(from: data)

        #expect(migrated.count == 1)
        #expect(migrated.first?.isBuiltIn == true)
    }

    @Test("Migration preserves user customizations on built-in")
    func migrationPreservesCustomizations() throws {
        // User may have changed hotkey or disabled - migration should preserve those
        let stored: [TransformationConfig] = [
            TransformationConfig(
                id: TransformationConfig.cleanTerminalTextDefaultID,
                name: "Clean Terminal Text",
                type: .algorithmic,
                isEnabled: false, // User disabled it
                isBuiltIn: false
            )
        ]

        let data = try JSONEncoder().encode(stored)
        let migrated = try TransformationConfig.decodeStoredTransformations(from: data)

        #expect(migrated.first?.isBuiltIn == true)
        #expect(migrated.first?.isEnabled == false) // Preserved
    }
}
