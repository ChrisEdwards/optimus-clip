import SwiftUI

// MARK: - Empty State View

/// Placeholder shown when no transformation is selected.
///
/// Provides visual indication and instructions for the user
/// to select or create a transformation.
struct TransformationEmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Transformation Selected")
                .font(.title2)
                .fontWeight(.medium)

            Text("Select a transformation from the sidebar\nor click + to create a new one.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    TransformationEmptyStateView()
        .frame(width: 300, height: 300)
}
