import Foundation
import OptimusClipCore
import SwiftUI

/// Application-level cache for fetched LLM models.
///
/// Injected via SwiftUI environment. Cache lifetime is tied to
/// the settings window session - cleared when window closes.
@Observable
final class ModelCache {
    private var cache: [LLMProviderKind: [LLMModel]] = [:]

    /// Returns cached models for provider, or nil if not cached.
    func models(for provider: LLMProviderKind) -> [LLMModel]? {
        self.cache[provider]
    }

    /// Stores models in cache for provider.
    func setModels(_ models: [LLMModel], for provider: LLMProviderKind) {
        self.cache[provider] = models
    }

    /// Clears all cached models.
    func clear() {
        self.cache.removeAll()
    }
}

// MARK: - Environment Key

private struct ModelCacheKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: ModelCache = .init()
}

extension EnvironmentValues {
    var modelCache: ModelCache {
        get { self[ModelCacheKey.self] }
        set { self[ModelCacheKey.self] = newValue }
    }
}
