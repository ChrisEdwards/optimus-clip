import SwiftUI

// MARK: - Transformations Tab View

/// Main view for the Transformations settings tab.
///
/// Implements a master-detail pattern with:
/// - Left sidebar: List of transformations with add/delete controls
/// - Right pane: Editor for selected transformation or empty state
///
/// Transformations are persisted to @AppStorage via JSON encoding.
/// Hotkey registrations are updated via HotkeyManager when transformations change.
struct TransformationsTabView: View {
    /// Stored transformations (JSON-encoded in UserDefaults).
    @AppStorage("transformations_data") private var transformationsData: Data = .init()

    /// Currently selected transformation ID.
    @State private var selectedID: UUID?

    /// Reference to HotkeyManager for registration updates.
    @ObservedObject private var hotkeyManager = HotkeyManager.shared

    /// Computed property to decode/encode transformations from storage.
    private var transformations: [TransformationConfig] {
        get {
            guard !self.transformationsData.isEmpty else {
                return TransformationConfig.defaultTransformations
            }
            return (try? JSONDecoder().decode([TransformationConfig].self, from: self.transformationsData))
                ?? TransformationConfig.defaultTransformations
        }
        nonmutating set {
            self.transformationsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var body: some View {
        HSplitView {
            // Left sidebar
            TransformationsSidebarView(
                transformations: self.transformations,
                selectedID: self.$selectedID,
                onAdd: self.addTransformation,
                onDelete: self.deleteTransformation
            )
            .frame(minWidth: 150, idealWidth: 180, maxWidth: 220)

            // Right detail pane
            if let selectedID = self.selectedID,
               let index = self.transformations.firstIndex(where: { $0.id == selectedID }) {
                TransformationEditorView(
                    transformation: self.bindingForTransformation(at: index),
                    allTransformations: self.transformations
                )
                .frame(minWidth: 250)
            } else {
                TransformationEmptyStateView(onCreateTransformation: self.addTransformation)
                    .frame(minWidth: 250)
            }
        }
    }

    // MARK: - Actions

    private func addTransformation() {
        var current = self.transformations
        let newTransform = TransformationConfig(
            name: "New Transformation",
            type: .algorithmic,
            isEnabled: true
        )
        current.append(newTransform)
        self.transformations = current
        self.selectedID = newTransform.id

        // Register hotkey with HotkeyManager
        self.hotkeyManager.register(transformation: newTransform)
    }

    private func deleteTransformation(_ id: UUID) {
        // Find transformation before removing to unregister hotkey
        if let transformation = self.transformations.first(where: { $0.id == id }) {
            self.hotkeyManager.unregister(transformation: transformation)
        }

        var current = self.transformations
        current.removeAll { $0.id == id }
        self.transformations = current
        if self.selectedID == id {
            self.selectedID = nil
        }
    }

    private func bindingForTransformation(at index: Int) -> Binding<TransformationConfig> {
        Binding(
            get: { self.transformations[index] },
            set: { newValue in
                let oldValue = self.transformations[index]
                var current = self.transformations
                current[index] = newValue
                self.transformations = current

                // Update HotkeyManager when enabled state changes
                if oldValue.isEnabled != newValue.isEnabled {
                    self.hotkeyManager.setEnabled(newValue.isEnabled, for: newValue)
                }
            }
        )
    }
}

// MARK: - Preview

#Preview {
    TransformationsTabView()
        .frame(width: 450, height: 500)
}
