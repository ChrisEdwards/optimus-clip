import Foundation
import OptimusClipCore

/// Resolves the effective model for an LLM transformation using a clear hierarchy:
/// 1) Transformation override (`TransformationConfig.model`)
/// 2) Provider default stored in UserDefaults (per provider key)
/// 3) Fallback default for the provider
///
/// This keeps model selection consistent across hotkeys, menu actions, and tests.
///
/// ## Sendable Justification
/// Marked `@unchecked Sendable` because:
/// - `UserDefaults` is documented as thread-safe by Apple
/// - All stored properties are immutable after initialization
/// - Only performs read-only access to UserDefaults
struct ModelResolver: @unchecked Sendable {
    enum Source: String, Sendable {
        case transformationOverride
        case providerDefault
        case fallbackDefault
    }

    struct Resolution: Sendable {
        let provider: LLMProviderKind
        let model: String
        let source: Source
    }

    /// Backed by UserDefaults; access is read-only and synchronous in this context.
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// Returns the chosen model for a transformation, or nil when the provider is missing/unknown.
    func resolveModel(for transformation: TransformationConfig) -> Resolution? {
        guard let providerKind = self.providerKind(for: transformation.provider) else {
            return nil
        }

        if let override = self.cleaned(transformation.model) {
            return Resolution(provider: providerKind, model: override, source: .transformationOverride)
        }

        if let providerDefault = self.providerDefault(for: providerKind) {
            return Resolution(provider: providerKind, model: providerDefault, source: .providerDefault)
        }

        guard let fallback = Self.fallbackModel(for: providerKind) else {
            return nil
        }

        return Resolution(provider: providerKind, model: fallback, source: .fallbackDefault)
    }

    // MARK: - Helpers

    private func providerDefault(for provider: LLMProviderKind) -> String? {
        let key = Self.providerModelKey(for: provider)
        guard let rawValue = self.userDefaults.string(forKey: key) else {
            return nil
        }
        return self.cleaned(rawValue)
    }

    private func providerKind(for providerString: String?) -> LLMProviderKind? {
        guard let providerString else {
            return nil
        }

        if let direct = LLMProviderKind(rawValue: providerString) {
            return direct
        }

        switch providerString.lowercased() {
        case "openai":
            return .openAI
        case "anthropic":
            return .anthropic
        case "openrouter":
            return .openRouter
        case "ollama":
            return .ollama
        case "awsbedrock", "aws", "bedrock":
            return .awsBedrock
        default:
            return nil
        }
    }

    private func cleaned(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), value.isEmpty == false else {
            return nil
        }
        return value
    }
}

// MARK: - Defaults

extension ModelResolver {
    static func providerModelKey(for provider: LLMProviderKind) -> String {
        switch provider {
        case .openAI:
            "openai_model_id"
        case .anthropic:
            "anthropic_model_id"
        case .openRouter:
            "openrouter_model_id"
        case .ollama:
            "ollama_model_id"
        case .awsBedrock:
            "aws_model_id"
        }
    }

    static func fallbackModel(for provider: LLMProviderKind) -> String? {
        switch provider {
        case .openAI:
            "gpt-4o-mini"
        case .anthropic:
            "claude-3-5-sonnet-20241022"
        case .openRouter:
            "openrouter/anthropic/claude-3.5-sonnet"
        case .ollama:
            "llama3.1"
        case .awsBedrock:
            "anthropic.claude-3-haiku-20240307-v1:0"
        }
    }
}
