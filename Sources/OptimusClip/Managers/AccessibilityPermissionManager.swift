import AppKit
@preconcurrency import ApplicationServices

/// Manages accessibility permission state and provides methods to request and check permission.
///
/// macOS requires explicit user permission for apps to:
/// 1. **Monitor keyboard events globally** (for hotkeys)
/// 2. **Simulate keyboard input** (for paste simulation via CGEvent)
///
/// Without accessibility permission, Optimus Clip cannot detect global hotkey presses
/// or simulate Cmd+V to paste transformed content.
///
/// ## Permission Flow
/// ```
/// App Launch
///     │
///     ▼
/// Check AXIsProcessTrusted()
///     │
///     ├─── TRUE ──→ Proceed normally
///     │
///     ▼ (FALSE)
/// Show in-app explainer UI
///     │
///     ▼
/// User clicks "Grant Permission"
///     │
///     ▼
/// Call AXIsProcessTrustedWithOptions (shows system dialog)
///     │
///     ▼
/// Start polling for permission grant
///     │
///     ├─── Permission granted ──→ Dismiss UI, proceed
///     │
///     └─── Still denied ──→ Show "Open System Settings" button
/// ```
///
/// ## Polling Strategy
/// - **Interval**: 2 seconds is fast enough to feel responsive, slow enough to not waste CPU.
/// - **Reason**: macOS doesn't provide notifications when permission changes.
///
/// ## Usage
/// ```swift
/// @ObservedObject var permissionManager = AccessibilityPermissionManager.shared
///
/// if permissionManager.isGranted {
///     // Proceed with hotkey registration, paste simulation
/// } else {
///     // Show permission request UI
/// }
/// ```
@MainActor
public final class AccessibilityPermissionManager: ObservableObject {
    // MARK: - Singleton

    /// Shared instance for global access.
    public static let shared = AccessibilityPermissionManager()

    // MARK: - Configuration

    /// Polling interval for checking permission changes.
    /// 2 seconds balances responsiveness with efficiency.
    private let pollInterval: TimeInterval = 2.0

    // MARK: - Published State

    /// Whether accessibility permission is currently granted.
    /// Observable property that updates when permission status changes.
    @Published public private(set) var isGranted: Bool = false

    /// Whether the permission dialog has been shown at least once.
    /// Useful for showing help text if the dialog was dismissed without granting.
    @Published public private(set) var hasBeenRequested: Bool = false

    // MARK: - Private State

    /// Task for polling permission state changes.
    private var pollTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Creates a new accessibility permission manager.
    ///
    /// Checks current permission state and starts polling for changes.
    /// The polling detects when the user grants permission via System Settings.
    private init() {
        self.checkPermission()
        self.startPolling()
    }

    deinit {
        self.pollTask?.cancel()
    }

    // MARK: - Public Methods

    /// Checks current accessibility permission state and updates `isGranted`.
    ///
    /// This is called automatically on init and during polling, but can also
    /// be called manually to force a refresh.
    public func checkPermission() {
        self.isGranted = AXIsProcessTrusted()
    }

    /// Requests accessibility permission by opening System Settings directly.
    ///
    /// We skip the system dialog (AXIsProcessTrustedWithOptions) because:
    /// 1. It just asks the user to open System Settings anyway
    /// 2. It's often suppressed after being dismissed once
    /// 3. The user must manually toggle the permission in Settings regardless
    ///
    /// This provides a cleaner UX - one action that takes the user directly
    /// where they need to go.
    public func requestPermission() {
        self.hasBeenRequested = true
        self.openSystemSettings()
    }

    /// Opens System Settings directly to the Accessibility privacy pane.
    ///
    /// Useful when the system dialog doesn't appear (already shown once) and
    /// the user needs to manually add the app to the accessibility list.
    ///
    /// - Note: Works on macOS 13 (Ventura) and later.
    public func openSystemSettings() {
        // URL scheme for Privacy & Security > Accessibility
        // swiftlint:disable:next force_unwrapping
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// Stops polling for permission changes.
    ///
    /// Call this when the app is terminating or when polling is no longer needed.
    public func stopPolling() {
        self.pollTask?.cancel()
        self.pollTask = nil
    }

    // MARK: - Private Methods

    /// Starts polling for permission state changes.
    ///
    /// macOS doesn't notify apps when accessibility permission is granted or revoked.
    /// Polling is the only reliable way to detect when the user grants permission
    /// via System Settings.
    private func startPolling() {
        self.pollTask?.cancel()
        self.pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self?.pollInterval ?? 2.0) * 1_000_000_000)
                guard let self, !Task.isCancelled else { break }
                let newValue = AXIsProcessTrusted()
                if newValue != self.isGranted {
                    self.isGranted = newValue
                }
            }
        }
    }
}
