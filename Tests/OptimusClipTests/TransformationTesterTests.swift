import OptimusClipCore
import Testing
@testable import OptimusClip

@Suite("TransformationTester")
struct TransformationTesterTests {
    @MainActor
    @Test("Algorithmic test uses Clean Terminal Text pipeline")
    func algorithmicTestMatchesPipeline() async throws {
        let input = "line one wraps\nline two continues\nline three keeps going"

        let tester = TransformationTester()
        let tested = try await tester.runTest(
            transformation: TransformationConfig.builtInCleanTerminalText,
            input: input
        )

        let pipelineResult = try await TransformationPipeline.cleanTerminalText().execute(input)

        #expect(tested == pipelineResult.output)
    }

    @Test("provider display names use shared normalization")
    func providerDisplayNamesUseSharedNormalization() {
        #expect(TransformationTester.providerDisplayName(forRawValue: "AWS") == "AWS Bedrock")
        #expect(TransformationTester.providerDisplayName(forRawValue: " openrouter ") == "OpenRouter")
        #expect(TransformationTester.providerDisplayName(forRawValue: "custom-provider") == "Custom-Provider")
    }
}
