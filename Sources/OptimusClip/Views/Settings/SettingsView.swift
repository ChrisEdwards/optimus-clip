import SwiftUI

/// Tab identifiers for the Settings window.
///
/// Each case represents a distinct settings section with its own UI.
/// The raw value is used for persistence of selected tab state.
enum SettingsTab: String, CaseIterable, Identifiable {
    case transformations
    case providers
    case history
    case general
    case permissions

    var id: String { self.rawValue }

    /// Display label for the tab.
    var label: String {
        switch self {
        case .transformations: "Transformations"
        case .providers: "Providers"
        case .history: "History"
        case .general: "General"
        case .permissions: "Permissions"
        }
    }

    /// SF Symbol name for the tab icon.
    var iconName: String {
        switch self {
        case .transformations: "wand.and.stars"
        case .providers: "cloud"
        case .history: "clock.arrow.circlepath"
        case .general: "gearshape"
        case .permissions: "lock.shield"
        }
    }
}

/// Main settings window view with tabbed navigation.
///
/// Provides access to all Optimus Clip configuration sections:
/// - **Transformations**: Create and edit clipboard transformation rules
/// - **Providers**: Configure LLM API credentials
/// - **History**: Browse and search transformation history
/// - **General**: App-wide preferences
/// - **Permissions**: Accessibility permission management
///
/// Window is resizable with reasonable bounds. macOS automatically persists window size.
struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .transformations

    var body: some View {
        TabView(selection: self.$selectedTab) {
            TransformationsTabView()
                .tabItem {
                    Label(SettingsTab.transformations.label, systemImage: SettingsTab.transformations.iconName)
                }
                .tag(SettingsTab.transformations)

            ProvidersTabView()
                .tabItem {
                    Label(SettingsTab.providers.label, systemImage: SettingsTab.providers.iconName)
                }
                .tag(SettingsTab.providers)

            HistoryTabView()
                .tabItem {
                    Label(SettingsTab.history.label, systemImage: SettingsTab.history.iconName)
                }
                .tag(SettingsTab.history)

            GeneralTabView()
                .tabItem {
                    Label(SettingsTab.general.label, systemImage: SettingsTab.general.iconName)
                }
                .tag(SettingsTab.general)

            PermissionsTabView()
                .tabItem {
                    Label(SettingsTab.permissions.label, systemImage: SettingsTab.permissions.iconName)
                }
                .tag(SettingsTab.permissions)
        }
        .frame(
            minWidth: 550,
            idealWidth: 650,
            maxWidth: 900,
            minHeight: 400,
            idealHeight: 550,
            maxHeight: 750
        )
    }
}

#Preview {
    SettingsView()
}
