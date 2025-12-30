import Foundation
import OptimusClipCore
import Testing
@testable import OptimusClip

@Suite("ModelResolver defaults")
struct ModelResolverDefaultsTests {
    @Test("OpenRouter fallback matches catalog id format")
    func openRouterFallbackIsValid() {
        let fallback = ModelResolver.fallbackModel(for: .openRouter)
        #expect(fallback == "openrouter/anthropic/claude-3.5-sonnet")
    }

    @MainActor
    @Test("Provider default resolves when no override is set")
    func providerDefaultResolutionUsesFallback() throws {
        let suite = "ModelResolverDefaultsTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Failed to create isolated defaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let resolver = ModelResolver(userDefaults: defaults)
        let config = TransformationConfig(
            id: UUID(),
            name: "Test",
            type: .llm,
            provider: LLMProviderKind.openRouter.rawValue,
            model: nil
        )

        let resolution = resolver.resolveModel(for: config)
        #expect(resolution?.source == .fallbackDefault)
        #expect(resolution?.model == "openrouter/anthropic/claude-3.5-sonnet")
    }
}
