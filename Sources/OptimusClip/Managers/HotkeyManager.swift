import AppKit
import KeyboardShortcuts
import OptimusClipCore

/// Central manager for global hotkey registration and handling.
///
/// HotkeyManager bridges the KeyboardShortcuts package with the rest of the application,
/// acting as the orchestrator for all hotkey functionality. It handles:
/// - Registering keyboard shortcut handlers with KeyboardShortcuts package
/// - Routing hotkey events to the transformation flow coordinator
/// - Managing transformation execution lifecycle
/// - Preventing duplicate execution during rapid key presses
///
/// ## Usage
/// ```swift
/// // At app startup
/// HotkeyManager.shared.registerBuiltInShortcuts()
///
/// // When user creates a new transformation
/// HotkeyManager.shared.register(transformation: config)
///
/// // When user deletes a transformation
/// HotkeyManager.shared.unregister(transformation: config)
/// ```
///
/// ## Threading
/// All methods are MainActor-isolated for thread safety with UI and KeyboardShortcuts.
@MainActor
final class HotkeyManager: ObservableObject {
    // MARK: - Singleton

    /// Shared instance for global access.
    static let shared = HotkeyManager()

    // MARK: - Dependencies

    /// Reference to the transformation flow coordinator.
    /// Defaults to the shared instance but can be injected for testing.
    var flowCoordinator: TransformationFlowCoordinator = .shared

    // MARK: - State

    /// Set of currently registered shortcut names for tracking.
    private var registeredShortcuts: Set<KeyboardShortcuts.Name> = []

    /// Cache of transformation configs keyed by their shortcut name.
    /// Used to look up the transformation when a hotkey is triggered.
    private var transformationsByShortcut: [KeyboardShortcuts.Name: TransformationConfig] = [:]

    // MARK: - Initialization

    private init() {}

    // MARK: - Built-in Shortcuts

    /// Registers handlers for built-in shortcuts (Quick Fix, Smart Fix).
    ///
    /// Call this once at app startup. The handlers will be active as long as
    /// the app is running.
    func registerBuiltInShortcuts() {
        // Ensure built-in shortcuts have their defaults if not set
        // This handles the case where user cleared the shortcut - reset to default
        self.ensureDefaultShortcut(for: .quickFix)
        self.ensureDefaultShortcut(for: .smartFix)

        // Quick Fix: Cmd+Option+V
        KeyboardShortcuts.onKeyUp(for: .quickFix) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.handleBuiltInHotkey(.quickFix)
            }
        }
        self.registeredShortcuts.insert(.quickFix)

        // Smart Fix: Cmd+Option+S
        KeyboardShortcuts.onKeyUp(for: .smartFix) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.handleBuiltInHotkey(.smartFix)
            }
        }
        self.registeredShortcuts.insert(.smartFix)
    }

    /// Ensures a built-in shortcut has its default value if currently unset.
    ///
    /// When a user clears a shortcut that has a default, KeyboardShortcuts stores
    /// a "disabled" state rather than falling back to the default. This method
    /// resets to the default if no shortcut is currently assigned.
    ///
    /// - Parameter name: The shortcut name to check and potentially reset.
    private func ensureDefaultShortcut(for name: KeyboardShortcuts.Name) {
        if KeyboardShortcuts.getShortcut(for: name) == nil {
            KeyboardShortcuts.reset(name)
        }
    }

    // MARK: - User Transformation Registration

    /// Registers a hotkey handler for a user-created transformation.
    ///
    /// - Parameter transformation: The transformation configuration to register.
    ///
    /// This method:
    /// 1. Skips registration if transformation is disabled
    /// 2. Registers onKeyUp handler with KeyboardShortcuts
    /// 3. Tracks the registration for later cleanup
    /// 4. Enables the shortcut
    ///
    /// ## Important
    /// Use `[weak self]` in the closure to prevent retain cycles.
    func register(transformation: TransformationConfig) {
        guard transformation.isEnabled else { return }

        let shortcutName = transformation.shortcutName

        // Store transformation for lookup when hotkey fires
        self.transformationsByShortcut[shortcutName] = transformation

        // Register handler with KeyboardShortcuts
        KeyboardShortcuts.onKeyUp(for: shortcutName) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.handleUserTransformationHotkey(transformation)
            }
        }

        // Track registration
        self.registeredShortcuts.insert(shortcutName)

        // Enable the shortcut
        KeyboardShortcuts.enable(shortcutName)
    }

    /// Unregisters a hotkey handler for a transformation.
    ///
    /// - Parameter transformation: The transformation configuration to unregister.
    ///
    /// Call this before deleting a transformation to ensure no dangling handlers.
    func unregister(transformation: TransformationConfig) {
        let shortcutName = transformation.shortcutName

        // Disable and reset the shortcut
        KeyboardShortcuts.disable(shortcutName)
        KeyboardShortcuts.reset(shortcutName)

        // Remove from tracking
        self.registeredShortcuts.remove(shortcutName)
        self.transformationsByShortcut.removeValue(forKey: shortcutName)
    }

    /// Registers all transformations from a list.
    ///
    /// - Parameter transformations: Array of transformation configurations.
    ///
    /// Call this at app startup after loading saved transformations.
    func registerAll(transformations: [TransformationConfig]) {
        for transformation in transformations {
            self.register(transformation: transformation)
        }
    }

    /// Unregisters all user transformations.
    ///
    /// This clears all registered user shortcuts but preserves built-in shortcuts.
    func unregisterAllUserTransformations() {
        for (shortcutName, _) in self.transformationsByShortcut {
            KeyboardShortcuts.disable(shortcutName)
            KeyboardShortcuts.reset(shortcutName)
            self.registeredShortcuts.remove(shortcutName)
        }
        self.transformationsByShortcut.removeAll()
    }

    // MARK: - Enable/Disable

    /// Sets the enabled state for a transformation's hotkey.
    ///
    /// - Parameters:
    ///   - enabled: Whether to enable or disable the hotkey.
    ///   - transformation: The transformation whose hotkey to update.
    ///
    /// This only affects the hotkey registration, not the transformation config itself.
    /// The UI should update the config's `isEnabled` property separately.
    func setEnabled(_ enabled: Bool, for transformation: TransformationConfig) {
        let shortcutName = transformation.shortcutName

        if enabled {
            // Re-register if not already registered
            if !self.registeredShortcuts.contains(shortcutName) {
                self.register(transformation: transformation)
            } else {
                KeyboardShortcuts.enable(shortcutName)
            }
        } else {
            KeyboardShortcuts.disable(shortcutName)
        }
    }

    // MARK: - Hotkey Handlers

    /// Handles a built-in hotkey trigger (Quick Fix or Smart Fix).
    ///
    /// - Parameter name: The KeyboardShortcuts.Name that was triggered.
    private func handleBuiltInHotkey(_ name: KeyboardShortcuts.Name) async {
        // Prevent duplicate execution
        guard !self.flowCoordinator.isProcessing else {
            NSSound.beep()
            return
        }

        // Configure pipeline based on which hotkey was pressed
        switch name {
        case .quickFix:
            // Quick Fix: strip whitespace + smart unwrap
            self.flowCoordinator.pipeline = TransformationPipeline.quickFix()
        case .smartFix:
            // Smart Fix: future LLM-based transformation (Phase 5)
            // For now, use same as Quick Fix
            self.flowCoordinator.pipeline = TransformationPipeline.quickFix()
        default:
            // Unknown built-in shortcut, use identity (no-op)
            self.flowCoordinator.pipeline = nil
        }

        // Execute the transformation flow
        _ = await self.flowCoordinator.handleHotkeyTrigger()
    }

    /// Handles a user-created transformation hotkey trigger.
    ///
    /// - Parameter transformation: The transformation configuration that was triggered.
    private func handleUserTransformationHotkey(_ transformation: TransformationConfig) async {
        // Prevent duplicate execution
        guard !self.flowCoordinator.isProcessing else {
            NSSound.beep()
            return
        }

        // Skip if transformation is disabled
        guard transformation.isEnabled else {
            return
        }

        // Configure pipeline based on transformation config
        // For now, all user transformations use the quickFix pipeline
        // Phase 5 will add LLM-based transformations with custom pipelines
        self.flowCoordinator.pipeline = TransformationPipeline.quickFix()

        // Execute the transformation flow
        _ = await self.flowCoordinator.handleHotkeyTrigger()
    }

    // MARK: - Query Methods

    /// Returns whether a shortcut is currently registered.
    ///
    /// - Parameter name: The shortcut name to check.
    /// - Returns: `true` if the shortcut is registered with this manager.
    func isRegistered(_ name: KeyboardShortcuts.Name) -> Bool {
        self.registeredShortcuts.contains(name)
    }

    /// Returns the count of registered shortcuts.
    var registeredCount: Int {
        self.registeredShortcuts.count
    }
}
