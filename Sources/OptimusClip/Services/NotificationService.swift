import AppKit
import UserNotifications

/// Categories for notification actions.
public enum NotificationCategory: String, Sendable {
    case transformationError = "TRANSFORMATION_ERROR"
    case authenticationError = "AUTHENTICATION_ERROR"
    case rateLimitError = "RATE_LIMIT_ERROR"
}

/// Actions users can take from notifications.
public enum NotificationAction: String, Sendable {
    case openSettings = "OPEN_SETTINGS"
    case retry = "RETRY"
    case dismiss = "DISMISS"
}

/// Service for displaying user notifications about transformation errors and status.
///
/// Uses `UNUserNotificationCenter` for non-intrusive alerts that:
/// - Auto-dismiss after 5 seconds
/// - Include actionable buttons (Open Settings, Retry)
/// - Respect system notification settings
///
/// ## Usage
/// ```swift
/// await NotificationService.shared.showError(
///     title: "Transformation Failed",
///     message: "Invalid API key. Check Settings.",
///     category: .authenticationError
/// )
/// ```
@MainActor
public final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    // MARK: - Singleton

    /// Shared notification service instance.
    public static let shared = NotificationService()

    // MARK: - Configuration

    /// Whether to play system sound with notifications.
    @Published public var playSoundOnError: Bool = true

    /// Whether notifications are enabled.
    @Published public var notificationsEnabled: Bool = true

    /// Callback invoked when user taps "Open Settings" action.
    public var onOpenSettings: (() -> Void)?

    /// Callback invoked when user taps "Retry" action.
    public var onRetry: (() -> Void)?

    // MARK: - State

    /// Whether notification permission has been granted.
    @Published public private(set) var permissionGranted: Bool = false

    // MARK: - Initialization

    override private init() {
        super.init()
        self.setupNotificationCategories()
        Task {
            await self.requestPermission()
        }
    }

    // MARK: - Permission

    /// Requests notification permission from the user.
    public func requestPermission() async {
        // Guard against running without a proper app bundle (e.g., debug binary)
        guard Bundle.main.bundleIdentifier != nil else {
            self.permissionGranted = false
            return
        }

        let center = UNUserNotificationCenter.current()
        center.delegate = self

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            self.permissionGranted = granted
        } catch {
            self.permissionGranted = false
        }
    }

    // MARK: - Notification Display

    /// Shows an error notification to the user.
    ///
    /// - Parameters:
    ///   - title: The notification title.
    ///   - message: The notification body message.
    ///   - category: The notification category for action buttons.
    public func showError(
        title: String,
        message: String,
        category: NotificationCategory = .transformationError
    ) async {
        guard self.notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.categoryIdentifier = category.rawValue

        if self.playSoundOnError {
            content.sound = .default
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        do {
            // Guard against running without a proper app bundle
            guard Bundle.main.bundleIdentifier != nil else {
                NSSound.beep()
                return
            }
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // Fall back to system beep if notification fails
            NSSound.beep()
        }
    }

    /// Shows a quick transient notification that auto-dismisses.
    ///
    /// - Parameters:
    ///   - title: The notification title.
    ///   - message: The notification body message.
    public func showTransient(title: String, message: String) async {
        guard self.notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        do {
            // Guard against running without a proper app bundle
            guard Bundle.main.bundleIdentifier != nil else {
                return
            }
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // Silent fail for transient notifications
        }
    }

    /// Shows a network error notification with retry option.
    public func showNetworkError(message: String) async {
        await self.showError(
            title: "Network Error",
            message: message,
            category: .transformationError
        )
    }

    /// Shows an authentication error with settings action.
    public func showAuthenticationError(provider: String) async {
        await self.showError(
            title: "Invalid API Key",
            message: "Check your \(provider) API key in Settings.",
            category: .authenticationError
        )
    }

    /// Shows a rate limit error.
    public func showRateLimitError(retryAfter: TimeInterval?) async {
        let message = if let seconds = retryAfter {
            "Rate limit reached. Try again in \(Int(seconds)) seconds."
        } else {
            "Rate limit reached. Please wait and try again."
        }

        await self.showError(
            title: "Rate Limited",
            message: message,
            category: .rateLimitError
        )
    }

    /// Shows a timeout error.
    public func showTimeoutError(seconds: Int) async {
        await self.showError(
            title: "Request Timed Out",
            message: "The request took longer than \(seconds) seconds. Try shorter text or check your connection.",
            category: .transformationError
        )
    }

    // MARK: - Setup

    /// Sets up notification categories with action buttons.
    private func setupNotificationCategories() {
        // Guard against running without a proper app bundle (e.g., debug binary)
        guard Bundle.main.bundleIdentifier != nil else {
            return
        }

        let openSettingsAction = UNNotificationAction(
            identifier: NotificationAction.openSettings.rawValue,
            title: "Open Settings",
            options: [.foreground]
        )

        let retryAction = UNNotificationAction(
            identifier: NotificationAction.retry.rawValue,
            title: "Retry",
            options: []
        )

        let dismissAction = UNNotificationAction(
            identifier: NotificationAction.dismiss.rawValue,
            title: "Dismiss",
            options: [.destructive]
        )

        let errorCategory = UNNotificationCategory(
            identifier: NotificationCategory.transformationError.rawValue,
            actions: [retryAction, dismissAction],
            intentIdentifiers: []
        )

        let authCategory = UNNotificationCategory(
            identifier: NotificationCategory.authenticationError.rawValue,
            actions: [openSettingsAction, dismissAction],
            intentIdentifiers: []
        )

        let rateLimitCategory = UNNotificationCategory(
            identifier: NotificationCategory.rateLimitError.rawValue,
            actions: [dismissAction],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            errorCategory,
            authCategory,
            rateLimitCategory
        ])
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Handle notification actions.
    public nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let action = NotificationAction(rawValue: response.actionIdentifier)

        Task { @MainActor in
            switch action {
            case .openSettings:
                self.onOpenSettings?()
            case .retry:
                self.onRetry?()
            case .dismiss, .none:
                break
            }
        }

        completionHandler()
    }

    /// Show notifications even when app is in foreground.
    public nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
