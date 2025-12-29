import Foundation
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
}
