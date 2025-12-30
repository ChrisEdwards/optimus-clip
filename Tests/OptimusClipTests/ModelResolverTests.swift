import Foundation
import OptimusClipCore
import Testing
@testable import OptimusClip

@Suite("ModelResolver")
struct ModelResolverTests {
    @Test("prefers transformation override when present")
    func prefersOverride() {
        let context = self.makeResolver()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        var transformation = TransformationConfig(
            name: "LLM Override",
            type: .llm,
            isEnabled: true,
            provider: "openai",
            model: "custom-model",
            systemPrompt: "prompt"
        )

        let resolution = context.resolver.resolveModel(for: transformation)
        #expect(resolution?.provider == .openAI)
        #expect(resolution?.model == "custom-model")
        #expect(resolution?.source == .transformationOverride)

        // Ensure whitespace is trimmed
        transformation.model = "  trimmed-model  "
        let trimmed = context.resolver.resolveModel(for: transformation)
        #expect(trimmed?.model == "trimmed-model")
    }

    @Test("uses provider default when override missing")
    func usesProviderDefault() {
        let context = self.makeResolver { defaults in
            let key = ModelResolver.providerModelKey(for: .anthropic)
            defaults.set("stored-model", forKey: key)
        }
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        let transformation = TransformationConfig(
            name: "LLM No Override",
            type: .llm,
            isEnabled: true,
            provider: "anthropic",
            model: nil,
            systemPrompt: "prompt"
        )

        let resolution = context.resolver.resolveModel(for: transformation)
        #expect(resolution?.provider == .anthropic)
        #expect(resolution?.model == "stored-model")
        #expect(resolution?.source == .providerDefault)
    }

    @Test("falls back to default when provider default missing or empty")
    func fallsBackToDefault() {
        let context = self.makeResolver { defaults in
            let key = ModelResolver.providerModelKey(for: .openRouter)
            defaults.set("", forKey: key) // Should be treated as absent
        }
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        let transformation = TransformationConfig(
            name: "LLM Fallback",
            type: .llm,
            isEnabled: true,
            provider: "openrouter",
            model: nil,
            systemPrompt: "prompt"
        )

        let resolution = context.resolver.resolveModel(for: transformation)
        #expect(resolution?.provider == .openRouter)
        #expect(resolution?.model == "openrouter/anthropic/claude-3.5-sonnet")
        #expect(resolution?.source == .fallbackDefault)
    }

    @Test("returns nil for unknown provider")
    func unknownProvider() {
        let context = self.makeResolver()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        let transformation = TransformationConfig(
            name: "Bad Provider",
            type: .llm,
            isEnabled: true,
            provider: "azure",
            model: nil,
            systemPrompt: "prompt"
        )

        let resolution = context.resolver.resolveModel(for: transformation)
        #expect(resolution == nil)
    }

    @Test("handles case-insensitive provider strings")
    func caseInsensitiveProviderLookup() {
        let context = self.makeResolver()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        let transformation = TransformationConfig(
            name: "Upper Provider",
            type: .llm,
            isEnabled: true,
            provider: "OpenAI",
            model: nil,
            systemPrompt: "prompt"
        )

        let resolution = context.resolver.resolveModel(for: transformation)
        #expect(resolution?.provider == .openAI)
        #expect(resolution?.model == "gpt-4o-mini")
        #expect(resolution?.source == .fallbackDefault)
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
        let suiteName = "ModelResolverTests-\(UUID().uuidString)"
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
