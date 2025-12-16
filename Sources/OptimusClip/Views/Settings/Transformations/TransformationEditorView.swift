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

            // Transformation type
            Section("Transformation Type") {
                Picker("Type", selection: self.$transformation.type) {
                    ForEach(TransformationType.allCases) { type in
                        Text(type.detailedName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            // LLM-specific settings (conditional)
            if self.transformation.type == .llm {
                Section("LLM Configuration") {
                    Picker("Provider", selection: self.providerBinding) {
                        Text("Select Provider").tag("")
                        ForEach(LLMProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider.rawValue)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("System Prompt")
                            .font(.headline)

                        TextEditor(text: self.$transformation.systemPrompt)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 100)
                            .border(Color.secondary.opacity(0.3))
                    }
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

        let startTime = Date()
        self.testState = .running
        self.testOutput = ""

        do {
            let output: String = switch self.transformation.type {
            case .algorithmic:
                // Use built-in algorithmic transformation
                try await self.runAlgorithmicTest()

            case .llm:
                // Use LLM transformation
                try await self.runLLMTest()
            }

            let duration = Date().timeIntervalSince(startTime)
            self.testOutput = output
            self.testState = .success(duration: duration)

        } catch {
            self.testState = .error(message: error.localizedDescription)
        }
    }

    /// Runs an algorithmic transformation test.
    private func runAlgorithmicTest() async throws -> String {
        // Use the WhitespaceStripTransformation for algorithmic types
        let transformation = WhitespaceStripTransformation()
        return try await transformation.transform(self.testInput)
    }

    /// Runs an LLM transformation test.
    private func runLLMTest() async throws -> String {
        // Validate provider is configured
        guard let providerName = self.transformation.provider,
              !providerName.isEmpty,
              let providerKind = LLMProviderKind(rawValue: providerName) else {
            throw TestError.noProviderConfigured
        }

        // Create the LLM client using the provider
        let factory = LLMProviderClientFactory()
        guard let client = try? factory.client(for: providerKind),
              client.isConfigured() else {
            throw TestError.providerNotConfigured(providerName)
        }

        // Use the model from the transformation or a reasonable fallback
        let model = self.transformation.model ?? Self.fallbackModel(for: providerKind)

        let llmTransformation = LLMTransformation(
            id: "test-\(self.transformation.id.uuidString)",
            displayName: self.transformation.name,
            providerClient: client,
            model: model,
            systemPrompt: self.transformation.systemPrompt
        )

        return try await llmTransformation.transform(self.testInput)
    }

    /// Returns a reasonable fallback model for the given provider.
    private static func fallbackModel(for provider: LLMProviderKind) -> String {
        switch provider {
        case .anthropic:
            "claude-sonnet-4-20250514"
        case .openAI:
            "gpt-4o-mini"
        case .openRouter:
            "anthropic/claude-3.5-sonnet"
        case .ollama:
            "llama3"
        case .awsBedrock:
            "anthropic.claude-3-5-sonnet-20241022-v2:0"
        }
    }
}

// MARK: - Test Errors

/// Errors that can occur during transformation testing.
private enum TestError: LocalizedError {
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

// MARK: - Shortcut Conflict Warning View

/// Displays an inline warning for keyboard shortcut conflicts.
struct ShortcutConflictWarningView: View {
    let conflict: ShortcutConflict
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: self.conflict.iconName)
                .foregroundColor(self.iconColor)
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text(self.conflict.shortDescription)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(self.textColor)

                Text(self.conflict.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Action button for critical conflicts
                if self.conflict.severity == .critical {
                    Button("Choose Different Shortcut") {
                        self.onDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.red)
                    .padding(.top, 4)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(self.backgroundColor)
        .cornerRadius(8)
    }

    private var iconColor: Color {
        switch self.conflict.severity {
        case .critical: .red
        case .system: .orange
        case .internal: .yellow
        case .common: .blue
        }
    }

    private var textColor: Color {
        switch self.conflict.severity {
        case .critical: .red
        case .system: .orange
        case .internal: .primary
        case .common: .primary
        }
    }

    private var backgroundColor: Color {
        switch self.conflict.severity {
        case .critical: Color.red.opacity(0.1)
        case .system: Color.orange.opacity(0.1)
        case .internal: Color.yellow.opacity(0.1)
        case .common: Color.blue.opacity(0.05)
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
