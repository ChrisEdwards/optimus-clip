import SwiftUI

/// Two-line HUD view showing transformation name and current status.
///
/// Layout:
/// ```
/// ┌─────────────────────────────────────┐
/// │   Running: Clean Terminal Text      │  ← Transformation name
/// │ ◐ Receiving... (2.3s)               │  ← Status + icon
/// └─────────────────────────────────────┘
/// ```
struct HUDNotificationView: View {
    let transformationName: String
    let state: HUDState
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Top line: Transformation name
            Text("Running: \(self.transformationName)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)

            // Bottom line: Status with icon
            HStack(spacing: 8) {
                self.stateIcon
                    .frame(width: 14, height: 14)

                Text(self.state.statusText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                // Close button (X)
                Button(action: self.onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 14, height: 14)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minWidth: 240, maxWidth: 400)
        .background(self.backgroundView)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }

    // MARK: - State Icon

    @ViewBuilder
    private var stateIcon: some View {
        switch self.state {
        case .starting, .connecting, .sending, .receiving:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.6)

        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.green)

        case .error:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.red)

        case .cancelled:
            Image(systemName: "slash.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        ZStack {
            // Base dark background
            Color.black.opacity(0.9)

            // Subtle gradient overlay
            LinearGradient(
                colors: [
                    Color.black.opacity(0.95),
                    Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Subtle blur effect for depth
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .opacity(0.05)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Starting") {
        HUDNotificationView(
            transformationName: "Clean Terminal Text",
            state: .starting,
            onClose: {}
        )
        .padding()
        .background(Color.gray)
    }

    #Preview("Receiving") {
        HUDNotificationView(
            transformationName: "Format as Markdown",
            state: .receiving(elapsedSeconds: 2.3),
            onClose: {}
        )
        .padding()
        .background(Color.gray)
    }

    #Preview("Success") {
        HUDNotificationView(
            transformationName: "Grammar Fix",
            state: .success,
            onClose: {}
        )
        .padding()
        .background(Color.gray)
    }

    #Preview("Error") {
        HUDNotificationView(
            transformationName: "Summarize",
            state: .error(message: "Rate limited"),
            onClose: {}
        )
        .padding()
        .background(Color.gray)
    }
#endif
