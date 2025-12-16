import KeyboardShortcuts
import MenuBarExtraAccess
import OptimusClipCore
import SwiftData
import SwiftUI

/// Main entry point for Optimus Clip.
///
/// This menu bar app uses MenuBarExtra to display a clipboard icon
/// in the system menu bar. The app runs as an accessory (no Dock icon)
/// and provides quick access to clipboard transformations via hotkeys.
///
/// ## Scenes
/// - **MenuBarExtra**: Primary menu bar icon with dropdown menu
/// - **Settings**: Native settings window opened via Cmd+, or menu item
@main
struct OptimusClipApp: App {
    /// Bridge to AppKit for setting activation policy and lifecycle events.
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// Observable state manager for menu bar icon appearance.
    @StateObject private var menuBarState = MenuBarStateManager()
    private let historyContainer: ModelContainer
    private let historyStore: HistoryStore

    init() {
        // Migrate any existing Keychain credentials to encrypted storage (one-time)
        EncryptedStorageService.shared.migrateFromKeychain()

        do {
            let container = try HistoryModelContainerFactory.makePersistentContainer()
            self.historyContainer = container
            let entryLimit = UserDefaults.standard.object(forKey: SettingsKey.historyEntryLimit) as? Int
                ?? DefaultSettings.historyEntryLimit
            self.historyStore = HistoryStore(
                container: container,
                configuration: .init(entryLimit: entryLimit)
            )
            TransformationFlowCoordinator.shared.historyStore = self.historyStore
        } catch {
            fatalError("Failed to initialize SwiftData history container: \(error)")
        }
    }

    var body: some Scene {
        // Primary menu bar scene
        MenuBarExtra {
            MenuBarMenuContent()
        } label: {
            self.menuBarIcon
        }
        .menuBarExtraStyle(.menu)
        .menuBarExtraAccess(isPresented: self.$menuBarState.isMenuPresented) { statusItem in
            self.menuBarState.configureStatusItem(statusItem)
        }
        .modelContainer(self.historyContainer)
        .environment(\.historyStore, self.historyStore)

        // Settings window scene (native macOS settings pattern)
        Settings {
            SettingsView()
        }
        .modelContainer(self.historyContainer)
        .environment(\.historyStore, self.historyStore)
    }

    /// Accessibility label describing the current icon state.
    private var accessibilityLabel: String {
        switch self.menuBarState.iconState {
        case .idle:
            "Optimus Clip"
        case .disabled:
            "Optimus Clip (Disabled)"
        }
    }

    /// Accessibility value that surfaces processing state to assistive tech.
    private var processingAccessibilityValue: String? {
        guard self.menuBarState.isProcessing else {
            return nil
        }
        return "Processing transformation"
    }

    /// Menu bar icon view with animation/highlight applied.
    @ViewBuilder
    private var menuBarIcon: some View {
        Image(systemName: "clipboard.fill")
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(
                self.menuBarState.shouldHighlightProcessingIcon ? Color.accentColor : Color.primary
            )
            .opacity(self.menuBarState.iconOpacity)
            .accessibilityLabel(self.accessibilityLabel)
            .optionalAccessibilityValue(self.processingAccessibilityValue)
            .processingPulse(isActive: self.menuBarState.shouldAnimateProcessing)
    }
}

// MARK: - Menu Bar Menu Content

/// Content view for the menu bar dropdown menu.
///
/// Extracted to a separate View to enable use of `@Environment(\.openSettings)`.
@MainActor
private struct MenuBarMenuContent: View {
    /// Environment action to open the Settings window.
    @Environment(\.openSettings) private var openSettings

    /// Stored transformations (JSON-encoded in UserDefaults).
    @AppStorage("transformations_data") private var transformationsData: Data = .init()

    /// Global hotkey manager for toggle binding.
    @ObservedObject private var hotkeyManager = HotkeyManager.shared

    /// Decoded transformations from storage.
    private var transformations: [TransformationConfig] {
        guard !self.transformationsData.isEmpty else {
            return TransformationConfig.defaultTransformations
        }
        return (try? JSONDecoder().decode([TransformationConfig].self, from: self.transformationsData))
            ?? TransformationConfig.defaultTransformations
    }

    /// Enabled transformations only.
    private var enabledTransformations: [TransformationConfig] {
        self.transformations.filter(\.isEnabled)
    }

    /// Binding for the hotkey toggle menu item.
    private var hotkeyToggleBinding: Binding<Bool> {
        Binding(
            get: { self.hotkeyManager.hotkeyListeningEnabled },
            set: { isOn in
                self.hotkeyManager.setHotkeyListeningEnabled(isOn)
            }
        )
    }

    /// Display label for the toggle based on current state.
    private var hotkeyToggleLabel: String {
        self.hotkeyManager.hotkeyListeningEnabled ? "Hotkeys Enabled" : "Hotkeys Paused"
    }

    var body: some View {
        // Transformations submenu
        TransformationsSubmenu(
            enabledTransformations: self.enabledTransformations,
            openSettings: self.openSettings
        )

        Divider()

        Toggle(self.hotkeyToggleLabel, isOn: self.hotkeyToggleBinding)

        Divider()

        Button("Settings...") {
            // Bring app to foreground since we're in accessory mode (no Dock icon)
            NSApp.activate(ignoringOtherApps: true)
            self.openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Quit Optimus Clip") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

// MARK: - Transformations Submenu

/// Submenu showing available transformations with keyboard shortcuts.
@MainActor
private struct TransformationsSubmenu: View {
    let enabledTransformations: [TransformationConfig]
    let openSettings: OpenSettingsAction

    var body: some View {
        Menu("Transformations") {
            if self.enabledTransformations.isEmpty {
                Text("No enabled transformations")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(self.enabledTransformations) { transformation in
                    TransformationMenuItem(transformation: transformation)
                }
            }

            Divider()

            Button("Configure in Settings...") {
                NSApp.activate(ignoringOtherApps: true)
                self.openSettings()
            }
        }
    }
}

// MARK: - Transformation Menu Item

/// Individual menu item for a transformation with keyboard shortcut display.
@MainActor
private struct TransformationMenuItem: View {
    let transformation: TransformationConfig

    /// The keyboard shortcut assigned to this transformation, if any.
    private var shortcut: KeyboardShortcuts.Shortcut? {
        KeyboardShortcuts.getShortcut(for: self.transformation.shortcutName)
    }

    var body: some View {
        Button {
            Task { @MainActor in
                await self.triggerTransformation()
            }
        } label: {
            HStack {
                Text(self.transformation.name)
                Spacer()
                if let shortcut {
                    Text(shortcut.description)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Triggers the transformation via HotkeyManager.
    @MainActor
    private func triggerTransformation() async {
        let hotkeyManager = HotkeyManager.shared
        let flowCoordinator = hotkeyManager.flowCoordinator

        // Prevent duplicate execution
        guard !flowCoordinator.isProcessing else {
            NSSound.beep()
            return
        }

        // Configure pipeline based on transformation type
        switch self.transformation.type {
        case .algorithmic:
            flowCoordinator.pipeline = TransformationPipeline.cleanTerminalText()

        case .llm:
            // LLM transformations require provider configuration
            guard let pipeline = self.createLLMPipeline(for: self.transformation) else {
                NSSound.beep()
                return
            }
            flowCoordinator.pipeline = pipeline
        }

        // Execute the transformation flow
        _ = await flowCoordinator.handleHotkeyTrigger()
    }

    /// Creates an LLM transformation pipeline from a transformation config.
    @MainActor
    private func createLLMPipeline(for transformation: TransformationConfig) -> TransformationPipeline? {
        let factory = LLMProviderClientFactory()
        guard let resolved = try? factory.client(for: transformation) else {
            return nil
        }

        let llmTransformation = LLMTransformation(
            id: "llm-\(transformation.id.uuidString)",
            displayName: transformation.name,
            providerClient: resolved.client,
            model: resolved.resolution.model,
            systemPrompt: transformation.systemPrompt
        )

        return TransformationPipeline.single(llmTransformation, config: .llm)
    }
}

// MARK: - View Helpers

extension View {
    /// Applies the menu bar processing pulse animation when available.
    @ViewBuilder
    fileprivate func processingPulse(isActive: Bool) -> some View {
        if #available(macOS 14.0, *) {
            self.symbolEffect(.pulse, isActive: isActive)
        } else {
            self
        }
    }

    /// Conditionally sets an accessibility value when provided.
    @ViewBuilder
    fileprivate func optionalAccessibilityValue(_ value: String?) -> some View {
        if let value {
            self.accessibilityValue(value)
        } else {
            self
        }
    }
}
