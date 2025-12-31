import OptimusClipCore
import SwiftUI

// MARK: - OpenAI Provider Section

/// Configuration section for OpenAI API credentials.
struct OpenAIProviderSection: View {
    @Binding var apiKey: String
    @Binding var modelId: String
    @Binding var validationState: ValidationState

    @Environment(\.modelCache) private var modelCache
    @State private var isLoadingModels = false

    private var availableModels: [LLMModel] {
        self.modelCache.models(for: .openAI) ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SecureField("API Key", text: self.$apiKey, prompt: Text("sk-..."))
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: self.apiKey) { _, _ in
                        self.validationState = .idle
                    }
            }

            // Model selection
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Model")
                        .frame(width: 50, alignment: .leading)

                    ComboBox(
                        text: self.$modelId,
                        items: self.availableModels.map(\.id),
                        placeholder: "gpt-4o-mini"
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
                    .disabled(self.isLoadingModels || self.apiKey.isEmpty)
                }

                if self.availableModels.isEmpty {
                    Text("Click Fetch to load available models")
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
                    isDisabled: self.apiKey.isEmpty || self.modelId.isEmpty,
                    action: self.validateAPIKey
                )

                Spacer()
            }

            ValidationStatusView(state: self.validationState)

            ProviderHelpLink(provider: .openAI)
        }
    }

    private func fetchModels() {
        self.isLoadingModels = true

        Task {
            do {
                let models = try await OpenAIValidator.listModels(apiKey: self.apiKey)
                await MainActor.run {
                    self.modelCache.setModels(
                        models.map { LLMModel(id: $0.id, name: $0.id, provider: .openAI) },
                        for: .openAI
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

    private func validateAPIKey() {
        self.validationState = .validating

        Task {
            do {
                let result = try await OpenAIValidator.validateAPIKey(
                    self.apiKey,
                    modelId: self.modelId.isEmpty ? nil : self.modelId
                )
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
    @Binding var modelId: String
    @Binding var validationState: ValidationState

    private let availableModels = AnthropicValidator.knownModels

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SecureField("API Key", text: self.$apiKey, prompt: Text("sk-ant-..."))
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: self.apiKey) { _, _ in
                        self.validationState = .idle
                    }
            }

            // Model selection (static list - Anthropic has no public models API)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Model")
                        .frame(width: 50, alignment: .leading)

                    ComboBox(
                        text: self.$modelId,
                        items: self.availableModels.map(\.id),
                        placeholder: "claude-3-5-sonnet-..."
                    )
                    .frame(height: 24)
                    .onChange(of: self.modelId) { _, _ in
                        self.validationState = .idle
                    }
                }

                Text("\(self.availableModels.count) models available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                ValidateButton(
                    state: self.validationState,
                    isDisabled: self.apiKey.isEmpty || self.modelId.isEmpty,
                    action: self.validateAPIKey
                )

                Spacer()
            }

            ValidationStatusView(state: self.validationState)

            ProviderHelpLink(provider: .anthropic)
        }
    }

    private func validateAPIKey() {
        self.validationState = .validating

        Task {
            do {
                let result = try await AnthropicValidator.validateAPIKey(
                    self.apiKey,
                    modelId: self.modelId.isEmpty ? nil : self.modelId
                )
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
    @Binding var modelId: String
    @Binding var validationState: ValidationState

    @Environment(\.modelCache) private var modelCache
    @State private var isLoadingModels = false

    private var availableModels: [LLMModel] {
        self.modelCache.models(for: .openRouter) ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SecureField("API Key", text: self.$apiKey, prompt: Text("sk-or-..."))
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: self.apiKey) { _, _ in
                        self.validationState = .idle
                    }
            }

            // Model selection
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Model")
                        .frame(width: 50, alignment: .leading)

                    ComboBox(
                        text: self.$modelId,
                        items: self.availableModels.map(\.id),
                        placeholder: "anthropic/claude-3.5-sonnet"
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
                    .disabled(self.isLoadingModels || self.apiKey.isEmpty)
                }

                if self.availableModels.isEmpty {
                    Text("Click Fetch to load 100+ available models")
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
                    isDisabled: self.apiKey.isEmpty,
                    action: self.validateAPIKey
                )

                Spacer()
            }

            ValidationStatusView(state: self.validationState)

            ProviderHelpLink(provider: .openRouter)
        }
    }

    private func fetchModels() {
        self.isLoadingModels = true

        Task {
            do {
                let models = try await OpenRouterValidator.listModels(apiKey: self.apiKey)
                await MainActor.run {
                    self.modelCache.setModels(
                        models.map { LLMModel(id: $0.id, name: $0.name, provider: .openRouter) },
                        for: .openRouter
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

    private func validateAPIKey() {
        self.validationState = .validating

        Task {
            do {
                let result = try await OpenRouterValidator.validateAPIKey(
                    self.apiKey,
                    modelId: self.modelId.isEmpty ? nil : self.modelId
                )
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
    @Binding var modelId: String
    @Binding var validationState: ValidationState

    @Environment(\.modelCache) private var modelCache
    @State private var isLoadingModels = false

    private var availableModels: [LLMModel] {
        self.modelCache.models(for: .ollama) ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Host row
            HStack {
                Text("Host")
                    .frame(width: 50, alignment: .leading)

                TextField("", text: self.$host, prompt: Text("http://localhost"))
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: self.host) { _, _ in
                        self.validationState = .idle
                    }
            }

            // Port row
            HStack {
                Text("Port")
                    .frame(width: 50, alignment: .leading)

                TextField("", text: self.$port, prompt: Text("11434"))
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: self.port) { _, _ in
                        self.validationState = .idle
                    }
            }

            // Model selection
            HStack {
                Text("Model")
                    .frame(width: 50, alignment: .leading)

                ComboBox(
                    text: self.$modelId,
                    items: self.availableModels.map(\.id),
                    placeholder: "llama3.2"
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
                .disabled(self.isLoadingModels || self.host.isEmpty)
            }

            if self.availableModels.isEmpty {
                Text("Click Fetch to load locally installed models")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("\(self.availableModels.count) models installed")
                    .font(.caption)
                    .foregroundColor(.secondary)
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

    private func fetchModels() {
        self.isLoadingModels = true

        Task {
            do {
                let models = try await OllamaValidator.listModels(host: self.host, port: self.port)
                await MainActor.run {
                    self.modelCache.setModels(
                        models.map { LLMModel(id: $0.name, name: $0.name, provider: .ollama) },
                        for: .ollama
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

    private func testConnection() {
        self.validationState = .validating

        Task {
            do {
                let result = try await OllamaValidator.testConnection(
                    host: self.host,
                    port: self.port,
                    modelId: self.modelId.isEmpty ? nil : self.modelId
                )
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
