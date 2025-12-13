import AppKit
import SwiftUI

// MARK: - Helper Views

/// Button for validating provider credentials.
struct ValidateButton: View {
    let state: ValidationState
    let isDisabled: Bool
    let action: () -> Void
    var label: String = "Validate"

    var body: some View {
        Button(action: self.action) {
            switch self.state {
            case .validating:
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failure:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            case .idle:
                Text(self.label)
            }
        }
        .buttonStyle(.bordered)
        .disabled(self.isDisabled || self.state == .validating)
    }
}

/// Displays validation status message.
struct ValidationStatusView: View {
    let state: ValidationState

    var body: some View {
        switch self.state {
        case let .success(message):
            Label(message, systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
        case let .failure(error):
            Label(error, systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundColor(.red)
        case .idle, .validating:
            EmptyView()
        }
    }
}

/// Link to provider's API key management page.
struct ProviderHelpLink: View {
    let provider: LLMProvider
    var label: String = "Get API Key"

    var body: some View {
        if let url = self.provider.helpURL {
            Button(self.label) {
                NSWorkspace.shared.open(url)
            }
            .buttonStyle(.link)
            .font(.caption)
        }
    }
}
