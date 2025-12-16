import AppKit
import Combine
import OptimusClipCore
import SwiftUI

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

    /// Publisher we listen to for processing state updates (injectable for testing).
    private let processingPublisher: AnyPublisher<Bool, Never>

    /// Notification center for observing accessibility preference changes.
    private let notificationCenter: NotificationCenter

    /// Closure that reads the current Reduce Motion setting.
    private let reduceMotionProvider: () -> Bool

    /// Publisher that emits global hotkey listening state changes.
    private let hotkeyStatePublisher: AnyPublisher<Bool, Never>

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
    init(
        processingPublisher: AnyPublisher<Bool, Never>? = nil,
        notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        reduceMotionProvider: @escaping () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion },
        hotkeyStatePublisher: AnyPublisher<Bool, Never>? = nil,
        initialHotkeyState: Bool? = nil
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
        self.stateMachine.setDisabled(!resolvedHotkeyState)

        self.observeProcessing()
        self.observeAccessibilityChanges()
        self.observeHotkeyState()
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
}
