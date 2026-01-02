import OptimusClipCore
import Testing
@testable import OptimusClip

@Suite("TransformationTester")
struct TransformationTesterTests {
    @Test("runTest throws noProviderConfigured when no provider is set")
    func noProviderThrows() async throws {
        let transform = TransformationConfig(
            name: "Test",
            isEnabled: true,
            provider: nil,
            systemPrompt: "Test"
        )

        let tester = TransformationTester()

        await #expect(throws: TransformationTestError.noProviderConfigured) {
            _ = try await tester.runTest(transformation: transform, input: "hello")
        }
    }

    @Test("runTest throws noProviderConfigured when provider is empty string")
    func emptyProviderThrows() async throws {
        let transform = TransformationConfig(
            name: "Test",
            isEnabled: true,
            provider: "",
            systemPrompt: "Test"
        )

        let tester = TransformationTester()

        await #expect(throws: TransformationTestError.noProviderConfigured) {
            _ = try await tester.runTest(transformation: transform, input: "hello")
        }
    }

    @Test("provider display names use shared normalization")
    func providerDisplayNamesUseSharedNormalization() {
        #expect(TransformationTester.providerDisplayName(forRawValue: "AWS") == "AWS Bedrock")
        #expect(TransformationTester.providerDisplayName(forRawValue: " openrouter ") == "OpenRouter")
        #expect(TransformationTester.providerDisplayName(forRawValue: "custom-provider") == "Custom-Provider")
    }
}
