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

    var body: some View {
        ScrollView {
            Form {
                OpenAIProviderSection(
                    apiKey: self.$openAIKey,
                    modelId: self.$openAIModelId,
                    validationState: self.$openAIValidation
                )

                AnthropicProviderSection(
                    apiKey: self.$anthropicKey,
                    modelId: self.$anthropicModelId,
                    validationState: self.$anthropicValidation
                )

                OpenRouterProviderSection(
                    apiKey: self.$openRouterKey,
                    modelId: self.$openRouterModelId,
                    validationState: self.$openRouterValidation
                )

                OllamaProviderSection(
                    host: self.$ollamaHost,
                    port: self.$ollamaPort,
                    modelId: self.$ollamaModelId,
                    validationState: self.$ollamaValidation
                )

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
            }
            .formStyle(.grouped)
            .padding()
        }
        .task {
            self.loadKeysFromKeychain()
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
