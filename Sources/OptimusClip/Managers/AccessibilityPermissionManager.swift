import AppKit
@preconcurrency import ApplicationServices

// MARK: - Polling Context

/// Context for determining permission polling rate.
///
/// Polling rate adapts to user context to balance responsiveness with efficiency:
/// - When user is actively waiting on Permissions tab: poll quickly (1s)
/// - When settings window is open: poll at medium rate (5s)
/// - When app is in background: poll slowly (30s) or not at all if granted
public enum PollingContext: Sendable {
    /// Permissions tab is visible - user is actively waiting for permission grant.
    case permissionsTabVisible
    /// Settings window is open but not on Permissions tab.
    case settingsOpen
    /// App is in background or no settings window visible.
    case background
}

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

    /// Current polling context - determines polling rate.
    /// Updated by views when they appear/disappear.
    private var pollingContext: PollingContext = .background

    /// Polling interval based on current context.
    /// - permissionsTabVisible: 1 second (user is actively waiting)
    /// - settingsOpen: 5 seconds (user might navigate to Permissions)
    /// - background: 30 seconds (minimal resource usage)
    private var pollInterval: TimeInterval {
        switch self.pollingContext {
        case .permissionsTabVisible: 1.0
        case .settingsOpen: 5.0
        case .background: 30.0
        }
    }

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
    /// Checks current permission state and starts polling only if needed.
    /// When permission is already granted, no polling occurs - saving CPU cycles.
    /// The polling detects when the user grants permission via System Settings.
    private init() {
        self.checkPermission()
        // Only start polling if permission is not yet granted
        if !self.isGranted {
            self.startPolling()
        }
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

    /// Updates the polling context and adjusts polling rate accordingly.
    ///
    /// Call this when:
    /// - Permissions tab becomes visible: `.permissionsTabVisible` (fastest polling)
    /// - Settings window opens: `.settingsOpen` (medium polling)
    /// - Settings window closes: `.background` (slowest polling)
    ///
    /// When permission is already granted, polling remains stopped regardless of context.
    ///
    /// - Parameter context: The new polling context.
    public func setPollingContext(_ context: PollingContext) {
        guard self.pollingContext != context else { return }
        self.pollingContext = context

        // If permission is granted, no need to poll at all
        guard !self.isGranted else { return }

        // Restart polling with new interval
        self.restartPolling()
    }

    // MARK: - Private Methods

    /// Restarts polling with the current context's interval.
    private func restartPolling() {
        self.stopPolling()
        self.startPolling()
    }

    /// Starts polling for permission state changes.
    ///
    /// macOS doesn't notify apps when accessibility permission is granted or revoked.
    /// Polling is the only reliable way to detect when the user grants permission
    /// via System Settings.
    ///
    /// **Optimization**: Once permission is granted, polling stops automatically
    /// to conserve CPU resources. The manager will not poll again unless
    /// permission is revoked and a new polling cycle is started.
    private func startPolling() {
        // Don't poll if permission is already granted
        guard !self.isGranted else {
            self.stopPolling()
            return
        }

        self.pollTask?.cancel()
        self.pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self?.pollInterval ?? 30.0) * 1_000_000_000)
                guard let self, !Task.isCancelled else { break }
                let newValue = AXIsProcessTrusted()
                if newValue != self.isGranted {
                    self.isGranted = newValue
                    // If permission was just granted, stop polling
                    if newValue {
                        self.stopPolling()
                        break
                    }
                }
            }
        }
    }
}
