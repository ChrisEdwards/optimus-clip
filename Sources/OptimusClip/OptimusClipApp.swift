import KeyboardShortcuts
import MenuBarExtraAccess
import OptimusClipCore
import Sparkle
import SwiftData
import SwiftUI

/// Main entry point for Optimus Clip.
@main
struct OptimusClipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var menuBarState = MenuBarStateManager()
    @StateObject private var updaterWrapper = UpdaterWrapper()

    /// Model cache for settings window session.
    @State private var modelCache = ModelCache()

    private let historyContainer: ModelContainer
    private let historyStore: HistoryStore

    /// Menu bar icon loaded from bundle resources, configured as template image.
    private static let menuBarIcon: NSImage? = {
        guard let url = Bundle.module.url(forResource: "MenuBarIcon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        image.isTemplate = true
        return image
    }()

    init() {
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
        MenuBarExtra {
            MenuBarMenuContent(updaterWrapper: self.updaterWrapper)
        } label: {
            if let icon = Self.menuBarIcon {
                Image(nsImage: icon)
                    .opacity(self.menuBarState.iconOpacity)
            } else {
                Image(systemName: "clipboard.fill")
                    .opacity(self.menuBarState.iconOpacity)
            }
        }
        .menuBarExtraStyle(.menu)
        .menuBarExtraAccess(isPresented: self.$menuBarState.isMenuPresented) { statusItem in
            self.menuBarState.configureStatusItem(statusItem)
        }
        .modelContainer(self.historyContainer)
        .environment(\.historyStore, self.historyStore)

        Settings {
            SettingsView()
                .onAppear { self.modelCache = ModelCache() }
        }
        .modelContainer(self.historyContainer)
        .environment(\.historyStore, self.historyStore)
        .environment(\.modelCache, self.modelCache)
    }
}

// MARK: - Menu Bar Menu Content

/// Content view for the menu bar dropdown menu.
private struct MenuBarMenuContent: View {
    @ObservedObject var updaterWrapper: UpdaterWrapper
    @Environment(\.openSettings) private var openSettings
    @AppStorage("transformations_data") private var transformationsData: Data = .init()

    private var transformations: [TransformationConfig] {
        guard !self.transformationsData.isEmpty else {
            return TransformationConfig.defaultTransformations
        }
        return (try? JSONDecoder().decode([TransformationConfig].self, from: self.transformationsData))
            ?? TransformationConfig.defaultTransformations
    }

    private var enabledTransformations: [TransformationConfig] {
        self.transformations.filter(\.isEnabled)
    }

    var body: some View {
        TransformationsSubmenu(
            enabledTransformations: self.enabledTransformations,
            openSettings: self.openSettings
        )

        Divider()

        // Only show "Check for Updates" if Sparkle is enabled (production builds)
        if self.updaterWrapper.canCheckForUpdates {
            Button("Check for Updates...") {
                self.updaterWrapper.checkForUpdates()
            }
        }

        Button("Settings...") {
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

private struct TransformationMenuItem: View {
    let transformation: TransformationConfig

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

    @MainActor
    private func triggerTransformation() async {
        let hotkeyManager = HotkeyManager.shared
        let flowCoordinator = hotkeyManager.flowCoordinator

        guard !flowCoordinator.isProcessing else {
            SoundManager.shared.playBeep()
            return
        }

        switch self.transformation.type {
        case .algorithmic:
            flowCoordinator.pipeline = TransformationPipeline.cleanTerminalText()

        case .llm:
            guard let pipeline = self.createLLMPipeline(for: self.transformation) else {
                SoundManager.shared.playBeep()
                return
            }
            flowCoordinator.pipeline = pipeline
        }

        _ = await flowCoordinator.handleHotkeyTrigger()
    }

    @MainActor
    private func createLLMPipeline(for transformation: TransformationConfig) -> TransformationPipeline? {
        guard let providerString = transformation.provider,
              let providerKind = LLMProviderKind(rawValue: providerString),
              let model = transformation.model,
              !model.isEmpty else {
            return nil
        }

        let factory = LLMProviderClientFactory()
        guard let client = try? factory.client(for: providerKind),
              client.isConfigured() else {
            return nil
        }

        let timeoutSeconds = UserDefaults.standard.double(forKey: SettingsKey.transformationTimeout)
        let effectiveTimeout = timeoutSeconds > 0 ? timeoutSeconds : DefaultSettings.transformationTimeout

        let llmTransformation = LLMTransformation(
            id: "llm-\(transformation.id.uuidString)",
            displayName: transformation.name,
            providerClient: client,
            model: model,
            systemPrompt: transformation.systemPrompt,
            timeoutSeconds: effectiveTimeout
        )

        return TransformationPipeline.single(llmTransformation, config: .llm)
    }
}
