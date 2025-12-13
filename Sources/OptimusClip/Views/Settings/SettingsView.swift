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
            TransformationsPlaceholderView()
                .tabItem {
                    Label(SettingsTab.transformations.label, systemImage: SettingsTab.transformations.iconName)
                }
                .tag(SettingsTab.transformations)

            ProvidersPlaceholderView()
                .tabItem {
                    Label(SettingsTab.providers.label, systemImage: SettingsTab.providers.iconName)
                }
                .tag(SettingsTab.providers)

            GeneralTabView()
                .tabItem {
                    Label(SettingsTab.general.label, systemImage: SettingsTab.general.iconName)
                }
                .tag(SettingsTab.general)

            PermissionsPlaceholderView()
                .tabItem {
                    Label(SettingsTab.permissions.label, systemImage: SettingsTab.permissions.iconName)
                }
                .tag(SettingsTab.permissions)
        }
        .frame(width: 450, height: 500)
        .fixedSize()
    }
}

// MARK: - Placeholder Views

/// Placeholder for Transformations tab (oc-4tw.4).
struct TransformationsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Transformations")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Create and edit clipboard transformation rules.\nImplemented in oc-4tw.4.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Placeholder for Providers tab (oc-4tw.5).
struct ProvidersPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cloud")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Providers")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Configure LLM API credentials.\nImplemented in oc-4tw.5.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Placeholder for Permissions tab (oc-4tw.7).
struct PermissionsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Permissions")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Accessibility permission management.\nImplemented in oc-4tw.7.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SettingsView()
}
