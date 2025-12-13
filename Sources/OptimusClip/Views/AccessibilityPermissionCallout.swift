import SwiftUI

/// A callout view that explains accessibility permission requirements and guides the user.
///
/// This view is displayed when accessibility permission has not been granted. It provides:
/// - Clear explanation of why the permission is needed
/// - A button to trigger the system permission dialog
/// - A button to open System Settings directly
/// - Help text if the dialog was already shown
///
/// ## Design Philosophy
/// Accessibility permission is often confusing for users. This view:
/// - Uses friendly, non-scary language
/// - Explains the specific features that require permission
/// - Provides multiple paths to grant permission
/// - Shows helpful guidance if the first attempt fails
///
/// ## Usage
/// ```swift
/// VStack {
///     AccessibilityPermissionCallout()
///     // ... other content
/// }
/// ```
///
/// The view automatically hides itself when permission is granted.
public struct AccessibilityPermissionCallout: View {
    @ObservedObject private var permissionManager = AccessibilityPermissionManager.shared

    public init() {}

    public var body: some View {
        if !self.permissionManager.isGranted {
            VStack(alignment: .leading, spacing: 12) {
                // Warning header
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                        .font(.title2)

                    Text("Accessibility Permission Required")
                        .font(.headline)
                }

                // Explanation
                Text("Optimus Clip needs Accessibility permission to:")
                    .foregroundColor(.secondary)

                // Feature list
                VStack(alignment: .leading, spacing: 4) {
                    Label("Detect global keyboard shortcuts", systemImage: "keyboard")
                    Label("Paste transformed text automatically", systemImage: "doc.on.clipboard")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        self.permissionManager.requestPermission()
                    } label: {
                        Label("Grant Permission", systemImage: "lock.open")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        self.permissionManager.openSystemSettings()
                    } label: {
                        Label("Open Settings", systemImage: "gear")
                    }
                    .buttonStyle(.bordered)
                }

                // Help text shown after request
                if self.permissionManager.hasBeenRequested {
                    Text(
                        "If the dialog didn't appear, click 'Open Settings' " +
                            "and add Optimus Clip to the Accessibility list."
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

/// A compact status indicator for accessibility permission.
///
/// Shows a simple icon and text indicating whether permission is granted.
/// Useful for displaying in settings or status areas.
public struct AccessibilityPermissionStatus: View {
    @ObservedObject private var permissionManager = AccessibilityPermissionManager.shared

    public init() {}

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: self.permissionManager.isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(self.permissionManager.isGranted ? .green : .red)

            Text(self.permissionManager.isGranted ? "Permission Granted" : "Permission Required")
                .font(.subheadline)
        }
    }
}

#Preview("Callout - Not Granted") {
    AccessibilityPermissionCallout()
        .padding()
        .frame(width: 400)
}

#Preview("Status Indicator") {
    VStack(spacing: 20) {
        AccessibilityPermissionStatus()
    }
    .padding()
}
