import SwiftUI

// MARK: - Sidebar View

/// Sidebar showing list of transformations with add/delete controls.
///
/// Displays transformations in a List with selection support.
/// Bottom toolbar provides add (+) and delete (-) buttons.
struct TransformationsSidebarView: View {
    /// All configured transformations.
    let transformations: [TransformationConfig]

    /// Currently selected transformation ID.
    @Binding var selectedID: UUID?

    /// Callback to add a new transformation.
    let onAdd: () -> Void

    /// Callback to delete a transformation.
    let onDelete: (UUID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Transformation list
            List(self.transformations, selection: self.$selectedID) { transformation in
                TransformationRowView(transformation: transformation)
                    .tag(transformation.id)
            }
            .listStyle(.sidebar)

            // Bottom toolbar
            HStack(spacing: 8) {
                Button(action: self.onAdd) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Add Transformation")

                Button {
                    if let id = self.selectedID {
                        self.onDelete(id)
                    }
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .disabled(self.selectedID == nil)
                .help("Delete Transformation")

                Spacer()
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }
}

// MARK: - Row View

/// Single row in the transformations sidebar.
///
/// Shows:
/// - Enabled/disabled indicator (checkmark or circle)
/// - Transformation name
struct TransformationRowView: View {
    let transformation: TransformationConfig

    var body: some View {
        HStack(spacing: 8) {
            // Enabled indicator
            Image(systemName: self.transformation.isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(self.transformation.isEnabled ? .green : .secondary)
                .font(.system(size: 12))

            // Name only (no lock icon)
            Text(self.transformation.name)
                .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

#Preview("Sidebar") {
    TransformationsSidebarView(
        transformations: TransformationConfig.defaultTransformations,
        selectedID: .constant(nil),
        onAdd: {},
        onDelete: { _ in }
    )
    .frame(width: 200, height: 300)
}
