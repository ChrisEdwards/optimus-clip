import KeyboardShortcuts
import OptimusClipCore
import SwiftUI

// MARK: - Editor View

/// Detail editor for a single transformation configuration.
///
/// Provides form fields for:
/// - Basic settings: name, hotkey, enabled toggle
/// - LLM settings: provider, model, system prompt
/// - Test mode with input/output preview
struct TransformationEditorView: View {
    @Binding var transformation: TransformationConfig

    /// All transformations for conflict detection.
    var allTransformations: [TransformationConfig] = []

    /// Currently detected shortcut conflict, if any.
    @State private var detectedConflict: ShortcutConflict?

    /// Whether to show the "use anyway" confirmation for system/common conflicts.
    @State private var showUseAnywayConfirmation = false

    // MARK: - Model Selection State

    /// Model resolver for determining defaults.
    private let modelResolver = ModelResolver()

    /// Shared model cache from environment.
    @Environment(\.modelCache) private var modelCache

    /// Whether models are currently being fetched.
    @State private var isLoadingModels = false

    /// Available models from cache for current provider.
    private var availableModels: [LLMModel] {
        guard let providerKind = self.currentProviderKind else { return [] }
        return self.modelCache.models(for: providerKind) ?? []
    }

    var body: some View {
        Form {
            // Basic settings
            Section("Basic Settings") {
                TextField("Name", text: self.$transformation.name)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Keyboard Shortcut")
                        Spacer()
                        KeyboardShortcuts.Recorder(for: self.transformation.shortcutName) { newShortcut in
                            self.validateShortcut(newShortcut)
                        }
                        .fixedSize()
                    }

                    // Inline conflict warning
                    if let conflict = self.detectedConflict {
                        ShortcutConflictWarningView(conflict: conflict) {
                            // Clear shortcut for critical conflicts
                            if conflict.severity == .critical {
                                KeyboardShortcuts.reset(self.transformation.shortcutName)
                                self.detectedConflict = nil
                            }
                        }
                    }
                }

                Toggle("Enabled", isOn: self.$transformation.isEnabled)
            }

            // LLM Configuration: shown for all transformations
            Section("LLM Configuration") {
                Picker("Provider", selection: self.providerBinding) {
                    Text("Select Provider").tag("")
                    ForEach(LLMProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider.rawValue)
                    }
                }
                // Model picker (only shown when provider is selected)
                if !self.providerBinding.wrappedValue.isEmpty {
                    self.modelPickerSection
                }

                self.systemPromptEditorSection
            }

            TransformationTestSection(transformation: self.transformation)
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Model Picker Section

    @ViewBuilder
    private var modelPickerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                ComboBox(
                    text: self.modelComboBoxBinding,
                    items: self.modelComboBoxItems,
                    placeholder: "Select model"
                )
                .frame(height: 24)

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

            // Helper text based on state
            self.modelHelperText
        }
    }

    /// Helper text displayed below the model combobox.
    @ViewBuilder
    private var modelHelperText: some View {
        if self.transformation.model == nil {
            Text("Using provider default")
                .font(.caption)
                .foregroundColor(.secondary)
        } else if self.availableModels.isEmpty, self.canFetchModels {
            Text("Click Fetch to load available models")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            Text("Pinned to this model")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    /// Whether the Fetch button should be enabled.
    private var canFetchModels: Bool { ModelFetcher().canFetch(for: self.currentProviderKind) }

    /// The current provider as LLMProviderKind, if valid.
    private var currentProviderKind: LLMProviderKind? {
        guard let provider = self.transformation.provider, !provider.isEmpty else { return nil }
        return LLMProviderKind(rawValue: provider)
    }

    /// Items to display in the model combobox.
    ///
    /// Always includes "Default (resolved-model)" first, followed by fetched models.
    private var modelComboBoxItems: [String] {
        var items: [String] = []

        // Default option with resolved model name
        let resolvedDefault = self.modelResolver.resolveModel(for: self.transformation)?.model ?? "default"
        items.append("Default (\(resolvedDefault))")

        // Add fetched models (excluding the resolved default to avoid duplication in display)
        for model in self.availableModels where model.id != resolvedDefault {
            items.append(model.id)
        }

        return items
    }

    /// Binding for the model combobox that handles Default vs pinned semantics.
    ///
    /// - "Default (...)" selection → `model = nil` (follows provider default)
    /// - Explicit model selection → `model = "model-id"` (pinned)
    private var modelComboBoxBinding: Binding<String> {
        Binding(
            get: {
                if let model = self.transformation.model {
                    return model // Explicit/pinned selection
                } else {
                    // Show "Default (resolved-model)"
                    let resolvedDefault = self.modelResolver.resolveModel(for: self.transformation)?.model ?? "default"
                    return "Default (\(resolvedDefault))"
                }
            },
            set: { newValue in
                if newValue.hasPrefix("Default") {
                    self.transformation.model = nil // Use provider default
                } else {
                    self.transformation.model = newValue // Pin to specific model
                }
            }
        )
    }

    /// Fetches available models for the current provider.
    private func fetchModels() {
        guard let providerKind = self.currentProviderKind else { return }
        self.isLoadingModels = true

        Task {
            let fetcher = ModelFetcher()
            let models = await fetcher.fetchModels(for: providerKind)
            await MainActor.run {
                self.modelCache.setModels(models, for: providerKind)
                self.isLoadingModels = false
            }
        }
    }

    // MARK: - System Prompt Editor Section

    @ViewBuilder
    private var systemPromptEditorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("System Prompt")
                .font(.headline)

            ZStack(alignment: .topLeading) {
                if self.transformation.systemPrompt.isEmpty {
                    Text("Write instructions for the AI...")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: self.$transformation.systemPrompt)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 100)
            }
            .padding(4)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))

            Text("\(self.transformation.systemPrompt.count) characters")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - Bindings

    /// Binding for provider (handles nil -> empty string conversion).
    private var providerBinding: Binding<String> {
        Binding(
            get: { self.transformation.provider ?? "" },
            set: { self.transformation.provider = $0.isEmpty ? nil : $0 }
        )
    }

    // MARK: - Shortcut Validation

    /// Validates a newly recorded shortcut for conflicts.
    ///
    /// - Parameter shortcut: The new shortcut, or nil if cleared.
    private func validateShortcut(_ shortcut: KeyboardShortcuts.Shortcut?) {
        guard let shortcut else {
            // Shortcut was cleared - no conflict
            self.detectedConflict = nil
            return
        }

        let detector = ShortcutConflictDetector(allTransformations: self.allTransformations)
        self.detectedConflict = detector.detectConflict(
            for: shortcut,
            excludingTransformation: self.transformation.id
        )

        // For critical conflicts, reset the shortcut after a brief delay
        // to allow the warning to show first
        if self.detectedConflict?.severity == .critical {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                KeyboardShortcuts.reset(self.transformation.shortcutName)
            }
        }
    }
}

// MARK: - Preview

#Preview("Editor") {
    TransformationEditorView(
        transformation: .constant(TransformationConfig(
            name: "Test Transform",
            isEnabled: true,
            provider: "anthropic",
            systemPrompt: "Clean up the text."
        ))
    )
    .frame(width: 300, height: 500)
}
