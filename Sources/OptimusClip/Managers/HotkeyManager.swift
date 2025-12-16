import AppKit
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

    /// Set of currently registered shortcut names for tracking.
    private var registeredShortcuts: Set<KeyboardShortcuts.Name> = []

    /// Cache of transformation configs keyed by their shortcut name.
    /// Used to look up the transformation when a hotkey is triggered.
    private var transformationsByShortcut: [KeyboardShortcuts.Name: TransformationConfig] = [:]

    // MARK: - Initialization

    private init() {}

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

        // Format As Markdown: Cmd+Option+S
        KeyboardShortcuts.onKeyUp(for: .formatAsMarkdown) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.handleBuiltInHotkey(.formatAsMarkdown)
            }
        }
        self.registeredShortcuts.insert(.formatAsMarkdown)
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
            return self.makeFormatAsMarkdownPipeline(client: client, model: "claude-3-haiku-20240307")
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
        switch provider {
        case .openAI: "gpt-4o-mini"
        case .anthropic: "claude-3-haiku-20240307"
        case .openRouter: "anthropic/claude-3-haiku"
        case .ollama: "llama3.1"
        case .awsBedrock: "anthropic.claude-3-haiku-20240307-v1:0"
        }
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
        // Validate required LLM configuration
        guard let providerString = transformation.provider,
              let providerKind = LLMProviderKind(rawValue: providerString),
              let model = transformation.model,
              !model.isEmpty else {
            return nil
        }

        // Get the provider client from credentials
        let factory = LLMProviderClientFactory()
        guard let client = try? factory.client(for: providerKind),
              client.isConfigured() else {
            return nil
        }

        // Create the LLM transformation
        let llmTransformation = LLMTransformation(
            id: "llm-\(transformation.id.uuidString)",
            displayName: transformation.name,
            providerClient: client,
            model: model,
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
}
