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
/// API keys are stored in @AppStorage (UserDefaults) for the MVP.
/// Phase 6 will migrate to Keychain for secure storage.
struct ProvidersTabView: View {
    // OpenAI configuration
    @AppStorage("openai_api_key") private var openAIKey = ""
    @AppStorage("openai_model_id") private var openAIModelId = "gpt-4o-mini"

    // Anthropic configuration
    @AppStorage("anthropic_api_key") private var anthropicKey = ""
    @AppStorage("anthropic_model_id") private var anthropicModelId = "claude-3-5-sonnet-20241022"

    // OpenRouter configuration
    @AppStorage("openrouter_api_key") private var openRouterKey = ""
    @AppStorage("openrouter_model_id") private var openRouterModelId = ""

    // Ollama configuration
    @AppStorage("ollama_host") private var ollamaHost = "http://localhost"
    @AppStorage("ollama_port") private var ollamaPort = "11434"
    @AppStorage("ollama_model_id") private var ollamaModelId = ""

    // AWS Bedrock configuration
    @AppStorage("aws_auth_method") private var awsAuthMethod = AWSAuthMethod.profile.rawValue
    @AppStorage("aws_profile") private var awsProfile = "default"
    @AppStorage("aws_access_key") private var awsAccessKey = ""
    @AppStorage("aws_secret_key") private var awsSecretKey = ""
    @AppStorage("aws_bearer_token") private var awsBearerToken = ""
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
    }
}

// MARK: - Preview

#Preview {
    ProvidersTabView()
        .frame(width: 450, height: 600)
}
