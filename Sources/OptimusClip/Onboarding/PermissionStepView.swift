import SwiftUI

/// Accessibility permission step of the onboarding flow.
///
/// This view guides users through granting accessibility permission with:
/// - Clear explanation of why the permission is needed
/// - Live status indicator that updates in real-time
/// - Direct link to System Settings
/// - Continue button that enables when permission is granted
///
/// ## Polling Strategy
/// Uses the AccessibilityPermissionManager's context-aware polling:
/// - Sets `.permissionsTabVisible` context on appear (1-second polling)
/// - Restores context on disappear
/// - Automatically detects when permission is granted
///
/// ## Usage
/// ```swift
/// PermissionStepView(onContinue: { onboardingState.advance() })
///     .environmentObject(onboardingState)
/// ```
struct PermissionStepView: View {
    /// Action to perform when user taps Continue (after permission is granted).
    let onContinue: () -> Void

    @ObservedObject private var permissionManager = AccessibilityPermissionManager.shared

    /// Tracks if permission was just granted (for celebration animation).
    @State private var showGrantedAnimation = false

    var body: some View {
        VStack(spacing: 32) {
            // Icon
            self.iconSection

            // Title and explanation
            self.explanationSection

            // Status indicator
            self.statusSection

            Spacer()

            // Action buttons
            self.actionButtons
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Fast polling when user is actively viewing this screen
            self.permissionManager.setPollingContext(.permissionsTabVisible)
        }
        .onDisappear {
            // Slower polling when navigating away
            self.permissionManager.setPollingContext(.settingsOpen)
        }
        .onChange(of: self.permissionManager.isGranted) { _, newValue in
            if newValue {
                // Show celebration animation
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    self.showGrantedAnimation = true
                }
                // Auto-advance after a brief celebration
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    self.onContinue()
                }
            }
        }
    }

    // MARK: - Icon Section

    @ViewBuilder
    private var iconSection: some View {
        ZStack {
            // Background glow when granted
            if self.permissionManager.isGranted {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .scaleEffect(self.showGrantedAnimation ? 1.3 : 1.0)
            }

            Image(systemName: self.permissionManager.isGranted ? "checkmark.shield.fill" : "shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(self.permissionManager.isGranted ? .green : .yellow)
                .scaleEffect(self.showGrantedAnimation ? 1.1 : 1.0)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: self.permissionManager.isGranted)
    }

    // MARK: - Explanation Section

    @ViewBuilder
    private var explanationSection: some View {
        VStack(spacing: 12) {
            Text("Accessibility Permission Required")
                .font(.title2.bold())

            Text("Optimus Clip needs permission to:")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                PermissionBulletPoint("Listen for your keyboard shortcuts")
                PermissionBulletPoint("Paste transformed text into other apps")
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Status Section

    @ViewBuilder
    private var statusSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: self.permissionManager.isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(self.permissionManager.isGranted ? .green : .red)
                    .contentTransition(.symbolEffect(.replace))

                Text(self.permissionManager.isGranted ? "Permission Granted!" : "Not Granted")
                    .font(.headline)
                    .foregroundStyle(self.permissionManager.isGranted ? .green : .primary)
            }
            .padding()
            .frame(maxWidth: 280)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(self.permissionManager.isGranted
                        ? Color.green.opacity(0.1)
                        : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        self.permissionManager.isGranted
                            ? Color.green.opacity(0.3)
                            : Color.secondary.opacity(0.2),
                        lineWidth: 1
                    )
            )

            if !self.permissionManager.isGranted {
                Text("Click below to open System Settings, then enable Optimus Clip.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 16) {
            if !self.permissionManager.isGranted {
                Button {
                    self.permissionManager.openSystemSettings()
                } label: {
                    Label("Open System Settings", systemImage: "gear")
                        .frame(minWidth: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Button {
                self.onContinue()
            } label: {
                Text("Continue")
                    .frame(minWidth: 200)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(!self.permissionManager.isGranted)
            .opacity(self.permissionManager.isGranted ? 1.0 : 0.5)
        }
    }
}

// MARK: - Permission Bullet Point

/// A bullet point for the permission explanation list.
private struct PermissionBulletPoint: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\u{2022}")
                .foregroundStyle(.secondary)
            Text(self.text)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview("Permission Not Granted") {
    PermissionStepView(onContinue: {})
        .frame(width: 500, height: 600)
}
