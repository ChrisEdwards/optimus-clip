import Foundation
import Testing
@testable import OptimusClip
@testable import OptimusClipCore

/// Tests for transformation timeout configuration.
///
/// Verifies that the user's timeout setting from UserDefaults is correctly
/// read and passed to LLMTransformation instances.
@Suite("Transformation Timeout")
struct TransformationTimeoutTests {
    // MARK: - Timeout Reading Logic Tests

    @Test("uses timeout from UserDefaults when set")
    func usesTimeoutFromUserDefaults() throws {
        let suiteName = "test-timeout-set"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.set(60.0, forKey: SettingsKey.transformationTimeout)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let timeoutSeconds = defaults.double(forKey: SettingsKey.transformationTimeout)
        let effectiveTimeout = timeoutSeconds > 0 ? timeoutSeconds : DefaultSettings.transformationTimeout

        #expect(effectiveTimeout == 60.0)
    }

    @Test("falls back to default when UserDefaults value is zero")
    func fallsBackWhenZero() throws {
        let suiteName = "test-timeout-zero"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.set(0.0, forKey: SettingsKey.transformationTimeout)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let timeoutSeconds = defaults.double(forKey: SettingsKey.transformationTimeout)
        let effectiveTimeout = timeoutSeconds > 0 ? timeoutSeconds : DefaultSettings.transformationTimeout

        #expect(effectiveTimeout == DefaultSettings.transformationTimeout)
    }

    @Test("falls back to default when UserDefaults key not set")
    func fallsBackWhenNotSet() throws {
        let suiteName = "test-timeout-notset"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removeObject(forKey: SettingsKey.transformationTimeout)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let timeoutSeconds = defaults.double(forKey: SettingsKey.transformationTimeout)
        let effectiveTimeout = timeoutSeconds > 0 ? timeoutSeconds : DefaultSettings.transformationTimeout

        #expect(effectiveTimeout == DefaultSettings.transformationTimeout)
        #expect(effectiveTimeout == 90.0) // Verify the actual default value
    }

    @Test("respects all timeout picker options")
    func respectsAllPickerOptions() throws {
        let validTimeouts: [Double] = [15, 30, 45, 60, 90, 120]

        for expectedTimeout in validTimeouts {
            let suiteName = "test-timeout-\(Int(expectedTimeout))"
            let defaults = try #require(UserDefaults(suiteName: suiteName))
            defaults.set(expectedTimeout, forKey: SettingsKey.transformationTimeout)
            defer { defaults.removePersistentDomain(forName: suiteName) }

            let timeoutSeconds = defaults.double(forKey: SettingsKey.transformationTimeout)
            let effectiveTimeout = timeoutSeconds > 0 ? timeoutSeconds : DefaultSettings.transformationTimeout

            #expect(effectiveTimeout == expectedTimeout)
        }
    }

    // MARK: - LLMTransformation Timeout Passthrough Test

    @Test("LLMTransformation receives configured timeout")
    func llmTransformationReceivesTimeout() async throws {
        let capture = TimeoutCapture()

        let provider = TimeoutCapturingProvider(capture: capture)

        let transformation = LLMTransformation(
            id: "timeout-test",
            displayName: "Timeout Test",
            providerClient: provider,
            model: "test-model",
            systemPrompt: "test",
            timeoutSeconds: 75.0
        )

        _ = try await transformation.transform("input")

        let capturedTimeout = await capture.timeout
        #expect(capturedTimeout == 75.0)
    }
}

// MARK: - Test Doubles

private actor TimeoutCapture {
    var timeout: TimeInterval = 0

    func capture(_ value: TimeInterval) {
        self.timeout = value
    }
}

private struct TimeoutCapturingProvider: LLMProviderClient {
    let provider: LLMProviderKind = .openAI
    private let capture: TimeoutCapture

    init(capture: TimeoutCapture) {
        self.capture = capture
    }

    func isConfigured() -> Bool {
        true
    }

    func transform(_ request: LLMRequest) async throws -> LLMResponse {
        await self.capture.capture(request.timeout)
        return LLMResponse(
            provider: request.provider,
            model: request.model,
            output: "result",
            duration: 0.1
        )
    }
}
