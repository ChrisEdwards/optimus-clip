import Foundation
import OptimusClipCore
import Testing

@Suite("ModelCatalog cache keys")
struct ModelCatalogCacheKeyTests {
    @Test("Cache key changes when API key changes")
    func cacheKeyIncludesApiKeyFingerprint() {
        let configA = ModelProviderConfig.openAI(apiKey: "sk-test-123")
        let configB = ModelProviderConfig.openAI(apiKey: "sk-rotated-456")

        #expect(configA.cacheKey != configB.cacheKey)
        #expect(configA.cacheKey.contains("key:"))
        #expect(!configA.cacheKey.contains("sk-test-123"))
    }

    @MainActor
    @Test("Cache entries are isolated by key fingerprint")
    func cacheEntriesAreIsolatedByKeyFingerprint() async throws {
        let suite = "ModelCatalogCacheKeyTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Failed to create isolated defaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let cache = ModelCache(userDefaults: defaults, storagePrefix: "test.model_cache.")
        let now = Date()

        let configA = ModelProviderConfig.openAI(apiKey: "sk-test-123")
        let configB = ModelProviderConfig.openAI(apiKey: "sk-rotated-456")

        let modelsA = [LLMModel(
            id: "gpt-a",
            provider: .openAI,
            contextLength: nil,
            pricing: nil,
            isDeprecated: false
        )]

        await cache.save(models: modelsA, key: configA.cacheKey, fetchedAt: now, expiresAt: now.addingTimeInterval(60))

        let freshA = await cache.loadFresh(key: configA.cacheKey, now: now)
        let freshB = await cache.loadFresh(key: configB.cacheKey, now: now)

        #expect(freshA?.count == 1)
        #expect(freshB == nil)
    }
}
