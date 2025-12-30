import Foundation
import Sparkle

/// Wrapper that conditionally enables Sparkle only for signed, bundled production builds.
///
/// This prevents update dialogs and errors during development while ensuring
/// production builds automatically check for and install updates.
///
/// ## Behavior by Scenario
/// | Scenario | Updates Enabled |
/// |----------|-----------------|
/// | `swift run` | No |
/// | Debug .app (unsigned) | No |
/// | Debug .app (ad-hoc signed) | No |
/// | Release .app (Developer ID) | Yes |
///
/// ## Usage
/// ```swift
/// @StateObject private var updaterWrapper = UpdaterWrapper()
///
/// if updaterWrapper.canCheckForUpdates {
///     Button("Check for Updates...") {
///         updaterWrapper.checkForUpdates()
///     }
/// }
/// ```
@MainActor
final class UpdaterWrapper: ObservableObject {
    // MARK: - Configuration

    /// Info.plist key that should contain the Developer Team ID.
    /// Set via build setting: `SUDeveloperTeamID = $(DEVELOPMENT_TEAM)`
    private nonisolated(unsafe) static let developerTeamIDKey = "SUDeveloperTeamID"

    // MARK: - Properties

    /// The Sparkle updater controller (nil if updates disabled)
    private var controller: SPUStandardUpdaterController?

    /// The underlying Sparkle updater for advanced operations
    var updater: SPUUpdater? { self.controller?.updater }

    /// Whether update checking is available (false during development)
    @Published private(set) var canCheckForUpdates: Bool = false
    private let bundle: Bundle
    private let teamID: String?

    // MARK: - Initialization

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        self.teamID = Self.teamID(from: bundle)

        guard self.shouldEnableUpdater() else {
            print("[UpdaterWrapper] Updates disabled (development build)")
            return
        }

        self.controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.canCheckForUpdates = true
        print("[UpdaterWrapper] Updates enabled (production build)")
    }

    // MARK: - Public API

    /// Check for updates and show UI if available
    func checkForUpdates() {
        guard let updater = self.updater else { return }
        updater.checkForUpdates()
    }

    /// Check for updates silently in the background
    func checkForUpdatesInBackground() {
        guard let updater = self.updater else { return }
        updater.checkForUpdatesInBackground()
    }

    // MARK: - Private Methods

    /// Determine if Sparkle should be enabled based on runtime conditions
    private func shouldEnableUpdater() -> Bool {
        // Condition 1: Must be running as an app bundle
        guard self.bundle.bundleURL.pathExtension == "app" else {
            print("[UpdaterWrapper] Not an app bundle")
            return false
        }

        // Condition 2: Team ID must be provided and not a placeholder
        guard let teamID = self.teamID else {
            print("[UpdaterWrapper] Missing or placeholder Developer Team ID")
            return false
        }

        // Condition 2: Must be signed with Developer ID
        guard self.isSignedWithDeveloperID(self.bundle.bundleURL, teamID: teamID) else {
            print("[UpdaterWrapper] Not signed with Developer ID")
            return false
        }

        return true
    }

    /// Verify the app is signed with our Developer ID certificate
    private func isSignedWithDeveloperID(_ url: URL, teamID: String) -> Bool {
        var code: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(url as CFURL, [], &code)

        guard createStatus == errSecSuccess, let staticCode = code else {
            return false
        }

        // Requirement: Signed by Apple and our specific team
        let requirement = "anchor apple generic and certificate leaf[subject.OU] = \"\(teamID)\""

        var req: SecRequirement?
        guard SecRequirementCreateWithString(requirement as CFString, [], &req) == errSecSuccess,
              let secRequirement = req else {
            return false
        }

        return SecStaticCodeCheckValidity(staticCode, [], secRequirement) == errSecSuccess
    }

    /// Reads and normalizes the Developer Team ID from a bundle.
    nonisolated static func teamID(from bundle: Bundle) -> String? {
        let rawValue = bundle.object(forInfoDictionaryKey: Self.developerTeamIDKey) as? String
        return Self.normalizedTeamID(rawValue)
    }

    /// Normalizes a raw Team ID string and discards placeholders.
    nonisolated static func normalizedTeamID(_ rawValue: String?) -> String? {
        guard let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }

        let uppercased = trimmed.uppercased()
        if trimmed.contains("$(") || uppercased == "YOUR_TEAM_ID" || uppercased == "CHANGE_ME" {
            return nil
        }

        return trimmed
    }
}
