import KeyboardShortcuts
import OptimusClipCore
import SwiftUI

// MARK: - Test State

/// State of the transformation test execution.
enum TransformationTestState: Equatable {
    case idle
    case running
    case success(duration: TimeInterval)
    case error(message: String)
}

// MARK: - Editor View

/// Detail editor for a single transformation configuration.
///
/// Provides form fields for:
/// - Basic settings: name, hotkey, enabled toggle
/// - Type selection: algorithmic or LLM
/// - LLM settings: provider, model, system prompt (conditional)
/// - Test mode with input/output preview
struct TransformationEditorView: View {
    @Binding var transformation: TransformationConfig

    /// All transformations for conflict detection.
    var allTransformations: [TransformationConfig] = []

    /// Currently detected shortcut conflict, if any.
    @State private var detectedConflict: ShortcutConflict?

    /// Whether to show the "use anyway" confirmation for system/common conflicts.
    @State private var showUseAnywayConfirmation = false

    // MARK: - Test Mode State

    /// Input text for testing the transformation.
    @State private var testInput: String = ""

    /// Output from the test run.
    @State private var testOutput: String = ""

    /// Current state of test execution.
    @State private var testState: TransformationTestState = .idle

    // MARK: - Model Selection State

    /// Model resolver for determining defaults.
    private let modelResolver = ModelResolver()

    /// Available models fetched from ModelCatalog.
    @State private var availableModels: [LLMModel] = []

    /// Whether models are currently being fetched.
    @State private var isLoadingModels = false

    var body: some View {
        Form {
            // Basic settings
            Section("Basic Settings") {
                // Name: read-only for built-ins, editable for user transformations
                if self.transformation.isBuiltIn {
                    LabeledContent("Name", value: self.transformation.name)
                } else {
                    TextField("Name", text: self.$transformation.name)
                        .textFieldStyle(.roundedBorder)
                }

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

            // LLM Configuration: shown for user transformations (always LLM), hidden for built-ins
            if !self.transformation.isBuiltIn {
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
            }

            // Test Mode Section
            Section("Test Transformation") {
                VStack(alignment: .leading, spacing: 12) {
                    // Input area
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Input")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextEditor(text: self.$testInput)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 60, maxHeight: 100)
                            .border(Color.secondary.opacity(0.3))
                    }

                    // Run button and status
                    HStack {
                        Button {
                            Task {
                                await self.runTest()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                if self.testState == .running {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "play.fill")
                                }
                                Text("Run Test")
                            }
                        }
                        .disabled(self.testInput.isEmpty || self.testState == .running)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Spacer()

                        // Status indicator
                        self.testStatusView
                    }

                    // Output area (only show if there's output)
                    if !self.testOutput.isEmpty || self.testState == .running {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Output")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            if self.testState == .running {
                                HStack {
                                    Spacer()
                                    ProgressView("Running transformation...")
                                    Spacer()
                                }
                                .frame(minHeight: 60)
                            } else {
                                TextEditor(text: .constant(self.testOutput))
                                    .font(.system(.body, design: .monospaced))
                                    .frame(minHeight: 60, maxHeight: 100)
                                    .border(Color.secondary.opacity(0.3))
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Test Status View

    @ViewBuilder
    private var testStatusView: some View {
        switch self.testState {
        case .idle:
            EmptyView()
        case .running:
            Text("Running...")
                .font(.caption)
                .foregroundColor(.secondary)
        case let .success(duration):
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(String(format: "%.2fs", duration))
            }
            .font(.caption)
        case let .error(message):
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text(message)
                    .lineLimit(1)
            }
            .font(.caption)
            .help(message)
        }
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
        .onChange(of: self.providerBinding.wrappedValue) { _, _ in
            // Clear fetched models when provider changes (they're provider-specific)
            self.availableModels = []
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
                self.availableModels = models
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

    // MARK: - Test Execution

    /// Runs the transformation on test input and displays the result.
    @MainActor
    private func runTest() async {
        guard !self.testInput.isEmpty else { return }

        // Capture values before async work
        let transformationSnapshot = self.transformation
        let inputSnapshot = self.testInput

        let startTime = Date()
        self.testState = .running
        self.testOutput = ""

        do {
            let tester = TransformationTester()
            let output = try await tester.runTest(
                transformation: transformationSnapshot,
                input: inputSnapshot
            )
            let duration = Date().timeIntervalSince(startTime)
            self.testOutput = output
            self.testState = .success(duration: duration)
        } catch {
            self.testState = .error(message: error.localizedDescription)
        }
    }
}

// MARK: - Preview

#Preview("Editor") {
    TransformationEditorView(
        transformation: .constant(TransformationConfig(
            name: "Test Transform",
            type: .llm,
            isEnabled: true,
            provider: "anthropic",
            systemPrompt: "Clean up the text."
        ))
    )
    .frame(width: 300, height: 500)
}
