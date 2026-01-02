import Foundation
import OptimusClipCore

/// Handles test execution for transformations in the editor.
///
/// Extracts test logic from TransformationEditorView to keep the view focused on UI.
struct TransformationTester {
    private let modelResolver: ModelResolver
    private let providerFactory: LLMProviderClientFactory
    private let userDefaults: UserDefaults

    init(
        modelResolver: ModelResolver = ModelResolver(),
        providerFactory: LLMProviderClientFactory = LLMProviderClientFactory(),
        userDefaults: UserDefaults = .standard
    ) {
        self.modelResolver = modelResolver
        self.providerFactory = providerFactory
        self.userDefaults = userDefaults
    }

    /// Runs a transformation test and returns the result.
    ///
    /// - Parameters:
    ///   - transformation: The transformation configuration to test.
    ///   - input: The input text to transform.
    /// - Returns: The transformed output.
    /// - Throws: `TransformationTestError` if the test fails.
    func runTest(transformation: TransformationConfig, input: String) async throws -> String {
        try await self.runLLMTest(transformation: transformation, input: input)
    }

    // MARK: - Private

    private func runLLMTest(transformation: TransformationConfig, input: String) async throws -> String {
        guard let providerName = transformation.provider, !providerName.isEmpty else {
            throw TransformationTestError.noProviderConfigured
        }

        guard let resolution = self.modelResolver.resolveModel(for: transformation) else {
            throw TransformationTestError.providerNotConfigured(
                Self.providerDisplayName(forRawValue: providerName)
            )
        }

        guard let client = try self.providerFactory.client(for: resolution.provider),
              client.isConfigured() else {
            throw TransformationTestError.providerNotConfigured(resolution.provider.displayName)
        }

        let timeoutSeconds = self.userDefaults.double(forKey: SettingsKey.transformationTimeout)
        let effectiveTimeout = timeoutSeconds > 0 ? timeoutSeconds : DefaultSettings.transformationTimeout

        let llmTransformation = LLMTransformation(
            id: "test-\(transformation.id.uuidString)",
            displayName: transformation.name,
            providerClient: client,
            model: resolution.model,
            systemPrompt: transformation.systemPrompt,
            timeoutSeconds: effectiveTimeout
        )

        return try await llmTransformation.transform(input)
    }

    // MARK: - Display Name Helpers

    static func providerDisplayName(forRawValue rawValue: String) -> String {
        LLMProviderKind.displayName(forRawValue: rawValue)
    }
}

// MARK: - Errors

/// Errors that can occur during transformation testing.
enum TransformationTestError: LocalizedError, Equatable {
    case noProviderConfigured
    case providerNotConfigured(String)

    var errorDescription: String? {
        switch self {
        case .noProviderConfigured:
            "No LLM provider selected"
        case let .providerNotConfigured(name):
            "\(name) is not configured"
        }
    }
}
