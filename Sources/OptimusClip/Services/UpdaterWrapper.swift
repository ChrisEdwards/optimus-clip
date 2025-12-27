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

    /// Apple Developer Team ID for code signing verification.
    /// Replace with your actual Team ID from Apple Developer Portal.
    /// Find it with: `security find-identity -v -p codesigning`
    private static let teamID = "YOUR_TEAM_ID"

    // MARK: - Properties

    /// The Sparkle updater controller (nil if updates disabled)
    private var controller: SPUStandardUpdaterController?

    /// The underlying Sparkle updater for advanced operations
    var updater: SPUUpdater? { self.controller?.updater }

    /// Whether update checking is available (false during development)
    @Published private(set) var canCheckForUpdates: Bool = false

    // MARK: - Initialization

    init() {
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
        let bundle = Bundle.main

        // Condition 1: Must be running as an app bundle
        guard bundle.bundleURL.pathExtension == "app" else {
            print("[UpdaterWrapper] Not an app bundle")
            return false
        }

        // Condition 2: Must be signed with Developer ID
        guard self.isSignedWithDeveloperID(bundle.bundleURL) else {
            print("[UpdaterWrapper] Not signed with Developer ID")
            return false
        }

        return true
    }

    /// Verify the app is signed with our Developer ID certificate
    private func isSignedWithDeveloperID(_ url: URL) -> Bool {
        var code: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(url as CFURL, [], &code)

        guard createStatus == errSecSuccess, let staticCode = code else {
            return false
        }

        // Requirement: Signed by Apple and our specific team
        // IMPORTANT: Update teamID constant with your actual Apple Developer Team ID
        let requirement = "anchor apple generic and certificate leaf[subject.OU] = \"\(Self.teamID)\""

        var req: SecRequirement?
        guard SecRequirementCreateWithString(requirement as CFString, [], &req) == errSecSuccess,
              let secRequirement = req else {
            return false
        }

        return SecStaticCodeCheckValidity(staticCode, [], secRequirement) == errSecSuccess
    }
}
