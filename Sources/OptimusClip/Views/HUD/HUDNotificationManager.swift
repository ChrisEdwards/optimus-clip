import AppKit
import SwiftUI

/// Manages the HUD notification panel that displays transformation progress.
///
/// The HUD appears at the bottom center of the active screen and shows:
/// - Transformation name (static throughout operation)
/// - Current status with icon (changes as operation progresses)
///
/// Supports Esc key to cancel in-flight operations.
///
/// ## Usage
/// ```swift
/// // Start showing HUD
/// HUDNotificationManager.shared.show(
///     transformationName: "Clean Terminal Text",
///     onCancel: { coordinator.cancel() }
/// )
///
/// // Update state as operation progresses
/// HUDNotificationManager.shared.updateState(.connecting(provider: "Anthropic"))
/// HUDNotificationManager.shared.updateState(.receiving(elapsedSeconds: 2.3))
/// HUDNotificationManager.shared.updateState(.success)
/// ```
@MainActor
final class HUDNotificationManager {
    // MARK: - Singleton

    static let shared = HUDNotificationManager()

    // MARK: - Properties

    private var hudPanel: NSPanel?
    private var hostingController: NSHostingController<HUDNotificationView>?
    private var dismissTimer: Timer?
    private var elapsedTimer: Timer?
    private var globalEventMonitor: Any?
    private var operationStartTime: Date?

    private var currentTransformationName: String = ""
    private var currentState: HUDState = .starting
    private var onCancelCallback: (() -> Void)?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Shows the HUD with the given transformation name.
    ///
    /// - Parameters:
    ///   - transformationName: Name of the transformation being executed.
    ///   - onCancel: Callback invoked when user presses Esc to cancel.
    func show(transformationName: String, onCancel: @escaping () -> Void) {
        // Clean up any existing HUD
        self.dismissImmediately()

        self.currentTransformationName = transformationName
        self.currentState = .starting
        self.onCancelCallback = onCancel
        self.operationStartTime = Date()

        self.createAndShowPanel()
        self.startGlobalEventMonitor()
    }

    /// Updates the HUD to show a new state.
    ///
    /// If the state is terminal (success, error, cancelled), the HUD will
    /// auto-dismiss after the appropriate delay.
    func updateState(_ state: HUDState) {
        self.currentState = state
        self.refreshView()

        // Stop elapsed timer if we're no longer receiving
        if case .receiving = state {
            // Timer already running, just update view
        } else {
            self.stopElapsedTimer()
        }

        // Start elapsed timer when entering receiving state
        if case .receiving = state, self.elapsedTimer == nil {
            self.startElapsedTimer()
        }

        // Schedule dismiss for terminal states
        if state.isTerminal {
            self.stopElapsedTimer()
            self.stopGlobalEventMonitor()
            self.scheduleDismiss(after: state.dismissDelay)

            // Play sound on success
            if case .success = state {
                SoundManager.shared.playPasteSound()
            }
        }
    }

    /// Dismisses the HUD immediately without animation.
    func dismissImmediately() {
        self.dismissTimer?.invalidate()
        self.dismissTimer = nil
        self.stopElapsedTimer()
        self.stopGlobalEventMonitor()

        self.hudPanel?.close()
        self.hudPanel = nil
        self.hostingController = nil
        self.onCancelCallback = nil
    }

    /// Dismisses the HUD with fade-out animation.
    func dismiss() {
        guard let panel = self.hudPanel else { return }

        self.dismissTimer?.invalidate()
        self.dismissTimer = nil
        self.stopElapsedTimer()
        self.stopGlobalEventMonitor()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: {
            Task { @MainActor [weak self] in
                panel.close()
                self?.hudPanel = nil
                self?.hostingController = nil
                self?.onCancelCallback = nil
            }
        }
    }

    // MARK: - Private Methods

    private func createAndShowPanel() {
        let view = HUDNotificationView(
            transformationName: self.currentTransformationName,
            state: self.currentState,
            onClose: { [weak self] in
                self?.handleCancel()
            }
        )

        let controller = NSHostingController(rootView: view)
        let size = controller.view.fittingSize

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentView = controller.view
        panel.isFloatingPanel = true
        panel.level = .mainMenu
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false

        self.positionPanel(panel)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)

        self.hudPanel = panel
        self.hostingController = controller

        // Fade in
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    private func positionPanel(_ panel: NSPanel) {
        // Get the active screen (where the focused window is, or main screen)
        let activeScreen = NSApp.keyWindow?.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let screenRect = activeScreen.visibleFrame
        let panelSize = panel.frame.size

        // Center horizontally
        let x = screenRect.midX - (panelSize.width / 2)

        // Position near bottom with padding
        let bottomPadding: CGFloat = 80
        let y = screenRect.minY + bottomPadding

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func refreshView() {
        guard let controller = self.hostingController else { return }

        let newView = HUDNotificationView(
            transformationName: self.currentTransformationName,
            state: self.currentState,
            onClose: { [weak self] in
                self?.handleCancel()
            }
        )

        controller.rootView = newView

        // Resize panel to fit new content
        if let panel = self.hudPanel {
            let newSize = controller.view.fittingSize
            var frame = panel.frame
            let oldWidth = frame.width
            frame.size = newSize
            // Keep centered horizontally
            frame.origin.x += (oldWidth - newSize.width) / 2
            panel.setFrame(frame, display: true)
        }
    }

    private func scheduleDismiss(after delay: TimeInterval) {
        self.dismissTimer?.invalidate()
        self.dismissTimer = Timer.scheduledTimer(
            withTimeInterval: delay,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.dismiss()
            }
        }
    }

    // MARK: - Elapsed Timer

    private func startElapsedTimer() {
        self.elapsedTimer = Timer.scheduledTimer(
            withTimeInterval: 0.1,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateElapsedTime()
            }
        }
    }

    private func stopElapsedTimer() {
        self.elapsedTimer?.invalidate()
        self.elapsedTimer = nil
    }

    private func updateElapsedTime() {
        guard let startTime = self.operationStartTime else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        self.currentState = .receiving(elapsedSeconds: elapsed)
        self.refreshView()
    }

    // MARK: - Global Event Monitor (Esc key)

    private func startGlobalEventMonitor() {
        self.globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Esc key code is 53
            if event.keyCode == 53 {
                Task { @MainActor in
                    self?.handleCancel()
                }
            }
        }
    }

    private func stopGlobalEventMonitor() {
        if let monitor = self.globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            self.globalEventMonitor = nil
        }
    }

    private func handleCancel() {
        // Only cancel if we're in a non-terminal state
        guard !self.currentState.isTerminal else { return }

        // Call the cancel callback
        self.onCancelCallback?()

        // Update to cancelled state
        self.updateState(.cancelled)
    }
}
