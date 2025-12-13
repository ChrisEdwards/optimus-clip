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

    var body: some View {
        Form {
            // Basic settings
            Section("Basic Settings") {
                TextField("Name", text: self.$transformation.name)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("Keyboard Shortcut")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: self.transformation.shortcutName)
                        .fixedSize()
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

                    TextField("Model", text: self.modelBinding)
                        .textFieldStyle(.roundedBorder)

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

    /// Binding for model (handles nil -> empty string conversion).
    private var modelBinding: Binding<String> {
        Binding(
            get: { self.transformation.model ?? "" },
            set: { self.transformation.model = $0.isEmpty ? nil : $0 }
        )
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
            model: "claude-3-haiku-20240307",
            systemPrompt: "Clean up the text."
        ))
    )
    .frame(width: 300, height: 500)
}
