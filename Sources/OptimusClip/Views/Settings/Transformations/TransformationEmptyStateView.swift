import SwiftUI

// MARK: - Empty State View

/// Placeholder shown when no transformation is selected.
///
/// Provides visual indication and instructions for the user
/// to select or create a transformation.
struct TransformationEmptyStateView: View {
    let onCreateTransformation: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("Create Your First Transformation")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Transformations modify clipboard content when you press a keyboard shortcut.\n" +
                "Clean up code, fix grammar, or reformat text instantly.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                self.onCreateTransformation()
            } label: {
                Label("Create Transformation", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("Or select an existing one from the sidebar.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
    }
}

// MARK: - Preview

#Preview {
    TransformationEmptyStateView(onCreateTransformation: {})
        .frame(width: 300, height: 300)
}
