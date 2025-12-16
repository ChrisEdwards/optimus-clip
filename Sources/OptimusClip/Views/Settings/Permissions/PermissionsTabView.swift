import SwiftUI

/// Permissions tab for managing Accessibility permission.
///
/// Optimus Clip requires Accessibility permission to:
/// 1. **Capture global keyboard shortcuts** - HotkeyManager uses CGEvent tap
/// 2. **Simulate paste events** - PasteSimulator uses CGEvent.post
///
/// Without this permission, the app cannot function. This tab provides:
/// - Clear visual indication of permission status
/// - Prominent warning when permission not granted
/// - Easy path to grant permission (1-2 clicks)
/// - Educational content explaining why permission is needed
///
/// ## Polling Strategy
/// macOS doesn't provide notifications when permission changes.
/// The AccessibilityPermissionManager uses context-aware polling:
/// - **1 second**: When this Permissions tab is visible (user is actively waiting)
/// - **5 seconds**: When Settings window is open but on another tab
/// - **30 seconds**: When app is in background
/// - **Stopped**: Once permission is granted (no further polling needed)
struct PermissionsTabView: View {
    @ObservedObject private var permissionManager = AccessibilityPermissionManager.shared

    var body: some View {
        Form {
            // Warning callout (shown only when permission NOT granted)
            if !self.permissionManager.isGranted {
                Section {
                    AccessibilityCalloutView(permissionManager: self.permissionManager)
                }
            }

            // Status section (always shown)
            Section("Permission Status") {
                PermissionStatusRow(isGranted: self.permissionManager.isGranted)
            }

            // Explanation section
            Section("About Accessibility Permission") {
                PermissionExplanationView()
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            // Fast polling when user is actively viewing permissions
            self.permissionManager.setPollingContext(.permissionsTabVisible)
        }
        .onDisappear {
            // Slower polling when navigating away
            self.permissionManager.setPollingContext(.settingsOpen)
        }
    }
}

// MARK: - Accessibility Callout View

/// Prominent warning callout shown when Accessibility permission is not granted.
///
/// Uses yellow/orange styling to draw attention and provides two action paths:
/// 1. "Grant Accessibility" - shows system permission prompt
/// 2. "Open System Settings" - direct link to Privacy settings
struct AccessibilityCalloutView: View {
    @ObservedObject var permissionManager: AccessibilityPermissionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with warning icon
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.yellow)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Accessibility Permission Required")
                        .font(.headline)

                    Text("Optimus Clip needs permission to function")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Explanation bullet points
            VStack(alignment: .leading, spacing: 6) {
                Text("Optimus Clip requires Accessibility permission to:")
                    .font(.body)

                BulletPointRow("Capture global keyboard shortcuts")
                BulletPointRow("Simulate paste events after transformations")
            }
            .padding(.vertical, 4)

            // Action button - single clear action
            Button {
                self.permissionManager.openSystemSettings()
            } label: {
                Label("Open System Settings", systemImage: "gear")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)

            // Help text
            VStack(alignment: .leading, spacing: 4) {
                Text("After granting permission, this message will disappear automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("If OptimusClip isn't in the list, click '+' and select OptimusClip.app from this folder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.yellow.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - Permission Status Row

/// Shows current permission status with appropriate icon and description.
struct PermissionStatusRow: View {
    let isGranted: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: self.isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(self.isGranted ? .green : .red)

            VStack(alignment: .leading, spacing: 2) {
                Text(self.isGranted ? "Accessibility Permission Granted" : "Accessibility Permission Denied")
                    .font(.body)

                Text(self
                    .isGranted ? "All features are fully functional" : "Hotkeys and paste simulation will not work")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Permission Explanation View

/// Educational content explaining why Accessibility permission is needed.
struct PermissionExplanationView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                """
                Accessibility permission is a macOS security feature that allows apps to \
                monitor keyboard events and control your computer. Optimus Clip is open source \
                and auditable - we only use this permission for clipboard transformations.
                """
            )
            .font(.body)
            .foregroundStyle(.secondary)

            Text("You can revoke this permission at any time in System Settings.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Bullet Point Row

/// Simple bullet point row for listing features.
struct BulletPointRow: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\u{2022}")
                .font(.body)
            Text(self.text)
                .font(.body)
        }
        .padding(.leading, 8)
    }
}

// MARK: - Preview

#Preview("Permission Granted") {
    PermissionsTabView()
        .frame(width: 450, height: 500)
}
