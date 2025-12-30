import Foundation
import OptimusClipCore
import SwiftUI
import Testing
@testable import OptimusClip

/// Test suite for HotkeyManager transformation cache behavior.
///
/// These tests verify that:
/// - Transformations are correctly cached when registered
/// - Cache updates are applied when transformations are edited
/// - The correct transformation is retrieved when a hotkey is triggered
@Suite("HotkeyManager Cache Tests")
struct HotkeyManagerCacheTests {
    // MARK: - Cache Update Tests

    @Test("updateTransformation updates cached transformation")
    @MainActor
    func updateTransformationUpdatesCachedValue() {
        let manager = HotkeyManager.shared

        // Create initial transformation with old prompt
        let id = UUID()
        var transformation = TransformationConfig(
            id: id,
            name: "Test LLM Transform",
            type: .llm,
            isEnabled: true,
            provider: "anthropic",
            systemPrompt: "Original prompt"
        )

        // Register the transformation (stores in cache)
        manager.register(transformation: transformation)

        // Update the system prompt
        transformation.systemPrompt = "Updated prompt"

        // Call updateTransformation (simulates what the binding does)
        manager.updateTransformation(transformation)

        // Retrieve the cached transformation and verify the update
        let cached = manager.getCachedTransformation(for: transformation.shortcutName)
        #expect(cached != nil, "Transformation should be in cache")
        #expect(cached?.systemPrompt == "Updated prompt", "Cache should have updated prompt")

        // Cleanup
        manager.unregister(transformation: transformation)
    }

    @Test("getCachedTransformation returns nil for unregistered transformation")
    @MainActor
    func getCachedTransformationReturnsNilForUnregistered() {
        let manager = HotkeyManager.shared

        let transformation = TransformationConfig(
            id: UUID(),
            name: "Never Registered",
            type: .llm,
            isEnabled: true
        )

        let cached = manager.getCachedTransformation(for: transformation.shortcutName)
        #expect(cached == nil, "Should return nil for unregistered transformation")
    }

    @Test("Multiple updates to same transformation all apply")
    @MainActor
    func multipleUpdatesAllApply() {
        let manager = HotkeyManager.shared

        let id = UUID()
        var transformation = TransformationConfig(
            id: id,
            name: "Multi-Update Test",
            type: .llm,
            isEnabled: true,
            provider: "anthropic",
            systemPrompt: "Version 1"
        )

        manager.register(transformation: transformation)

        // Update multiple times
        transformation.systemPrompt = "Version 2"
        manager.updateTransformation(transformation)

        transformation.systemPrompt = "Version 3"
        manager.updateTransformation(transformation)

        transformation.systemPrompt = "Final Version"
        manager.updateTransformation(transformation)

        let cached = manager.getCachedTransformation(for: transformation.shortcutName)
        #expect(cached?.systemPrompt == "Final Version", "Should have final version")

        manager.unregister(transformation: transformation)
    }

    @Test("Cache uses correct key based on UUID")
    @MainActor
    func cacheUsesCorrectKeyBasedOnUUID() {
        let manager = HotkeyManager.shared

        // Create two transformations with different UUIDs
        let id1 = UUID()
        let id2 = UUID()

        var transform1 = TransformationConfig(
            id: id1,
            name: "Transform 1",
            type: .llm,
            isEnabled: true,
            systemPrompt: "Prompt 1"
        )

        var transform2 = TransformationConfig(
            id: id2,
            name: "Transform 2",
            type: .llm,
            isEnabled: true,
            systemPrompt: "Prompt 2"
        )

        manager.register(transformation: transform1)
        manager.register(transformation: transform2)

        // Update transform1 only
        transform1.systemPrompt = "Updated Prompt 1"
        manager.updateTransformation(transform1)

        // Verify transform1 is updated but transform2 is not
        let cached1 = manager.getCachedTransformation(for: transform1.shortcutName)
        let cached2 = manager.getCachedTransformation(for: transform2.shortcutName)

        #expect(cached1?.systemPrompt == "Updated Prompt 1", "Transform 1 should be updated")
        #expect(cached2?.systemPrompt == "Prompt 2", "Transform 2 should be unchanged")

        manager.unregister(transformation: transform1)
        manager.unregister(transformation: transform2)
    }

    @Test("Disabled transformation can be updated after enabling")
    @MainActor
    func disabledTransformationCanBeUpdatedAfterEnabling() {
        let manager = HotkeyManager.shared

        let id = UUID()
        var transformation = TransformationConfig(
            id: id,
            name: "Initially Disabled",
            type: .llm,
            isEnabled: false, // Disabled - won't be registered
            systemPrompt: "Original"
        )

        // This won't register because it's disabled
        manager.register(transformation: transformation)

        // Enable and register
        transformation.isEnabled = true
        manager.setEnabled(true, for: transformation)

        // Update the prompt
        transformation.systemPrompt = "After Enable Update"
        manager.updateTransformation(transformation)

        let cached = manager.getCachedTransformation(for: transformation.shortcutName)
        #expect(cached?.systemPrompt == "After Enable Update", "Should have updated prompt after enabling")

        manager.unregister(transformation: transformation)
    }

    @Test("Format As Markdown uses stored prompt when falling back to configured provider")
    @MainActor
    func formatAsMarkdownUsesStoredPromptOnFallback() async throws {
        let suiteName = "format-as-markdown-fallback.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let storedPrompt = "User-custom markdown prompt"
        let storedTransformation = TransformationConfig(
            id: TransformationConfig.formatAsMarkdownDefaultID,
            name: "Format As Markdown",
            type: .llm,
            isEnabled: true,
            provider: "openai",
            model: "gpt-4o",
            systemPrompt: storedPrompt
        )
        let data = try JSONEncoder().encode([storedTransformation])
        defaults.set(data, forKey: SettingsKey.transformationsData)

        let client = RecordingLLMClient(provider: .openAI)
        let resolution = ModelResolver.Resolution(
            provider: .openAI,
            model: "gpt-4o",
            source: .transformationOverride
        )
        let factory = StubLLMFactory(
            client: client,
            resolution: resolution,
            allowDirectResolution: false // Force fallback path
        )

        let manager = HotkeyManager(userDefaults: defaults)
        manager.llmFactory = factory

        let pipeline = try #require(manager.createFormatAsMarkdownPipeline())
        let result = try await pipeline.execute("input")
        #expect(result.output == storedPrompt)

        let lastRequest = try #require(await client.lastRequest())
        #expect(lastRequest.systemPrompt == storedPrompt)
    }

    @Test("LLM pipeline uses provider default when model is empty")
    @MainActor
    func llmPipelineUsesProviderDefaultWhenModelEmpty() async throws {
        let suiteName = "hotkey-fallback-model.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let providerDefault = "provider-default-model"
        defaults.set(providerDefault, forKey: ModelResolver.providerModelKey(for: .openAI))

        let transformation = TransformationConfig(
            name: "LLM Transform",
            type: .llm,
            isEnabled: true,
            provider: "openai",
            model: nil,
            systemPrompt: "Prompt"
        )

        let client = RecordingLLMClient(provider: .openAI)
        let resolution = ModelResolver.Resolution(
            provider: .openAI,
            model: providerDefault,
            source: .providerDefault
        )
        let factory = StubLLMFactory(
            client: client,
            resolution: resolution,
            allowDirectResolution: true
        )

        let manager = HotkeyManager(userDefaults: defaults)
        manager.llmFactory = factory

        let pipeline = try #require(manager.createLLMPipeline(for: transformation))
        let result = try await pipeline.execute("input")
        #expect(result.output == transformation.systemPrompt)

        let lastRequest = try #require(await client.lastRequest())
        #expect(lastRequest.model == providerDefault)
    }
}

// MARK: - Test Doubles

private struct RecordingLLMClient: LLMProviderClient {
    let provider: LLMProviderKind
    private let recorder = RequestRecorder()

    func isConfigured() -> Bool { true }

    func transform(_ request: LLMRequest) async throws -> LLMResponse {
        await self.recorder.record(request)
        return LLMResponse(
            provider: self.provider,
            model: request.model,
            output: request.systemPrompt,
            duration: 0.01
        )
    }

    func lastRequest() async -> LLMRequest? {
        await self.recorder.lastRequest
    }
}

private actor RequestRecorder {
    private(set) var lastRequest: LLMRequest?

    func record(_ request: LLMRequest) {
        self.lastRequest = request
    }
}

private struct StubLLMFactory: LLMProviderClientBuilding {
    let client: any LLMProviderClient
    let resolution: ModelResolver.Resolution
    let allowDirectResolution: Bool

    func client(for provider: LLMProviderKind) throws -> (any LLMProviderClient)? {
        provider == self.resolution.provider ? self.client : nil
    }

    func client(
        for transformation: TransformationConfig,
        modelResolver: ModelResolver
    ) throws -> LLMProviderClientFactory.ClientResolution? {
        guard self.allowDirectResolution else { return nil }
        guard let resolved = modelResolver.resolveModel(for: transformation) else { return nil }
        guard resolved.provider == self.resolution.provider else { return nil }
        return LLMProviderClientFactory.ClientResolution(client: self.client, resolution: resolved)
    }

    func configuredClients() throws -> [LLMProviderKind: any LLMProviderClient] {
        [self.resolution.provider: self.client]
    }
}
