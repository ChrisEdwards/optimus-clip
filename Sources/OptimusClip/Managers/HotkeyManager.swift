import AppKit
import Combine
import Foundation
import KeyboardShortcuts
import OptimusClipCore
import os.log

private let logger = Logger(subsystem: "com.optimusclip", category: "HotkeyManager")

/// Main manager for registering and handling global hotkeys. MainActor-isolated.
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
    /// Factory for building LLM provider clients (overridable in tests).
    var llmFactory: any LLMProviderClientBuilding = LLMProviderClientFactory()

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

    init(userDefaults: UserDefaults = .standard) {
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

    /// Registers a hotkey handler for a user-created transformation and enables it.
    func register(transformation: TransformationConfig) {
        guard transformation.isEnabled else { return }
        let shortcutName = transformation.shortcutName
        self.transformationsByShortcut[shortcutName] = transformation
        KeyboardShortcuts.onKeyUp(for: shortcutName) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                guard let latest = self.transformationsByShortcut[shortcutName] else { return }
                await self.triggerTransformation(latest)
            }
        }
        self.registeredShortcuts.insert(shortcutName)
        self.activateShortcutBasedOnGlobalState(shortcutName)
    }

    /// Unregisters a hotkey handler for a transformation (call before deleting).
    func unregister(transformation: TransformationConfig) {
        let shortcutName = transformation.shortcutName
        self.disableShortcut(shortcutName)
        KeyboardShortcuts.reset(shortcutName)
        self.registeredShortcuts.remove(shortcutName)
        self.globallySuspendedShortcuts.remove(shortcutName)
        self.transformationsByShortcut.removeValue(forKey: shortcutName)
    }

    /// Registers all transformations from a list (call at app startup).
    func registerAll(transformations: [TransformationConfig]) {
        for transformation in transformations {
            self.register(transformation: transformation)
        }
    }

    /// Unregisters all user transformations (preserves built-in shortcuts).
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

    /// Sets the enabled state for a transformation's hotkey (UI should update config separately).
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

    /// Updates the cached configuration for an already registered transformation.
    ///
    /// Call this after persisting edits made in the Settings UI so future hotkey
    /// invocations use the latest provider/model/prompt values.
    ///
    /// - Parameter transformation: Updated transformation pulled from persistence/UI.
    func updateTransformation(_ transformation: TransformationConfig) {
        self.transformationsByShortcut[transformation.shortcutName] = transformation
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
        self.flowCoordinator.transformationTimeout = self.currentTimeout()

        // Prevent duplicate execution
        guard !self.flowCoordinator.isProcessing else {
            logger.warning("Hotkey ignored - already processing")
            SoundManager.shared.playBeep()
            return
        }

        // Configure pipeline based on which hotkey was pressed
        switch name {
        case .cleanTerminalText:
            logger.debug("Creating Clean Terminal Text LLM pipeline")
            guard let pipeline = self.createCleanTerminalTextPipeline() else {
                logger
                    .error(
                        "Clean Terminal Text failed: No LLM provider configured. Add API key in Settings > Providers."
                    )
                SoundManager.shared.playBeep()
                return
            }
            self.flowCoordinator.pipeline = pipeline
        case .formatAsMarkdown:
            logger.debug("Creating Format As Markdown LLM pipeline")
            guard let pipeline = self.createFormatAsMarkdownPipeline() else {
                logger
                    .error(
                        "Format As Markdown failed: No LLM provider configured. Add API key in Settings > Providers."
                    )
                SoundManager.shared.playBeep()
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

    /// Builds the Clean Terminal Text pipeline using stored settings or a provider fallback.
    func createCleanTerminalTextPipeline() -> TransformationPipeline? {
        self.createBuiltInPipeline(
            id: TransformationConfig.cleanTerminalTextDefaultID,
            pipelineId: "clean-terminal-text-builtin"
        )
    }

    /// Builds the Format As Markdown pipeline using stored settings or a provider fallback.
    func createFormatAsMarkdownPipeline() -> TransformationPipeline? {
        self.createBuiltInPipeline(
            id: TransformationConfig.formatAsMarkdownDefaultID,
            pipelineId: "format-as-markdown-builtin"
        )
    }

    /// Creates a pipeline for a built-in transformation with fallback support.
    private func createBuiltInPipeline(id: UUID, pipelineId: String) -> TransformationPipeline? {
        let factory = self.llmFactory
        guard let stored = self.transformationFromStorage(id: id) else {
            logger.warning("No stored transformation found for \(pipelineId)")
            return nil
        }

        if let pipeline = self.createLLMPipeline(for: stored) {
            logger.info("Using stored transformation for \(pipelineId)")
            return pipeline
        }

        // Fall back to any configured provider while preserving the user's prompt
        guard let configuredClients = try? factory.configuredClients(),
              let (provider, client) = configuredClients.first else {
            logger.warning("No LLM providers configured in Keychain")
            return nil
        }

        logger.info("Using fallback provider: \(provider.rawValue) for \(pipelineId)")
        let model = stored.model ?? Self.defaultModel(for: provider)
        return self.makeLLMPipeline(
            client: client,
            model: model,
            systemPrompt: stored.systemPrompt,
            displayName: stored.name,
            id: pipelineId
        )
    }

    /// Creates an LLM pipeline with the given client and configuration.
    private func makeLLMPipeline(
        client: any LLMProviderClient,
        model: String,
        systemPrompt: String,
        displayName: String,
        id: String
    ) -> TransformationPipeline {
        let timeout = self.currentTimeout()
        let transformation = LLMTransformation(
            id: id,
            displayName: displayName,
            providerClient: client,
            model: model,
            systemPrompt: systemPrompt,
            timeoutSeconds: timeout
        )
        return TransformationPipeline.single(transformation, config: .llm)
    }

    /// Loads the stored Format As Markdown transformation (if available).
    func formatAsMarkdownTransformation() -> TransformationConfig? {
        self.transformationFromStorage(id: TransformationConfig.formatAsMarkdownDefaultID)
    }

    /// Loads the stored Clean Terminal Text transformation (if available).
    func cleanTerminalTextTransformation() -> TransformationConfig? {
        self.transformationFromStorage(id: TransformationConfig.cleanTerminalTextDefaultID)
    }

    private func transformationFromStorage(id: UUID) -> TransformationConfig? {
        guard let transformations = self.loadPersistedTransformations() else {
            return nil
        }
        return transformations.first { $0.id == id }
    }

    private func loadPersistedTransformations() -> [TransformationConfig]? {
        let data = self.userDefaults.data(forKey: SettingsKey.transformationsData)
        do {
            return try TransformationConfig.decodeStoredTransformations(from: data)
        } catch {
            logger.error("Failed to decode transformations_data for hotkeys: \(error.localizedDescription)")
            return nil
        }
    }

    private func currentTimeout() -> TimeInterval {
        let timeoutSeconds = self.userDefaults.double(forKey: SettingsKey.transformationTimeout)
        let effectiveTimeout = timeoutSeconds > 0 ? timeoutSeconds : DefaultSettings.transformationTimeout
        return effectiveTimeout
    }

    /// Returns a reasonable default model for the given provider.
    private static func defaultModel(for provider: LLMProviderKind) -> String {
        ModelResolver.fallbackModel(for: provider) ?? "gpt-4o-mini"
    }

    /// Triggers a transformation from menu items or hotkeys, guarding against duplicate runs.
    @discardableResult
    func triggerTransformation(_ transformation: TransformationConfig) async -> Bool {
        self.flowCoordinator.transformationTimeout = self.currentTimeout()

        // Prevent duplicate execution
        guard !self.flowCoordinator.isProcessing else {
            SoundManager.shared.playBeep()
            return false
        }

        // Skip if transformation is disabled
        guard transformation.isEnabled else {
            return false
        }

        // Always get the latest persisted config for LLM transformations
        var effectiveTransformation = transformation
        if let persisted = self.transformationFromStorage(id: transformation.id) {
            effectiveTransformation = persisted
            // Keep cache aligned with latest persisted data
            self.transformationsByShortcut[transformation.shortcutName] = persisted
        }

        // Configure pipeline - all transformations are now LLM-based
        guard let pipeline = self.createLLMPipeline(for: effectiveTransformation) else {
            // LLM not configured - beep and abort
            SoundManager.shared.playBeep()
            return false
        }
        self.flowCoordinator.pipeline = pipeline

        // Execute the transformation flow
        return await self.flowCoordinator.handleHotkeyTrigger()
    }

    // MARK: - LLM Pipeline Factory

    /// Creates an LLM transformation pipeline from a transformation config.
    ///
    /// - Parameter transformation: The transformation config with LLM settings.
    /// - Returns: A configured pipeline, or `nil` if LLM is not configured.
    func createLLMPipeline(for transformation: TransformationConfig) -> TransformationPipeline? {
        let factory = self.llmFactory
        let resolver = ModelResolver(userDefaults: self.userDefaults)
        guard let resolved = try? factory.client(for: transformation, modelResolver: resolver) else {
            return nil
        }

        let timeoutSeconds = self.userDefaults.double(forKey: SettingsKey.transformationTimeout)
        let effectiveTimeout = timeoutSeconds > 0 ? timeoutSeconds : DefaultSettings.transformationTimeout

        // Create the LLM transformation
        let llmTransformation = LLMTransformation(
            id: "llm-\(transformation.id.uuidString)",
            displayName: transformation.name,
            providerClient: resolved.client,
            model: resolved.resolution.model,
            systemPrompt: transformation.systemPrompt,
            timeoutSeconds: effectiveTimeout
        )

        // Wrap in a pipeline with user-configured timeout
        let config = PipelineConfig(timeout: effectiveTimeout, failFast: true)
        return TransformationPipeline.single(llmTransformation, config: config)
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

    /// Returns the cached transformation configuration for a shortcut name.
    ///
    /// This is primarily for testing to verify cache updates are applied correctly.
    ///
    /// - Parameter name: The keyboard shortcut name to look up.
    /// - Returns: The cached transformation, or nil if not found.
    func getCachedTransformation(for name: KeyboardShortcuts.Name) -> TransformationConfig? {
        self.transformationsByShortcut[name]
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
