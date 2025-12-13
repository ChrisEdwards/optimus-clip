import SwiftUI

/// Tab identifiers for the Settings window.
///
/// Each case represents a distinct settings section with its own UI.
/// The raw value is used for persistence of selected tab state.
enum SettingsTab: String, CaseIterable, Identifiable {
    case transformations
    case providers
    case general
    case permissions

    var id: String { self.rawValue }

    /// Display label for the tab.
    var label: String {
        switch self {
        case .transformations: "Transformations"
        case .providers: "Providers"
        case .general: "General"
        case .permissions: "Permissions"
        }
    }

    /// SF Symbol name for the tab icon.
    var iconName: String {
        switch self {
        case .transformations: "wand.and.stars"
        case .providers: "cloud"
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
/// - **General**: App-wide preferences
/// - **Permissions**: Accessibility permission management
///
/// Window size is fixed at 450x500 to prevent layout issues and follow macOS HIG.
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
        .frame(width: 450, height: 500)
        .fixedSize()
    }
}

#Preview {
    SettingsView()
}
