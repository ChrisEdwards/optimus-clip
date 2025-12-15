import AppKit
import OptimusClipCore
import OSLog
import ServiceManagement
import SwiftUI

private let logger = Logger(subsystem: "com.optimusclip", category: "GeneralSettings")

/// General settings tab containing app-wide preferences.
///
/// Provides settings that don't fit into other categories:
/// - Launch at Login: Auto-start when user logs in
/// - Sound Effects: Audio feedback for transformations
/// - Transformation Timeout: Maximum wait time for LLM responses
/// - About: Version info and links
struct GeneralTabView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("soundEffectsEnabled") private var soundEffectsEnabled = true
    @AppStorage("transformationTimeout") private var transformationTimeout = 30.0

    @State private var loginItemStatus: SMAppService.Status = .notRegistered

    var body: some View {
        Form {
            Section("Startup") {
                LaunchAtLoginToggle(
                    isEnabled: self.$launchAtLogin,
                    status: self.$loginItemStatus
                )
            }

            Section("User Interface") {
                Toggle("Sound Effects", isOn: self.$soundEffectsEnabled)
                    .help("Play audio feedback when transformations succeed or fail")
            }

            Section("Performance") {
                TransformationTimeoutPicker(timeout: self.$transformationTimeout)
            }

            Section("History") {
                HistorySettingsSection()
            }

            Section("About") {
                AboutSection()
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            self.updateLoginItemStatus()
        }
    }

    private func updateLoginItemStatus() {
        self.loginItemStatus = SMAppService.mainApp.status
        // Sync AppStorage with actual system state (user may have changed in System Settings)
        let actuallyEnabled = self.loginItemStatus == .enabled
        if self.launchAtLogin != actuallyEnabled {
            self.launchAtLogin = actuallyEnabled
        }
    }
}

// MARK: - Launch at Login Toggle

/// Toggle control for managing Launch at Login with status indicator.
///
/// Uses SMAppService (macOS 13+) for login item management.
/// Shows status and provides deep link to System Settings when approval is required.
struct LaunchAtLoginToggle: View {
    @Binding var isEnabled: Bool
    @Binding var status: SMAppService.Status

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Launch at Login", isOn: self.$isEnabled)
                .onChange(of: self.isEnabled) { _, newValue in
                    self.setLaunchAtLogin(newValue)
                }

            self.statusIndicator
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch self.status {
        case .enabled:
            Label("Enabled", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
        case .requiresApproval:
            VStack(alignment: .leading, spacing: 4) {
                Label(
                    "Requires Approval in System Settings",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundColor(.orange)

                Button("Open System Settings") {
                    self.openLoginItems()
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        case .notRegistered:
            Label("Not Registered", systemImage: "circle")
                .font(.caption)
                .foregroundColor(.secondary)
        case .notFound:
            Label("App Bundle Not Found", systemImage: "exclamationmark.circle")
                .font(.caption)
                .foregroundColor(.red)
        @unknown default:
            EmptyView()
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }

            // Status doesn't update immediately - check after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.status = SMAppService.mainApp.status
            }
        } catch {
            logger.error("Failed to \(enabled ? "enable" : "disable") launch at login: \(error.localizedDescription)")
            // Revert toggle on failure
            self.isEnabled = !enabled
        }
    }

    private func openLoginItems() {
        // macOS 13+: Open Login Items in System Settings
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Transformation Timeout Picker

/// Picker for selecting transformation timeout duration.
///
/// Provides discrete sensible options rather than free-form input
/// to prevent invalid configurations.
struct TransformationTimeoutPicker: View {
    @Binding var timeout: Double

    private let timeoutOptions: [Double] = [15, 30, 45, 60, 90, 120]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Transformation Timeout:")

                Picker("", selection: self.$timeout) {
                    ForEach(self.timeoutOptions, id: \.self) { seconds in
                        Text("\(Int(seconds)) seconds").tag(seconds)
                    }
                }
                .labelsHidden()
                .frame(width: 150)
            }

            Text("Maximum time to wait for LLM responses before failing")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - About Section

/// Displays app version info and useful links.
struct AboutSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Version:")
                    .foregroundColor(.secondary)
                Text(Bundle.main.appVersion)
            }

            HStack {
                Text("Build:")
                    .foregroundColor(.secondary)
                Text(Bundle.main.appBuild)
            }

            HStack(spacing: 16) {
                Button("View on GitHub") {
                    if let url = URL(string: "https://github.com/optimusclip/optimus-clip") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)

                Button("Report Issue") {
                    if let url = URL(string: "https://github.com/optimusclip/optimus-clip/issues") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
            }
        }
    }
}

// MARK: - History Section

private struct HistorySettingsSection: View {
    @Environment(\.historyStore) private var historyStore
    @AppStorage(SettingsKey.historyEntryLimit) private var entryLimit = DefaultSettings.historyEntryLimit

    @State private var recentEntries: [HistoryRecord] = []
    @State private var isLoading = false
    @State private var loadError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Stepper(value: self.$entryLimit, in: 25 ... 500, step: 25) {
                Text("Store up to \(self.entryLimit) entries")
            }
            .onChange(of: self.entryLimit) { _, newValue in
                Task {
                    await self.setEntryLimitOnStore(newValue, reload: true)
                }
            }

            Text("Oldest entries are pruned automatically once the limit is reached.")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            HStack {
                Text("Recent Transformations")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Button("Refresh") {
                    Task {
                        await self.refreshHistory()
                    }
                }
                .disabled(self.isLoading)
            }

            if self.isLoading {
                ProgressView()
            } else if let loadError {
                Text(loadError)
                    .font(.caption)
                    .foregroundColor(.red)
            } else if self.recentEntries.isEmpty {
                Text("No history yet. Trigger a transformation to populate this list.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(self.recentEntries.prefix(5)) { entry in
                        HistoryEntryRow(entry: entry)
                        if entry.id != self.recentEntries.prefix(5).last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .task {
            await self.setEntryLimitOnStore(self.entryLimit, reload: false)
            await self.refreshHistory()
        }
    }

    private func setEntryLimitOnStore(_ value: Int, reload: Bool) async {
        do {
            try await self.historyStore.updateEntryLimit(value)
            if reload {
                await self.refreshHistory()
            }
        } catch {
            await MainActor.run {
                self.loadError = "Failed to update history limit: \(error.localizedDescription)"
            }
        }
    }

    private func refreshHistory() async {
        await MainActor.run {
            self.isLoading = true
            self.loadError = nil
        }

        do {
            let entries = try await self.historyStore.fetchRecent(limit: 5)
            await MainActor.run {
                self.recentEntries = entries
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.loadError = "Unable to load history: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

private struct HistoryEntryRow: View {
    let entry: HistoryRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(self.entry.transformationName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(self.entry.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let provider = entry.providerName {
                Text("\(provider.uppercased()) · \(self.entry.modelUsed ?? "Unknown Model")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(self.previewText)
                .font(.caption)
                .lineLimit(2)
                .foregroundColor(.secondary)

            Text("\(self.entry.inputCharCount) chars · \(self.entry.processingTimeMs) ms")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var previewText: String {
        let text = self.entry.outputText.isEmpty ? self.entry.inputText : self.entry.outputText
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Bundle Extensions

extension Bundle {
    /// Marketing version string (e.g., "1.0.0").
    var appVersion: String {
        self.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    /// Build number string (e.g., "42").
    var appBuild: String {
        self.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}

// MARK: - Preview

#Preview {
    GeneralTabView()
        .frame(width: 450, height: 500)
}
