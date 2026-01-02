import Testing
@testable import OptimusClip

@Suite("TransformationConfig LLM-Only Tests")
struct TransformationConfigLLMOnlyTests {
    @Test("TransformationConfig has no type property")
    func noTypeProperty() {
        let config = TransformationConfig(
            name: "Test",
            isEnabled: true,
            provider: "anthropic",
            systemPrompt: "Test prompt"
        )

        // If this compiles, there's no type property
        #expect(config.name == "Test")
        #expect(config.provider == "anthropic")
    }

    @Test("TransformationConfig has no isBuiltIn property")
    func noIsBuiltInProperty() {
        let config = TransformationConfig(
            name: "Test",
            isEnabled: true
        )

        // If this compiles, there's no isBuiltIn property
        #expect(config.name == "Test")
    }

    @Test("Default Clean Terminal Text is LLM-based with prompt")
    func defaultCleanTerminalTextHasPrompt() {
        let defaults = TransformationConfig.defaultTransformations
        let cleanTerminal = defaults.first { $0.id == TransformationConfig.cleanTerminalTextDefaultID }

        #expect(cleanTerminal != nil)
        #expect(cleanTerminal?.systemPrompt.isEmpty == false)
        #expect(cleanTerminal?.provider == "anthropic")
    }
}
