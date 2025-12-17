import SwiftUI

// MARK: - Providers Tab View

/// Providers settings tab for configuring LLM API credentials.
///
/// Displays configuration sections for each supported provider:
/// - **OpenAI**: API key for GPT models
/// - **Anthropic**: API key for Claude models
/// - **OpenRouter**: API key for aggregated models
/// - **Ollama**: Host and port for local models
/// - **AWS Bedrock**: Profile or access keys with region
///
/// API keys are stored in the system Keychain (Phase 6 requirement).
///
/// ## Visual Hierarchy
/// - Summary header shows configuration status at a glance
/// - Configured providers are expanded by default
/// - Unconfigured providers are collapsed with "Click to configure" prompt
struct ProvidersTabView: View {
    private let apiKeyStore = APIKeyStore()

    // OpenAI configuration
    @State private var openAIKey = ""
    @AppStorage("openai_model_id") private var openAIModelId = "gpt-4o-mini"

    // Anthropic configuration
    @State private var anthropicKey = ""
    @AppStorage("anthropic_model_id") private var anthropicModelId = "claude-3-5-sonnet-20241022"

    // OpenRouter configuration
    @State private var openRouterKey = ""
    @AppStorage("openrouter_model_id") private var openRouterModelId = ""

    // Ollama configuration
    @AppStorage("ollama_host") private var ollamaHost = "http://localhost"
    @AppStorage("ollama_port") private var ollamaPort = "11434"
    @AppStorage("ollama_model_id") private var ollamaModelId = ""

    // AWS Bedrock configuration
    @AppStorage("aws_auth_method") private var awsAuthMethod = AWSAuthMethod.profile.rawValue
    @AppStorage("aws_profile") private var awsProfile = "default"
    @State private var awsAccessKey = ""
    @State private var awsSecretKey = ""
    @State private var awsBearerToken = ""
    @AppStorage("aws_region") private var awsRegion = "us-east-1"
    @AppStorage("aws_model_id") private var awsModelId = "anthropic.claude-3-haiku-20240307-v1:0"

    // Validation states
    @State private var openAIValidation: ValidationState = .idle
    @State private var anthropicValidation: ValidationState = .idle
    @State private var openRouterValidation: ValidationState = .idle
    @State private var ollamaValidation: ValidationState = .idle
    @State private var bedrockValidation: ValidationState = .idle

    // Expansion states for disclosure groups
    @State private var isOpenAIExpanded = false
    @State private var isAnthropicExpanded = false
    @State private var isOpenRouterExpanded = false
    @State private var isOllamaExpanded = false
    @State private var isBedrockExpanded = false

    // MARK: - Configuration Status

    private var isOpenAIConfigured: Bool { !self.openAIKey.isEmpty }
    private var isAnthropicConfigured: Bool { !self.anthropicKey.isEmpty }
    private var isOpenRouterConfigured: Bool { !self.openRouterKey.isEmpty }
    private var isOllamaConfigured: Bool { !self.ollamaHost.isEmpty && self.ollamaHost != "http://localhost" }
    private var isBedrockConfigured: Bool {
        let method = AWSAuthMethod(rawValue: self.awsAuthMethod) ?? .profile
        return switch method {
        case .profile: !self.awsProfile.isEmpty
        case .keys: !self.awsAccessKey.isEmpty && !self.awsSecretKey.isEmpty
        case .bearerToken: !self.awsBearerToken.isEmpty
        }
    }

    private var configuredCount: Int {
        [
            self.isOpenAIConfigured,
            self.isAnthropicConfigured,
            self.isOpenRouterConfigured,
            self.isOllamaConfigured,
            self.isBedrockConfigured
        ].count(where: { $0 })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Summary header
                ProviderSummaryHeader(
                    configuredCount: self.configuredCount,
                    isOpenAIConfigured: self.isOpenAIConfigured,
                    isAnthropicConfigured: self.isAnthropicConfigured,
                    isOpenRouterConfigured: self.isOpenRouterConfigured,
                    isOllamaConfigured: self.isOllamaConfigured,
                    isBedrockConfigured: self.isBedrockConfigured
                )
                .padding(.horizontal)
                .padding(.top, 8)

                Form {
                    // OpenAI
                    DisclosureGroup(isExpanded: self.$isOpenAIExpanded) {
                        OpenAIProviderSection(
                            apiKey: self.$openAIKey,
                            modelId: self.$openAIModelId,
                            validationState: self.$openAIValidation
                        )
                    } label: {
                        ProviderHeaderLabel(
                            name: "OpenAI",
                            isConfigured: self.isOpenAIConfigured
                        )
                    }

                    // Anthropic
                    DisclosureGroup(isExpanded: self.$isAnthropicExpanded) {
                        AnthropicProviderSection(
                            apiKey: self.$anthropicKey,
                            modelId: self.$anthropicModelId,
                            validationState: self.$anthropicValidation
                        )
                    } label: {
                        ProviderHeaderLabel(
                            name: "Anthropic",
                            isConfigured: self.isAnthropicConfigured
                        )
                    }

                    // OpenRouter
                    DisclosureGroup(isExpanded: self.$isOpenRouterExpanded) {
                        OpenRouterProviderSection(
                            apiKey: self.$openRouterKey,
                            modelId: self.$openRouterModelId,
                            validationState: self.$openRouterValidation
                        )
                    } label: {
                        ProviderHeaderLabel(
                            name: "OpenRouter",
                            isConfigured: self.isOpenRouterConfigured
                        )
                    }

                    // Ollama
                    DisclosureGroup(isExpanded: self.$isOllamaExpanded) {
                        OllamaProviderSection(
                            host: self.$ollamaHost,
                            port: self.$ollamaPort,
                            modelId: self.$ollamaModelId,
                            validationState: self.$ollamaValidation
                        )
                    } label: {
                        ProviderHeaderLabel(
                            name: "Ollama (Local)",
                            isConfigured: self.isOllamaConfigured
                        )
                    }

                    // AWS Bedrock
                    DisclosureGroup(isExpanded: self.$isBedrockExpanded) {
                        AWSBedrockProviderSection(
                            authMethod: Binding(
                                get: { AWSAuthMethod(rawValue: self.awsAuthMethod) ?? .profile },
                                set: { self.awsAuthMethod = $0.rawValue }
                            ),
                            profile: self.$awsProfile,
                            accessKey: self.$awsAccessKey,
                            secretKey: self.$awsSecretKey,
                            bearerToken: self.$awsBearerToken,
                            region: self.$awsRegion,
                            modelId: self.$awsModelId,
                            validationState: self.$bedrockValidation
                        )
                    } label: {
                        ProviderHeaderLabel(
                            name: "AWS Bedrock",
                            isConfigured: self.isBedrockConfigured
                        )
                    }
                }
                .formStyle(.grouped)
                .padding()
            }
        }
        .task {
            self.loadKeysFromKeychain()
            self.initializeExpansionState()
        }
        .onChange(of: self.openAIKey) { _, newValue in
            self.persistOpenAIKey(newValue)
        }
        .onChange(of: self.anthropicKey) { _, newValue in
            self.persistAnthropicKey(newValue)
        }
        .onChange(of: self.openRouterKey) { _, newValue in
            self.persistOpenRouterKey(newValue)
        }
        .onChange(of: self.awsAccessKey) { _, newValue in
            self.persistAWSAccessKey(newValue)
        }
        .onChange(of: self.awsSecretKey) { _, newValue in
            self.persistAWSSecretKey(newValue)
        }
        .onChange(of: self.awsBearerToken) { _, newValue in
            self.persistAWSBearerToken(newValue)
        }
    }

    /// Set initial expansion state based on configuration status.
    private func initializeExpansionState() {
        // Expand configured providers, collapse unconfigured
        self.isOpenAIExpanded = self.isOpenAIConfigured
        self.isAnthropicExpanded = self.isAnthropicConfigured
        self.isOpenRouterExpanded = self.isOpenRouterConfigured
        self.isOllamaExpanded = self.isOllamaConfigured
        self.isBedrockExpanded = self.isBedrockConfigured

        // If none configured, expand OpenAI as the default
        if self.configuredCount == 0 {
            self.isOpenAIExpanded = true
        }
    }
}

// MARK: - Provider Summary Header

/// Summary header showing overall configuration status.
private struct ProviderSummaryHeader: View {
    let configuredCount: Int
    let isOpenAIConfigured: Bool
    let isAnthropicConfigured: Bool
    let isOpenRouterConfigured: Bool
    let isOllamaConfigured: Bool
    let isBedrockConfigured: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("LLM Providers")
                    .font(.headline)
                Spacer()
                Text("\(self.configuredCount) of 5 configured")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                ProviderStatusBadge(name: "OpenAI", isConfigured: self.isOpenAIConfigured)
                ProviderStatusBadge(name: "Anthropic", isConfigured: self.isAnthropicConfigured)
                ProviderStatusBadge(name: "OpenRouter", isConfigured: self.isOpenRouterConfigured)
                ProviderStatusBadge(name: "Ollama", isConfigured: self.isOllamaConfigured)
                ProviderStatusBadge(name: "Bedrock", isConfigured: self.isBedrockConfigured)
            }
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Small badge showing provider configuration status.
private struct ProviderStatusBadge: View {
    let name: String
    let isConfigured: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: self.isConfigured ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundStyle(self.isConfigured ? .green : .secondary)
            Text(self.name)
                .font(.caption)
                .foregroundStyle(self.isConfigured ? .primary : .secondary)
        }
    }
}

// MARK: - Provider Header Label

/// Label for disclosure group showing provider name and configuration status.
private struct ProviderHeaderLabel: View {
    let name: String
    let isConfigured: Bool

    var body: some View {
        HStack {
            Text(self.name)
                .font(.headline)

            Spacer()

            if self.isConfigured {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Configured")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Click to configure")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ProvidersTabView()
        .frame(width: 450, height: 600)
}

// MARK: - Keychain Helpers

@MainActor
extension ProvidersTabView {
    private func loadKeysFromKeychain() {
        self.openAIKey = (try? self.apiKeyStore.loadOpenAIKey()) ?? ""
        self.anthropicKey = (try? self.apiKeyStore.loadAnthropicKey()) ?? ""
        self.openRouterKey = (try? self.apiKeyStore.loadOpenRouterKey()) ?? ""
        self.awsAccessKey = (try? self.apiKeyStore.loadAWSAccessKey()) ?? ""
        self.awsSecretKey = (try? self.apiKeyStore.loadAWSSecretKey()) ?? ""
        self.awsBearerToken = (try? self.apiKeyStore.loadAWSBearerToken()) ?? ""
    }

    private func persistOpenAIKey(_ key: String) {
        do {
            try self.apiKeyStore.saveOpenAIKey(key)
        } catch {
            self.openAIValidation = .failure(error: error.localizedDescription)
        }
    }

    private func persistAnthropicKey(_ key: String) {
        do {
            try self.apiKeyStore.saveAnthropicKey(key)
        } catch {
            self.anthropicValidation = .failure(error: error.localizedDescription)
        }
    }

    private func persistOpenRouterKey(_ key: String) {
        do {
            try self.apiKeyStore.saveOpenRouterKey(key)
        } catch {
            self.openRouterValidation = .failure(error: error.localizedDescription)
        }
    }

    private func persistAWSAccessKey(_ key: String) {
        do {
            try self.apiKeyStore.saveAWSAccessKey(key)
        } catch {
            self.bedrockValidation = .failure(error: error.localizedDescription)
        }
    }

    private func persistAWSSecretKey(_ key: String) {
        do {
            try self.apiKeyStore.saveAWSSecretKey(key)
        } catch {
            self.bedrockValidation = .failure(error: error.localizedDescription)
        }
    }

    private func persistAWSBearerToken(_ token: String) {
        do {
            try self.apiKeyStore.saveAWSBearerToken(token)
        } catch {
            self.bedrockValidation = .failure(error: error.localizedDescription)
        }
    }
}
