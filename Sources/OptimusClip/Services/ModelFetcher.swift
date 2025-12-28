import Foundation
import OptimusClipCore

/// Fetches available models for LLM providers.
///
/// Used by TransformationEditorView to populate the model selection combobox.
struct ModelFetcher {
    private let providerFactory: LLMProviderClientFactory

    init(providerFactory: LLMProviderClientFactory = LLMProviderClientFactory()) {
        self.providerFactory = providerFactory
    }

    /// Checks if models can be fetched for the given provider.
    ///
    /// - Parameter provider: The provider kind to check.
    /// - Returns: `true` if the provider is configured with valid credentials.
    func canFetch(for provider: LLMProviderKind?) -> Bool {
        guard let provider else { return false }
        return (try? self.providerFactory.isConfigured(provider)) ?? false
    }

    /// Fetches available models for the given provider.
    ///
    /// - Parameter provider: The provider to fetch models for.
    /// - Returns: Array of available models, or empty array on failure.
    func fetchModels(for provider: LLMProviderKind) async -> [LLMModel] {
        do {
            guard let config = try self.providerFactory.modelProviderConfig(for: provider) else {
                return []
            }
            let catalog = ModelCatalog()
            return try await catalog.models(for: config)
        } catch {
            return []
        }
    }
}
