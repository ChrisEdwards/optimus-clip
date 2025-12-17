// swiftlint:disable file_length
// TODO: Extract credential input views to reduce file size (oc-3bc)
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.optimusclip", category: "Onboarding")

/// Optional provider setup step for onboarding.
///
/// Supports OpenAI, Anthropic, or Ollama with validate/skip paths and saves
/// credentials for later use in Settings.
struct ProviderSetupStepView: View {
    /// Action to perform when user taps Continue (after validation).
    let onContinue: () -> Void

    /// Action to perform when user taps Skip.
    let onSkip: () -> Void

    // MARK: - State

    /// Currently selected provider.
    @State private var selectedProvider: OnboardingProvider = .openAI

    /// OpenAI API key input.
    @State private var openAIKey: String = ""

    /// Anthropic API key input.
    @State private var anthropicKey: String = ""

    /// Ollama host input.
    @State private var ollamaHost: String = "localhost"

    /// Ollama port input.
    @State private var ollamaPort: String = "11434"

    /// Ensures stored credentials are loaded once per lifecycle.
    @State private var didLoadStoredCredentials = false

    /// Current validation state.
    @State private var validationState: ValidationState = .idle

    /// API key store for saving credentials.
    private let apiKeyStore = APIKeyStore()

    var body: some View {
        VStack(spacing: 24) {
            // Icon and title
            self.headerSection

            // Provider selection
            self.providerSelectionSection

            // Credentials input for selected provider
            self.credentialsSection

            // Validation status
            self.validationSection

            Spacer()

            // Action buttons
            self.actionButtons
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            self.loadSavedCredentialsIfNeeded()
            self.applyLoadedValidationStateForSelection()
        }
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "cloud.fill")
                .font(.system(size: 56))
                .foregroundStyle(.blue)

            Text("Enable Smart Transformations")
                .font(.title2.bold())

            Text("Connect an AI provider for intelligent text processing")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 6) {
                ProviderBulletPoint("Grammar and spelling fixes")
                ProviderBulletPoint("Summarization and rewriting")
                ProviderBulletPoint("Format conversion")
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Provider Selection Section

    @ViewBuilder
    private var providerSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a Provider")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(OnboardingProvider.allCases) { provider in
                    ProviderRadioButton(
                        provider: provider,
                        isSelected: self.selectedProvider == provider,
                        action: {
                            self.selectedProvider = provider
                            self.applyLoadedValidationStateForSelection()
                        }
                    )
                }
            }
        }
        .frame(maxWidth: 400)
    }

    // MARK: - Credentials Section

    @ViewBuilder
    private var credentialsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch self.selectedProvider {
            case .openAI:
                self.apiKeyInput(
                    label: "OpenAI API Key",
                    placeholder: "sk-...",
                    text: self.$openAIKey,
                    helpURL: URL(string: "https://platform.openai.com/api-keys")
                )
            case .anthropic:
                self.apiKeyInput(
                    label: "Anthropic API Key",
                    placeholder: "sk-ant-...",
                    text: self.$anthropicKey,
                    helpURL: URL(string: "https://console.anthropic.com/settings/keys")
                )
            case .ollama:
                self.ollamaInput
            }
        }
        .frame(maxWidth: 400)
    }

    @ViewBuilder
    private func apiKeyInput(
        label: String,
        placeholder: String,
        text: Binding<String>,
        helpURL: URL?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline.weight(.medium))

                Spacer()

                if let url = helpURL {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Text("Get API Key")
                            Image(systemName: "arrow.up.right.square")
                        }
                        .font(.caption)
                    }
                }
            }

            SecureField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .onChange(of: text.wrappedValue) { _, _ in
                    self.validationState = .idle
                }
        }
    }

    @ViewBuilder
    private var ollamaInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ollama Server")
                .font(.subheadline.weight(.medium))

            HStack(spacing: 8) {
                TextField("Host", text: self.$ollamaHost)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)

                Text(":")
                    .foregroundStyle(.secondary)

                TextField("Port", text: self.$ollamaPort)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
            }
            .onChange(of: self.ollamaHost) { _, _ in self.validationState = .idle }
            .onChange(of: self.ollamaPort) { _, _ in self.validationState = .idle }

            Text("Make sure Ollama is running locally with `ollama serve`")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Validation Section

    @ViewBuilder
    private var validationSection: some View {
        VStack(spacing: 12) {
            switch self.validationState {
            case .idle:
                Button {
                    Task { await self.validateCredentials() }
                } label: {
                    Label("Validate", systemImage: "checkmark.circle")
                        .frame(minWidth: 120)
                }
                .buttonStyle(.bordered)
                .disabled(!self.hasInput)

            case .validating:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Validating...")
                        .foregroundStyle(.secondary)
                }

            case let .success(message):
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(message)
                        .foregroundStyle(.green)
                }
                .font(.subheadline)

            case let .failure(error):
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .foregroundStyle(.red)
                }
                .font(.subheadline)
                .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: 400)
        .padding(.vertical, 8)
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                self.saveCredentials()
                self.onContinue()
            } label: {
                Text("Continue")
                    .frame(minWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!self.isValidated)

            Button {
                self.onSkip()
            } label: {
                Text("Skip - I'll do this later")
                    .frame(minWidth: 200)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Computed Properties

    private var hasInput: Bool {
        switch self.selectedProvider {
        case .openAI:
            !self.openAIKey.isEmpty
        case .anthropic:
            !self.anthropicKey.isEmpty
        case .ollama:
            self.hasOllamaConfig
        }
    }

    private var isValidated: Bool {
        if case .success = self.validationState {
            return true
        }
        return false
    }

    private var hasOllamaConfig: Bool {
        !self.ollamaHost.isEmpty && !self.ollamaPort.isEmpty
    }

    // MARK: - Actions

    private func validateCredentials() async {
        self.validationState = .validating

        do {
            let message: String = switch self.selectedProvider {
            case .openAI:
                try await OpenAIValidator.validateAPIKey(self.openAIKey)
            case .anthropic:
                try await AnthropicValidator.validateAPIKey(self.anthropicKey)
            case .ollama:
                try await OllamaValidator.testConnection(
                    host: self.ollamaHost,
                    port: self.ollamaPort
                )
            }
            self.validationState = .success(message: message)
        } catch {
            self.validationState = .failure(error: error.localizedDescription)
        }
    }

    private func saveCredentials() {
        do {
            switch self.selectedProvider {
            case .openAI:
                try self.apiKeyStore.saveOpenAIKey(self.openAIKey)
            case .anthropic:
                try self.apiKeyStore.saveAnthropicKey(self.anthropicKey)
            case .ollama:
                UserDefaults.standard.set(self.ollamaHost, forKey: SettingsKey.ollamaHost)
                UserDefaults.standard.set(self.ollamaPort, forKey: SettingsKey.ollamaPort)
            }
        } catch {
            // Log error but don't block - user can re-enter in Settings
            logger.error("Failed to save credentials: \(error.localizedDescription)")
        }
    }

    private func loadSavedCredentialsIfNeeded() {
        guard !self.didLoadStoredCredentials else { return }
        self.didLoadStoredCredentials = true

        do {
            if let savedOpenAIKey = try self.apiKeyStore.loadOpenAIKey(), !savedOpenAIKey.isEmpty {
                self.openAIKey = savedOpenAIKey
            }

            if let savedAnthropicKey = try self.apiKeyStore.loadAnthropicKey(), !savedAnthropicKey.isEmpty {
                self.anthropicKey = savedAnthropicKey
            }
        } catch {
            self.validationState = .failure(
                error: "Couldn't load saved keys: \(error.localizedDescription)"
            )
        }

        let defaults = UserDefaults.standard
        if let savedHost = defaults.string(forKey: SettingsKey.ollamaHost), !savedHost.isEmpty {
            self.ollamaHost = savedHost
        }
        if let savedPort = defaults.string(forKey: SettingsKey.ollamaPort), !savedPort.isEmpty {
            self.ollamaPort = savedPort
        }
    }

    private func applyLoadedValidationStateForSelection() {
        switch self.selectedProvider {
        case .openAI where !self.openAIKey.isEmpty:
            self.validationState = .success(message: "Using saved OpenAI key")
        case .anthropic where !self.anthropicKey.isEmpty:
            self.validationState = .success(message: "Using saved Anthropic key")
        case .ollama where self.hasOllamaConfig:
            self.validationState = .success(message: "Using saved Ollama host")
        default:
            self.validationState = .idle
        }
    }
}

// MARK: - Supporting Types

/// Providers available in the onboarding flow.
///
/// This is a subset of all providers - only the most common ones
/// to keep the onboarding simple.
private enum OnboardingProvider: String, CaseIterable, Identifiable {
    case openAI
    case anthropic
    case ollama

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .ollama: "Ollama"
        }
    }

    var description: String {
        switch self {
        case .openAI: "Most popular, requires API key"
        case .anthropic: "Excellent for writing tasks"
        case .ollama: "Free, runs locally on your Mac"
        }
    }

    var iconName: String {
        switch self {
        case .openAI: "brain.head.profile"
        case .anthropic: "sparkles"
        case .ollama: "desktopcomputer"
        }
    }

    var isRecommended: Bool {
        self == .openAI
    }
}

// MARK: - Provider Radio Button

private struct ProviderRadioButton: View {
    let provider: OnboardingProvider
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: 12) {
                Image(systemName: self.isSelected ? "circle.inset.filled" : "circle")
                    .foregroundStyle(self.isSelected ? .blue : .secondary)

                Image(systemName: self.provider.iconName)
                    .frame(width: 24)
                    .foregroundStyle(self.isSelected ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(self.provider.displayName)
                            .fontWeight(self.isSelected ? .semibold : .regular)

                        if self.provider.isRecommended {
                            Text("Recommended")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }

                    Text(self.provider.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(self.isSelected
                        ? Color.blue.opacity(0.08)
                        : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        self.isSelected ? Color.blue.opacity(0.3) : Color.secondary.opacity(0.2),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Provider Bullet Point

private struct ProviderBulletPoint: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\u{2022}")
                .foregroundStyle(.secondary)
            Text(self.text)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview("Provider Setup") {
    ProviderSetupStepView(onContinue: {}, onSkip: {})
        .frame(width: 500, height: 700)
}
