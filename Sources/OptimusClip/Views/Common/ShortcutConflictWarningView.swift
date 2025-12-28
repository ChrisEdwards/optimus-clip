import SwiftUI

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
