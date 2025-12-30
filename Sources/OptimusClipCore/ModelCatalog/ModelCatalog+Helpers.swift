import Foundation
import OptimusClipCore

extension ModelCatalog {
    // MARK: - Static / Fallback Lists

    func staticAnthropicModels() -> [LLMModel] {
        [
            LLMModel(id: "claude-3-opus-20240229", provider: .anthropic, contextLength: 200_000),
            LLMModel(id: "claude-3-sonnet-20240229", provider: .anthropic, contextLength: 200_000),
            LLMModel(id: "claude-3-haiku-20240307", provider: .anthropic, contextLength: 200_000),
            LLMModel(id: "claude-3-5-sonnet-20241022", provider: .anthropic, contextLength: 200_000)
        ]
    }

    func staticBedrockModels(region: String) -> [LLMModel] {
        let models = [
            LLMModel(id: "anthropic.claude-3-haiku-20240307-v1:0", provider: .awsBedrock, contextLength: 200_000),
            LLMModel(id: "anthropic.claude-3-sonnet-20240229-v1:0", provider: .awsBedrock, contextLength: 200_000),
            LLMModel(id: "anthropic.claude-3-opus-20240229-v1:0", provider: .awsBedrock, contextLength: 200_000),
            LLMModel(id: "anthropic.claude-3-5-sonnet-20241022-v2:0", provider: .awsBedrock, contextLength: 200_000),
            LLMModel(id: "meta.llama3-8b-instruct-v1:0", provider: .awsBedrock, contextLength: 8000)
        ]
        return models.map { model in
            LLMModel(
                id: model.id,
                name: "\(model.name) (\(region))",
                provider: model.provider,
                contextLength: model.contextLength,
                pricing: model.pricing,
                isDeprecated: model.isDeprecated
            )
        }
    }

    // MARK: - OpenRouter Helpers

    static func openRouterReferer() -> String {
        if let value = Bundle.main.object(forInfoDictionaryKey: "OpenRouterRefererURL") as? String,
           let normalized = normalizedURLString(value) {
            return normalized
        }
        return "https://optimusclip.app"
    }

    static func openRouterTitle() -> String {
        if let value = Bundle.main.object(forInfoDictionaryKey: "OpenRouterAppTitle") as? String,
           let normalized = normalizedTitle(value) {
            return normalized
        }
        if let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           let normalized = Self.normalizedTitle(displayName) {
            return normalized
        }
        if let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String,
           let normalized = Self.normalizedTitle(bundleName) {
            return normalized
        }
        return "Optimus Clip"
    }

    static func normalizedURLString(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()) else {
            return nil
        }
        return url.absoluteString
    }

    static func normalizedTitle(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
