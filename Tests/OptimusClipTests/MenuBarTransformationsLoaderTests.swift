import Foundation
import OptimusClipCore
import Testing
@testable import OptimusClip

@Suite("Menu bar transformations loading")
struct MenuBarTransformationsLoaderTests {
    @Test("Invalid data returns failure and no transformations are used")
    func invalidDataDoesNotFallbackToDefaults() {
        let invalid = Data([0x00, 0x01])
        let result = MenuBarTransformationsLoader.load(from: invalid)

        switch result {
        case .success:
            Issue.record("Expected decode failure for invalid data")
        case .failure:
            #expect(true)
        }
    }

    @Test("Missing built-in is added via migration for menu bar")
    func migrationMatchesSettingsAndHotkeys() throws {
        let custom = TransformationConfig(
            id: UUID(),
            name: "Custom",
            type: .llm,
            isEnabled: true,
            provider: "openrouter",
            model: "meta-llama/llama-3.1-8b-instruct:free"
        )
        let data = try JSONEncoder().encode([custom])

        let result = MenuBarTransformationsLoader.load(from: data)
        let transformations = try result.get()

        #expect(transformations.contains { $0.id == TransformationConfig.cleanTerminalTextDefaultID })
        #expect(transformations.contains { $0.id == custom.id })
    }
}
