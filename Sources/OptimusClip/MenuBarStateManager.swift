import AppKit
import Combine
import OptimusClipCore
import SwiftUI

// MARK: - Menu Bar Badge

/// Badge indicator for menu bar icon attention state.
///
/// Badge shows when the app needs user action to function properly:
/// - `needsAttention`: Critical issue (permission missing)
/// - `setupIncomplete`: Warning (LLM transforms without configured provider)
public enum MenuBarBadge: Sendable, Equatable {
    /// No badge - app is ready to work.
    case none

    /// Red badge - critical issue requiring attention (e.g., permission missing).
    case needsAttention

    /// Yellow badge - setup incomplete (e.g., LLM transforms without configured provider).
    case setupIncomplete
}

/// Manages menu bar icon state and appearance.
///
/// This observable object wraps `IconStateMachine` to provide SwiftUI bindings
/// for reactive UI updates. It coordinates icon state changes (idle, disabled)
/// across the entire app lifecycle.
///
/// ## States
/// - **Idle**: Full opacity, normal operation
/// - **Disabled**: Dimmed (0.45 opacity), monitoring paused
@MainActor
final class MenuBarStateManager: ObservableObject {
    /// Whether the menu is currently presented (open).
    @Published var isMenuPresented: Bool = false

    /// The underlying state machine (testable in OptimusClipCore).
    @Published private(set) var stateMachine = IconStateMachine()

    /// Indicates whether an LLM transformation is currently running.
    @Published private(set) var isProcessing: Bool = false

    /// Reflects the user's Reduce Motion accessibility preference.
    @Published private(set) var reduceMotionEnabled: Bool

    /// Tracks whether global hotkey listening is currently enabled.
    @Published private(set) var hotkeysEnabled: Bool

    /// Whether accessibility permission is currently granted.
    @Published private(set) var accessibilityPermissionGranted: Bool

    /// Whether at least one LLM provider is configured.
    @Published private(set) var hasConfiguredProvider: Bool

    /// Whether any enabled transformation requires an LLM provider.
    @Published private(set) var hasEnabledLLMTransformations: Bool

    /// Publisher we listen to for processing state updates (injectable for testing).
    private let processingPublisher: AnyPublisher<Bool, Never>

    /// Notification center for observing accessibility preference changes.
    private let notificationCenter: NotificationCenter

    /// Closure that reads the current Reduce Motion setting.
    private let reduceMotionProvider: () -> Bool

    /// Publisher that emits global hotkey listening state changes.
    private let hotkeyStatePublisher: AnyPublisher<Bool, Never>

    /// Publisher that emits accessibility permission state changes.
    private let accessibilityPermissionPublisher: AnyPublisher<Bool, Never>

    /// Closure to check if any provider has configured credentials.
    private let providerConfigChecker: () -> Bool

    /// Closure to check if any enabled transformation is LLM type.
    private let llmTransformationsChecker: () -> Bool

    /// Combine cancellables for publisher subscriptions.
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    /// Creates a new menu bar state manager.
    ///
    /// - Parameters:
    ///   - processingPublisher: Optional custom publisher for processing state (used in tests).
    ///   - notificationCenter: Notification center for accessibility changes.
    ///   - reduceMotionProvider: Closure that reports the current Reduce Motion preference.
    ///   - hotkeyStatePublisher: Publisher for hotkey enable/disable state (defaults to HotkeyManager).
    ///   - initialHotkeyState: Optional override for initial hotkey enabled state (used in tests).
    ///   - accessibilityPermissionPublisher: Publisher for accessibility permission state.
    ///   - providerConfigChecker: Closure that checks if any provider has credentials configured.
    ///   - llmTransformationsChecker: Closure that checks if any enabled transformation is LLM type.
    init(
        processingPublisher: AnyPublisher<Bool, Never>? = nil,
        notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        reduceMotionProvider: @escaping () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion },
        hotkeyStatePublisher: AnyPublisher<Bool, Never>? = nil,
        initialHotkeyState: Bool? = nil,
        accessibilityPermissionPublisher: AnyPublisher<Bool, Never>? = nil,
        providerConfigChecker: (() -> Bool)? = nil,
        llmTransformationsChecker: (() -> Bool)? = nil
    ) {
        self.processingPublisher = processingPublisher ?? TransformationFlowCoordinator.shared.$isProcessing
            .eraseToAnyPublisher()
        self.notificationCenter = notificationCenter
        self.reduceMotionProvider = reduceMotionProvider
        self.reduceMotionEnabled = reduceMotionProvider()
        let resolvedHotkeyState = initialHotkeyState ?? HotkeyManager.shared.hotkeyListeningEnabled
        self.hotkeysEnabled = resolvedHotkeyState
        self.hotkeyStatePublisher = hotkeyStatePublisher ?? HotkeyManager.shared.$hotkeyListeningEnabled
            .eraseToAnyPublisher()

        // Accessibility permission state
        self.accessibilityPermissionPublisher = accessibilityPermissionPublisher
            ?? AccessibilityPermissionManager.shared.$isGranted.eraseToAnyPublisher()
        self.accessibilityPermissionGranted = AccessibilityPermissionManager.shared.isGranted

        // Provider configuration and LLM transformations state
        self.providerConfigChecker = providerConfigChecker ?? Self.defaultProviderConfigChecker
        self.llmTransformationsChecker = llmTransformationsChecker ?? Self.defaultLLMTransformationsChecker
        self.hasConfiguredProvider = self.providerConfigChecker()
        self.hasEnabledLLMTransformations = self.llmTransformationsChecker()

        // Set initial state machine state after all properties initialized
        self.stateMachine.setDisabled(!resolvedHotkeyState)

        self.observeProcessing()
        self.observeAccessibilityChanges()
        self.observeHotkeyState()
        self.observeAccessibilityPermission()
        self.observeProviderConfiguration()
    }

    // MARK: - Forwarded Properties

    /// Current icon state.
    var iconState: IconStateMachine.State {
        self.stateMachine.state
    }

    /// Computed opacity based on current icon state.
    var iconOpacity: Double {
        self.stateMachine.iconOpacity
    }

    /// Whether the menu bar icon should animate to indicate processing.
    var shouldAnimateProcessing: Bool {
        self.isProcessing && !self.reduceMotionEnabled
    }

    /// Whether the icon should highlight (color change) instead of animating.
    var shouldHighlightProcessingIcon: Bool {
        self.isProcessing && self.reduceMotionEnabled
    }

    /// Current badge state for menu bar icon.
    ///
    /// Priority: needsAttention > setupIncomplete > none
    var badge: MenuBarBadge {
        // Critical: Accessibility permission is required for hotkeys to work
        if !self.accessibilityPermissionGranted {
            return .needsAttention
        }

        // Warning: LLM transforms exist but no provider configured
        if self.hasEnabledLLMTransformations, !self.hasConfiguredProvider {
            return .setupIncomplete
        }

        return .none
    }

    /// Human-readable description of the current badge state.
    var badgeDescription: String? {
        switch self.badge {
        case .none:
            nil
        case .needsAttention:
            "Permission Required"
        case .setupIncomplete:
            "Provider Setup Needed"
        }
    }

    /// Detailed help text explaining what action to take for the current badge.
    var badgeHelpText: String? {
        switch self.badge {
        case .none:
            nil
        case .needsAttention:
            "Open System Settings to enable accessibility"
        case .setupIncomplete:
            "Configure an LLM provider in Settings"
        }
    }

    // MARK: - State Transitions

    /// Sets the disabled state for the icon.
    ///
    /// - Parameter disabled: If true, dims the icon; if false, returns to idle.
    func setDisabled(_ disabled: Bool) {
        self.stateMachine.setDisabled(disabled)
    }

    // MARK: - NSStatusItem Configuration

    /// Configure the status item appearance.
    ///
    /// - Parameter statusItem: The NSStatusItem to configure.
    func configureStatusItem(_ statusItem: NSStatusItem) {
        statusItem.button?.toolTip = "Optimus Clip"
    }

    // MARK: - Observers

    private func observeProcessing() {
        self.processingPublisher
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] isProcessing in
                self?.isProcessing = isProcessing
            }
            .store(in: &self.cancellables)
    }

    private func observeAccessibilityChanges() {
        self.notificationCenter.publisher(for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.reduceMotionEnabled = self.reduceMotionProvider()
            }
            .store(in: &self.cancellables)
    }

    private func observeHotkeyState() {
        self.hotkeyStatePublisher
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] isEnabled in
                guard let self else { return }
                self.hotkeysEnabled = isEnabled
                self.stateMachine.setDisabled(!isEnabled)
            }
            .store(in: &self.cancellables)
    }

    private func observeAccessibilityPermission() {
        self.accessibilityPermissionPublisher
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] isGranted in
                self?.accessibilityPermissionGranted = isGranted
            }
            .store(in: &self.cancellables)
    }

    private func observeProviderConfiguration() {
        // Re-check provider config and LLM transformations periodically
        // when UserDefaults changes (transformations or API keys might change)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.hasConfiguredProvider = self.providerConfigChecker()
                self.hasEnabledLLMTransformations = self.llmTransformationsChecker()
            }
            .store(in: &self.cancellables)
    }

    // MARK: - Default Checkers

    /// Default implementation to check if any provider has configured credentials.
    private static let defaultProviderConfigChecker: () -> Bool = {
        let apiKeyStore = APIKeyStore()

        // Check if any provider has an API key configured
        if let openAIKey = try? apiKeyStore.loadOpenAIKey(), !openAIKey.isEmpty {
            return true
        }
        if let anthropicKey = try? apiKeyStore.loadAnthropicKey(), !anthropicKey.isEmpty {
            return true
        }
        if let openRouterKey = try? apiKeyStore.loadOpenRouterKey(), !openRouterKey.isEmpty {
            return true
        }

        // Check AWS (either access key pair or bearer token)
        if let awsAccessKey = try? apiKeyStore.loadAWSAccessKey(),
           let awsSecretKey = try? apiKeyStore.loadAWSSecretKey(),
           !awsAccessKey.isEmpty, !awsSecretKey.isEmpty {
            return true
        }
        if let awsBearerToken = try? apiKeyStore.loadAWSBearerToken(), !awsBearerToken.isEmpty {
            return true
        }

        // Check Ollama (just needs host configured, no API key required)
        let ollamaHost = UserDefaults.standard.string(forKey: SettingsKey.ollamaHost) ?? ""
        if !ollamaHost.isEmpty {
            return true
        }

        return false
    }

    /// Default implementation to check if any enabled transformation is LLM type.
    private static let defaultLLMTransformationsChecker: () -> Bool = {
        guard let data = UserDefaults.standard.data(forKey: "transformations_data"),
              let transformations = try? JSONDecoder().decode([TransformationConfig].self, from: data) else {
            // Check default transformations if no custom ones exist
            return TransformationConfig.defaultTransformations.contains { $0.isEnabled && $0.type == .llm }
        }

        return transformations.contains { $0.isEnabled && $0.type == .llm }
    }

    /// Manually refresh badge-related state.
    ///
    /// Call this after making changes to provider configuration or transformations
    /// to immediately update the badge without waiting for debounce.
    func refreshBadgeState() {
        self.hasConfiguredProvider = self.providerConfigChecker()
        self.hasEnabledLLMTransformations = self.llmTransformationsChecker()
    }
}
