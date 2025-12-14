import SwiftUI

// MARK: - OpenAI Provider Section

/// Configuration section for OpenAI API credentials.
struct OpenAIProviderSection: View {
    @Binding var apiKey: String
    @Binding var validationState: ValidationState

    var body: some View {
        Section("OpenAI") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SecureField("API Key", text: self.$apiKey, prompt: Text("sk-..."))
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: self.apiKey) { _, _ in
                            self.validationState = .idle
                        }

                    ValidateButton(
                        state: self.validationState,
                        isDisabled: self.apiKey.isEmpty,
                        action: self.validateAPIKey
                    )
                }

                ValidationStatusView(state: self.validationState)

                ProviderHelpLink(provider: .openai)
            }
        }
    }

    private func validateAPIKey() {
        self.validationState = .validating

        Task {
            do {
                let result = try await OpenAIValidator.validateAPIKey(self.apiKey)
                await MainActor.run {
                    self.validationState = .success(message: result)
                }
            } catch {
                await MainActor.run {
                    self.validationState = .failure(error: error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Anthropic Provider Section

/// Configuration section for Anthropic API credentials.
struct AnthropicProviderSection: View {
    @Binding var apiKey: String
    @Binding var validationState: ValidationState

    var body: some View {
        Section("Anthropic") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SecureField("API Key", text: self.$apiKey, prompt: Text("sk-ant-..."))
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: self.apiKey) { _, _ in
                            self.validationState = .idle
                        }

                    ValidateButton(
                        state: self.validationState,
                        isDisabled: self.apiKey.isEmpty,
                        action: self.validateAPIKey
                    )
                }

                ValidationStatusView(state: self.validationState)

                ProviderHelpLink(provider: .anthropic)
            }
        }
    }

    private func validateAPIKey() {
        self.validationState = .validating

        Task {
            do {
                let result = try await AnthropicValidator.validateAPIKey(self.apiKey)
                await MainActor.run {
                    self.validationState = .success(message: result)
                }
            } catch {
                await MainActor.run {
                    self.validationState = .failure(error: error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - OpenRouter Provider Section

/// Configuration section for OpenRouter API credentials.
struct OpenRouterProviderSection: View {
    @Binding var apiKey: String
    @Binding var validationState: ValidationState

    var body: some View {
        Section("OpenRouter") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SecureField("API Key", text: self.$apiKey, prompt: Text("sk-or-..."))
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: self.apiKey) { _, _ in
                            self.validationState = .idle
                        }

                    ValidateButton(
                        state: self.validationState,
                        isDisabled: self.apiKey.isEmpty,
                        action: self.validateAPIKey
                    )
                }

                ValidationStatusView(state: self.validationState)

                Text("Access 100+ models through a unified API")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ProviderHelpLink(provider: .openRouter)
            }
        }
    }

    private func validateAPIKey() {
        self.validationState = .validating

        Task {
            do {
                let result = try await OpenRouterValidator.validateAPIKey(self.apiKey)
                await MainActor.run {
                    self.validationState = .success(message: result)
                }
            } catch {
                await MainActor.run {
                    self.validationState = .failure(error: error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Ollama Provider Section

/// Configuration section for Ollama local server.
struct OllamaProviderSection: View {
    @Binding var host: String
    @Binding var port: String
    @Binding var validationState: ValidationState

    var body: some View {
        Section("Ollama (Local)") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("Host", text: self.$host, prompt: Text("http://localhost"))
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: self.host) { _, _ in
                            self.validationState = .idle
                        }

                    TextField("Port", text: self.$port, prompt: Text("11434"))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .onChange(of: self.port) { _, _ in
                            self.validationState = .idle
                        }
                }

                HStack {
                    ValidateButton(
                        state: self.validationState,
                        isDisabled: self.host.isEmpty,
                        action: self.testConnection,
                        label: "Test Connection"
                    )

                    Spacer()
                }

                ValidationStatusView(state: self.validationState)

                Text("Run `ollama serve` to start the local server")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ProviderHelpLink(provider: .ollama, label: "Download Ollama")
            }
        }
    }

    func testConnection() {
        self.validationState = .validating

        Task {
            do {
                let result = try await OllamaValidator.testConnection(host: self.host, port: self.port)
                await MainActor.run {
                    self.validationState = .success(message: result)
                }
            } catch {
                await MainActor.run {
                    self.validationState = .failure(error: error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - AWS Bedrock Provider Section

/// Configuration section for AWS Bedrock credentials.
struct AWSBedrockProviderSection: View {
    @Binding var authMethod: AWSAuthMethod
    @Binding var profile: String
    @Binding var accessKey: String
    @Binding var secretKey: String
    @Binding var region: String
    @Binding var validationState: ValidationState

    private let awsRegions = [
        "us-east-1",
        "us-west-2",
        "eu-west-1",
        "eu-west-2",
        "eu-central-1",
        "ap-northeast-1",
        "ap-southeast-1",
        "ap-southeast-2"
    ]

    var body: some View {
        Section("AWS Bedrock") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Authentication", selection: self.$authMethod) {
                    ForEach(AWSAuthMethod.allCases) { method in
                        Text(method.displayName).tag(method)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: self.authMethod) { _, _ in
                    self.validationState = .idle
                }

                if self.authMethod == .profile {
                    self.profileAuthFields
                } else {
                    self.keysAuthFields
                }

                Picker("Region", selection: self.$region) {
                    ForEach(self.awsRegions, id: \.self) { region in
                        Text(region).tag(region)
                    }
                }
                .onChange(of: self.region) { _, _ in
                    self.validationState = .idle
                }

                HStack {
                    ValidateButton(
                        state: self.validationState,
                        isDisabled: self.isValidationDisabled,
                        action: self.validateCredentials
                    )

                    Spacer()
                }

                ValidationStatusView(state: self.validationState)

                ProviderHelpLink(provider: .awsBedrock, label: "AWS Bedrock Console")
            }
        }
    }

    @ViewBuilder
    private var profileAuthFields: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Profile Name", text: self.$profile, prompt: Text("default"))
                .textFieldStyle(.roundedBorder)
                .onChange(of: self.profile) { _, _ in
                    self.validationState = .idle
                }

            Text("Uses credentials from ~/.aws/credentials")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var keysAuthFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            SecureField("Access Key ID", text: self.$accessKey, prompt: Text("AKIA..."))
                .textFieldStyle(.roundedBorder)
                .onChange(of: self.accessKey) { _, _ in
                    self.validationState = .idle
                }

            SecureField("Secret Access Key", text: self.$secretKey, prompt: Text("..."))
                .textFieldStyle(.roundedBorder)
                .onChange(of: self.secretKey) { _, _ in
                    self.validationState = .idle
                }
        }
    }

    private var isValidationDisabled: Bool {
        if self.authMethod == .profile {
            self.profile.isEmpty
        } else {
            self.accessKey.isEmpty || self.secretKey.isEmpty
        }
    }

    private func validateCredentials() {
        self.validationState = .validating

        Task {
            do {
                let result: String = if self.authMethod == .profile {
                    try await BedrockValidator.validateProfile(self.profile, region: self.region)
                } else {
                    try await BedrockValidator.validateKeys(
                        accessKey: self.accessKey,
                        secretKey: self.secretKey,
                        region: self.region
                    )
                }
                await MainActor.run {
                    self.validationState = .success(message: result)
                }
            } catch {
                await MainActor.run {
                    self.validationState = .failure(error: error.localizedDescription)
                }
            }
        }
    }
}
