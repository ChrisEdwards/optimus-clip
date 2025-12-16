import AppKit
import Combine
import Foundation
import KeyboardShortcuts
import OptimusClipCore
import os.log

private let logger = Logger(subsystem: "com.optimusclip", category: "HotkeyManager")

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

    /// Whether global hotkey listening is currently enabled.
    @Published private(set) var hotkeyListeningEnabled: Bool

    /// Persistent storage for the listening flag.
    private let userDefaults: UserDefaults

    /// Set of shortcut names with registered handlers.
    private var registeredShortcuts: Set<KeyboardShortcuts.Name> = []

    /// Subset of registered shortcuts that are currently active/enabled.
    private var activeShortcuts: Set<KeyboardShortcuts.Name> = []

    /// Shortcuts that should resume once global listening is re-enabled.
    private var globallySuspendedShortcuts: Set<KeyboardShortcuts.Name> = []

    /// Cache of transformation configs keyed by their shortcut name.
    /// Used to look up the transformation when a hotkey is triggered.
    private var transformationsByShortcut: [KeyboardShortcuts.Name: TransformationConfig] = [:]

    // MARK: - Initialization

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let stored = userDefaults.object(forKey: SettingsKey.hotkeyListeningEnabled) as? Bool {
            self.hotkeyListeningEnabled = stored
        } else {
            self.hotkeyListeningEnabled = DefaultSettings.hotkeyListeningEnabled
        }
    }

    // MARK: - Built-in Shortcuts

    /// Registers handlers for built-in shortcuts (Clean Terminal Text, Format As Markdown).
    ///
    /// Call this once at app startup. The handlers will be active as long as
    /// the app is running.
    func registerBuiltInShortcuts() {
        // Ensure built-in shortcuts have their defaults if not set
        // This handles the case where user cleared the shortcut - reset to default
        self.ensureDefaultShortcut(for: .cleanTerminalText)
        self.ensureDefaultShortcut(for: .formatAsMarkdown)

        // Clean Terminal Text: Cmd+Option+V
        KeyboardShortcuts.onKeyUp(for: .cleanTerminalText) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.handleBuiltInHotkey(.cleanTerminalText)
            }
        }
        self.registeredShortcuts.insert(.cleanTerminalText)
        self.activateShortcutBasedOnGlobalState(.cleanTerminalText)

        // Format As Markdown: Cmd+Option+S
        KeyboardShortcuts.onKeyUp(for: .formatAsMarkdown) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.handleBuiltInHotkey(.formatAsMarkdown)
            }
        }
        self.registeredShortcuts.insert(.formatAsMarkdown)
        self.activateShortcutBasedOnGlobalState(.formatAsMarkdown)
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

        // Enable shortcut if global listening is active, otherwise keep suspended
        self.activateShortcutBasedOnGlobalState(shortcutName)
    }

    /// Unregisters a hotkey handler for a transformation.
    ///
    /// - Parameter transformation: The transformation configuration to unregister.
    ///
    /// Call this before deleting a transformation to ensure no dangling handlers.
    func unregister(transformation: TransformationConfig) {
        let shortcutName = transformation.shortcutName

        // Disable and reset the shortcut
        self.disableShortcut(shortcutName)
        KeyboardShortcuts.reset(shortcutName)

        // Remove from tracking
        self.registeredShortcuts.remove(shortcutName)
        self.globallySuspendedShortcuts.remove(shortcutName)
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
            self.disableShortcut(shortcutName)
            KeyboardShortcuts.reset(shortcutName)
            self.registeredShortcuts.remove(shortcutName)
            self.globallySuspendedShortcuts.remove(shortcutName)
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
                self.activateShortcutBasedOnGlobalState(shortcutName)
            }
        } else {
            self.disableShortcut(shortcutName)
            self.globallySuspendedShortcuts.remove(shortcutName)
        }
    }

    // MARK: - Global Listening Control

    /// Enables or disables all hotkey handling at once.
    ///
    /// Disabling releases the shortcuts so other apps can use them.
    /// Enabling restores only the shortcuts that were previously active.
    func setHotkeyListeningEnabled(_ enabled: Bool) {
        guard self.hotkeyListeningEnabled != enabled else { return }
        self.hotkeyListeningEnabled = enabled
        self.userDefaults.set(enabled, forKey: SettingsKey.hotkeyListeningEnabled)

        if enabled {
            self.restoreShortcutsAfterGlobalToggle()
        } else {
            self.suspendShortcutsForGlobalToggle()
        }
    }

    // MARK: - Hotkey Handlers

    /// Handles a built-in hotkey trigger (Clean Terminal Text or Format As Markdown).
    ///
    /// - Parameter name: The KeyboardShortcuts.Name that was triggered.
    private func handleBuiltInHotkey(_ name: KeyboardShortcuts.Name) async {
        logger.info("Built-in hotkey triggered: \(name.rawValue)")

        // Prevent duplicate execution
        guard !self.flowCoordinator.isProcessing else {
            logger.warning("Hotkey ignored - already processing")
            NSSound.beep()
            return
        }

        // Configure pipeline based on which hotkey was pressed
        switch name {
        case .cleanTerminalText:
            logger.debug("Using Clean Terminal Text pipeline")
            self.flowCoordinator.pipeline = TransformationPipeline.cleanTerminalText()
        case .formatAsMarkdown:
            logger.debug("Creating Format As Markdown LLM pipeline")
            guard let pipeline = self.createFormatAsMarkdownPipeline() else {
                logger
                    .error(
                        "Format As Markdown failed: No LLM provider configured. Add API key in Settings > Providers."
                    )
                NSSound.beep()
                return
            }
            self.flowCoordinator.pipeline = pipeline
        default:
            logger.warning("Unknown built-in shortcut: \(name.rawValue)")
            self.flowCoordinator.pipeline = nil
        }

        // Execute the transformation flow
        logger.debug("Executing transformation flow")
        _ = await self.flowCoordinator.handleHotkeyTrigger()
    }

    /// Creates the default Format As Markdown LLM pipeline.
    ///
    /// Uses Anthropic Claude as the default provider with a markdown formatting prompt.
    /// Falls back to the first configured LLM provider if Anthropic is not available.
    ///
    /// - Returns: A configured LLM pipeline, or `nil` if no LLM provider is configured.
    private func createFormatAsMarkdownPipeline() -> TransformationPipeline? {
        let factory = LLMProviderClientFactory()

        // Try the default provider (Anthropic) first
        if let client = try? factory.client(for: .anthropic), client.isConfigured() {
            logger.info("Using Anthropic for Format As Markdown")
            let model = ModelResolver.fallbackModel(for: .anthropic) ?? "claude-3-5-sonnet-20241022"
            return self.makeFormatAsMarkdownPipeline(client: client, model: model)
        }
        logger.debug("Anthropic not configured, checking other providers")

        // Fall back to any configured provider
        guard let configuredClients = try? factory.configuredClients(),
              let (provider, client) = configuredClients.first else {
            logger.warning("No LLM providers configured in Keychain")
            return nil
        }

        logger.info("Using fallback provider: \(provider.rawValue)")
        return self.makeFormatAsMarkdownPipeline(client: client, model: Self.defaultModel(for: provider))
    }

    /// Creates an LLM pipeline for Format As Markdown with the given client and model.
    private func makeFormatAsMarkdownPipeline(client: any LLMProviderClient, model: String) -> TransformationPipeline {
        let prompt = "Format the following text as clean, well-structured Markdown. " +
            "Use appropriate headers, lists, code blocks, and emphasis where applicable. " +
            "Fix any grammar or spelling issues while preserving the original meaning."
        let transformation = LLMTransformation(
            id: "format-as-markdown-builtin",
            displayName: "Format As Markdown",
            providerClient: client,
            model: model,
            systemPrompt: prompt
        )
        return TransformationPipeline.single(transformation, config: .llm)
    }

    /// Returns a reasonable default model for the given provider.
    private static func defaultModel(for provider: LLMProviderKind) -> String {
        ModelResolver.fallbackModel(for: provider) ?? "gpt-4o-mini"
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

        // Configure pipeline based on transformation type
        switch transformation.type {
        case .algorithmic:
            // Algorithmic transformations use the cleanTerminalText pipeline
            self.flowCoordinator.pipeline = TransformationPipeline.cleanTerminalText()

        case .llm:
            // LLM transformations require provider configuration
            guard let pipeline = self.createLLMPipeline(for: transformation) else {
                // LLM not configured - beep and abort
                NSSound.beep()
                return
            }
            self.flowCoordinator.pipeline = pipeline
        }

        // Execute the transformation flow
        _ = await self.flowCoordinator.handleHotkeyTrigger()
    }

    // MARK: - LLM Pipeline Factory

    /// Creates an LLM transformation pipeline from a transformation config.
    ///
    /// - Parameter transformation: The transformation config with LLM settings.
    /// - Returns: A configured pipeline, or `nil` if LLM is not configured.
    private func createLLMPipeline(for transformation: TransformationConfig) -> TransformationPipeline? {
        let factory = LLMProviderClientFactory()
        guard let resolved = try? factory.client(for: transformation) else {
            return nil
        }

        // Create the LLM transformation
        let llmTransformation = LLMTransformation(
            id: "llm-\(transformation.id.uuidString)",
            displayName: transformation.name,
            providerClient: resolved.client,
            model: resolved.resolution.model,
            systemPrompt: transformation.systemPrompt
        )

        // Wrap in a pipeline with LLM-appropriate timeout
        return TransformationPipeline.single(llmTransformation, config: .llm)
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

    // MARK: - Private Helpers

    /// Enables the shortcut immediately or schedules it once global listening resumes.
    private func activateShortcutBasedOnGlobalState(_ shortcutName: KeyboardShortcuts.Name) {
        if self.hotkeyListeningEnabled {
            self.enableShortcut(shortcutName)
        } else {
            self.globallySuspendedShortcuts.insert(shortcutName)
            self.disableShortcut(shortcutName)
        }
    }

    private func enableShortcut(_ shortcutName: KeyboardShortcuts.Name) {
        KeyboardShortcuts.enable(shortcutName)
        self.activeShortcuts.insert(shortcutName)
        self.globallySuspendedShortcuts.remove(shortcutName)
    }

    private func disableShortcut(_ shortcutName: KeyboardShortcuts.Name) {
        KeyboardShortcuts.disable(shortcutName)
        self.activeShortcuts.remove(shortcutName)
    }

    private func suspendShortcutsForGlobalToggle() {
        let currentlyActive = self.activeShortcuts
        self.globallySuspendedShortcuts.formUnion(currentlyActive)
        for name in currentlyActive {
            self.disableShortcut(name)
        }
    }

    private func restoreShortcutsAfterGlobalToggle() {
        for name in self.globallySuspendedShortcuts where self.registeredShortcuts.contains(name) {
            self.enableShortcut(name)
        }
        self.globallySuspendedShortcuts.removeAll()
    }
}
