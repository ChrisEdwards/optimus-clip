import KeyboardShortcuts
import SwiftUI

// MARK: - Editor View

/// Detail editor for a single transformation configuration.
///
/// Provides form fields for:
/// - Basic settings: name, hotkey, enabled toggle
/// - Type selection: algorithmic or LLM
/// - LLM settings: provider, model, system prompt (conditional)
struct TransformationEditorView: View {
    @Binding var transformation: TransformationConfig

    /// All transformations for conflict detection.
    var allTransformations: [TransformationConfig] = []

    /// Currently detected shortcut conflict, if any.
    @State private var detectedConflict: ShortcutConflict?

    /// Whether to show the "use anyway" confirmation for system/common conflicts.
    @State private var showUseAnywayConfirmation = false

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
        }
        .formStyle(.grouped)
        .padding()
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
