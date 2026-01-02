import Foundation
import OptimusClipCore
import Testing
@testable import OptimusClip

/// Tests for the model selector combobox binding logic.
///
/// The binding distinguishes between:
/// - "Default (model)" → `model = nil` (follows provider default)
/// - Explicit model → `model = "model-id"` (pinned)
@Suite("ModelSelectorBinding")
struct ModelSelectorBindingTests {
    // MARK: - Binding Set Logic

    @Test("selecting Default sets model to nil")
    func selectingDefaultSetsNil() {
        var config = TransformationConfig(
            name: "Test",
            isEnabled: true,
            provider: "openai",
            model: "gpt-4o",
            systemPrompt: "test"
        )

        // Simulate selecting "Default (gpt-4o-mini)"
        let selection = "Default (gpt-4o-mini)"
        if selection.hasPrefix("Default") {
            config.model = nil
        } else {
            config.model = selection
        }

        #expect(config.model == nil)
    }

    @Test("selecting explicit model sets that model")
    func selectingExplicitModelSetsModel() {
        var config = TransformationConfig(
            name: "Test",
            isEnabled: true,
            provider: "openai",
            model: nil,
            systemPrompt: "test"
        )

        // Simulate selecting "gpt-4-turbo"
        let selection = "gpt-4-turbo"
        if selection.hasPrefix("Default") {
            config.model = nil
        } else {
            config.model = selection
        }

        #expect(config.model == "gpt-4-turbo")
    }

    @Test("custom typed model becomes pinned selection")
    func customTypedModelBecomesPinned() {
        var config = TransformationConfig(
            name: "Test",
            isEnabled: true,
            provider: "openai",
            model: nil,
            systemPrompt: "test"
        )

        // User types a custom model not in the list
        let selection = "my-custom-model"
        if selection.hasPrefix("Default") {
            config.model = nil
        } else {
            config.model = selection
        }

        #expect(config.model == "my-custom-model")
    }

    // MARK: - Binding Get Logic

    @Test("nil model displays as Default option")
    func nilDisplaysAsDefault() {
        let context = self.makeResolver()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        let config = TransformationConfig(
            name: "Test",
            isEnabled: true,
            provider: "openai",
            model: nil,
            systemPrompt: "test"
        )

        // Simulate the binding get logic
        let resolvedDefault = context.resolver.resolveModel(for: config)?.model ?? "default"
        let displayValue: String = if let model = config.model {
            model
        } else {
            "Default (\(resolvedDefault))"
        }

        #expect(displayValue.hasPrefix("Default"))
        #expect(displayValue.contains("gpt-4o-mini"))
    }

    @Test("explicit model displays as-is")
    func explicitDisplaysAsIs() {
        let config = TransformationConfig(
            name: "Test",
            isEnabled: true,
            provider: "openai",
            model: "gpt-4-turbo",
            systemPrompt: "test"
        )

        // Simulate the binding get logic
        let displayValue: String = if let model = config.model {
            model
        } else {
            "Default (fallback)"
        }

        #expect(displayValue == "gpt-4-turbo")
    }

    // MARK: - Items Array Logic

    @Test("items array starts with Default option")
    func itemsStartWithDefault() {
        let context = self.makeResolver()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        let config = TransformationConfig(
            name: "Test",
            isEnabled: true,
            provider: "openai",
            model: nil,
            systemPrompt: "test"
        )

        let availableModels: [LLMModel] = [
            LLMModel(id: "gpt-4o", provider: .openAI),
            LLMModel(id: "gpt-4-turbo", provider: .openAI)
        ]

        // Simulate the items array logic
        var items: [String] = []
        let resolvedDefault = context.resolver.resolveModel(for: config)?.model ?? "default"
        items.append("Default (\(resolvedDefault))")
        for model in availableModels where model.id != resolvedDefault {
            items.append(model.id)
        }

        #expect(items.first?.hasPrefix("Default") == true)
        #expect(items.contains("gpt-4o"))
        #expect(items.contains("gpt-4-turbo"))
    }

    @Test("items array excludes resolved default from fetched list")
    func itemsExcludeResolvedDefault() {
        let context = self.makeResolver()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        let config = TransformationConfig(
            name: "Test",
            isEnabled: true,
            provider: "openai",
            model: nil,
            systemPrompt: "test"
        )

        // gpt-4o-mini is the fallback default for OpenAI
        let availableModels: [LLMModel] = [
            LLMModel(id: "gpt-4o-mini", provider: .openAI),
            LLMModel(id: "gpt-4-turbo", provider: .openAI)
        ]

        // Simulate the items array logic
        var items: [String] = []
        let resolvedDefault = context.resolver.resolveModel(for: config)?.model ?? "default"
        items.append("Default (\(resolvedDefault))")
        for model in availableModels where model.id != resolvedDefault {
            items.append(model.id)
        }

        // Default shows as "Default (gpt-4o-mini)"
        #expect(items.first == "Default (gpt-4o-mini)")
        // gpt-4o-mini should NOT appear as a separate item (it's the default)
        #expect(!items.contains("gpt-4o-mini"))
        // gpt-4-turbo should appear as explicit option
        #expect(items.contains("gpt-4-turbo"))
    }

    // MARK: - Provider Change Logic

    @Test("provider change updates default display")
    func providerChangeUpdatesDefault() {
        let context = self.makeResolver()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        var config = TransformationConfig(
            name: "Test",
            isEnabled: true,
            provider: "openai",
            model: nil,
            systemPrompt: "test"
        )

        // OpenAI default
        let openAIDefault = context.resolver.resolveModel(for: config)?.model
        #expect(openAIDefault == "gpt-4o-mini")

        // Switch to Anthropic
        config.provider = "anthropic"
        let anthropicDefault = context.resolver.resolveModel(for: config)?.model
        #expect(anthropicDefault == "claude-3-5-sonnet-20241022")
    }

    @Test("provider change preserves pinned model")
    func providerChangePreservesPinnedModel() {
        var config = TransformationConfig(
            name: "Test",
            isEnabled: true,
            provider: "openai",
            model: "gpt-4o",
            systemPrompt: "test"
        )

        // Switch to Anthropic - pinned model is preserved
        config.provider = "anthropic"

        // Model stays pinned (user explicitly selected it)
        #expect(config.model == "gpt-4o")
    }

    // MARK: - Helpers

    private struct ResolverContext {
        let resolver: ModelResolver
        let defaults: UserDefaults
        let suiteName: String
    }

    private func makeResolver(
        setup: (UserDefaults) -> Void = { _ in }
    ) -> ResolverContext {
        let suiteName = "ModelSelectorBindingTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create UserDefaults suite")
            return ResolverContext(resolver: ModelResolver(), defaults: .standard, suiteName: suiteName)
        }
        defaults.removePersistentDomain(forName: suiteName)
        setup(defaults)
        return ResolverContext(
            resolver: ModelResolver(userDefaults: defaults),
            defaults: defaults,
            suiteName: suiteName
        )
    }
}
