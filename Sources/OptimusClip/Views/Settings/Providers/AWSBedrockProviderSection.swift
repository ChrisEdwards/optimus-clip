import OptimusClipCore
import SwiftUI

// MARK: - AWS Bedrock Provider Section

/// Configuration section for AWS Bedrock credentials.
struct AWSBedrockProviderSection: View {
    @Binding var authMethod: AWSAuthMethod
    @Binding var profile: String
    @Binding var accessKey: String
    @Binding var secretKey: String
    @Binding var bearerToken: String
    @Binding var region: String
    @Binding var modelId: String
    @Binding var validationState: ValidationState

    @Environment(\.modelCache) private var modelCache
    @State private var isLoadingModels = false

    private var availableModels: [LLMModel] {
        self.modelCache.models(for: .awsBedrock) ?? []
    }

    // All AWS regions where Bedrock is available
    private let awsRegions = [
        // US regions
        "us-east-1",
        "us-east-2",
        "us-west-1",
        "us-west-2",
        // Europe regions
        "eu-central-1",
        "eu-west-1",
        "eu-west-2",
        "eu-west-3",
        "eu-north-1",
        // Asia Pacific regions
        "ap-south-1",
        "ap-southeast-1",
        "ap-southeast-2",
        "ap-northeast-1",
        "ap-northeast-2",
        "ap-northeast-3",
        // South America
        "sa-east-1",
        // Canada
        "ca-central-1",
        // Middle East
        "me-south-1",
        "me-central-1",
        // Africa
        "af-south-1"
    ]

    var body: some View {
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

            switch self.authMethod {
            case .profile:
                self.profileAuthFields
            case .keys:
                self.keysAuthFields
            case .bearerToken:
                self.bearerTokenAuthFields
            }

            Picker("Region", selection: self.$region) {
                ForEach(self.awsRegions, id: \.self) { region in
                    Text(region).tag(region)
                }
            }
            .onChange(of: self.region) { _, _ in
                self.validationState = .idle
            }

            // Model selection with native combobox
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Model")
                        .frame(width: 60, alignment: .leading)

                    ComboBox(
                        text: self.$modelId,
                        items: self.availableModels.map(\.id),
                        placeholder: "anthropic.claude-3-..."
                    )
                    .frame(height: 24)
                    .onChange(of: self.modelId) { _, _ in
                        self.validationState = .idle
                    }

                    Button(action: self.fetchModels) {
                        if self.isLoadingModels {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Fetch")
                        }
                    }
                    .disabled(self.isLoadingModels || !self.canFetchModels)
                }

                if self.availableModels.isEmpty {
                    Text("Click Fetch to load available models, or type a model ID directly")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(self.availableModels.count) models available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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
            // Warning: SigV4 signing is not yet implemented
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Access Key auth requires SigV4 signing which is not yet implemented")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(6)

            SecureField("Access Key ID", text: self.$accessKey, prompt: Text("AKIA..."))
                .textFieldStyle(.roundedBorder)
                .disabled(true) // Disabled until SigV4 is implemented
                .onChange(of: self.accessKey) { _, _ in
                    self.validationState = .idle
                }

            SecureField("Secret Access Key", text: self.$secretKey, prompt: Text("..."))
                .textFieldStyle(.roundedBorder)
                .disabled(true) // Disabled until SigV4 is implemented
                .onChange(of: self.secretKey) { _, _ in
                    self.validationState = .idle
                }

            Text("Use Bearer Token or AWS Profile authentication instead")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var bearerTokenAuthFields: some View {
        VStack(alignment: .leading, spacing: 4) {
            SecureField("Bearer Token", text: self.$bearerToken, prompt: Text("..."))
                .textFieldStyle(.roundedBorder)
                .onChange(of: self.bearerToken) { _, _ in
                    self.validationState = .idle
                }

            Text("Set via AWS_BEARER_TOKEN_BEDROCK environment variable")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var canFetchModels: Bool {
        switch self.authMethod {
        case .profile:
            !self.profile.isEmpty
        case .keys:
            // Access Keys auth is disabled until SigV4 is implemented
            false
        case .bearerToken:
            !self.bearerToken.isEmpty
        }
    }

    private var isValidationDisabled: Bool {
        if self.modelId.isEmpty {
            return true
        }
        return switch self.authMethod {
        case .profile:
            self.profile.isEmpty
        case .keys:
            // Access Keys auth is disabled until SigV4 is implemented
            true
        case .bearerToken:
            self.bearerToken.isEmpty
        }
    }

    private func fetchModels() {
        self.isLoadingModels = true

        Task {
            do {
                let models: [BedrockModel] = switch self.authMethod {
                case .profile:
                    try await BedrockValidator.listModelsWithProfile(self.profile, region: self.region)
                case .keys:
                    try await BedrockValidator.listModels(
                        accessKey: self.accessKey,
                        secretKey: self.secretKey,
                        region: self.region
                    )
                case .bearerToken:
                    try await BedrockValidator.listModelsWithBearerToken(
                        bearerToken: self.bearerToken,
                        region: self.region
                    )
                }
                await MainActor.run {
                    self.modelCache.setModels(
                        models.map { LLMModel(id: $0.id, name: $0.id, provider: .awsBedrock) },
                        for: .awsBedrock
                    )
                    self.isLoadingModels = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingModels = false
                    self.validationState = .failure(error: "Failed to fetch models: \(error.localizedDescription)")
                }
            }
        }
    }

    private func validateCredentials() {
        self.validationState = .validating

        Task {
            do {
                let validationMessage: String = switch self.authMethod {
                case .profile:
                    try await BedrockValidator.validateProfile(
                        self.profile,
                        region: self.region,
                        modelId: self.modelId
                    )
                case .keys:
                    try await BedrockValidator.validateKeys(
                        accessKey: self.accessKey,
                        secretKey: self.secretKey,
                        region: self.region,
                        modelId: self.modelId
                    )
                case .bearerToken:
                    try await BedrockValidator.validateBearerToken(
                        self.bearerToken,
                        region: self.region,
                        modelId: self.modelId
                    )
                }
                await MainActor.run {
                    self.validationState = .success(message: validationMessage)
                }
            } catch {
                await MainActor.run {
                    self.validationState = .failure(error: error.localizedDescription)
                }
            }
        }
    }
}
