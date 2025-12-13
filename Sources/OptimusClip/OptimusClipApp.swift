import SwiftUI

/// Main entry point for Optimus Clip.
///
/// Phase 0: Minimal app structure to verify build system.
/// Phase 1: Add MenuBarExtra and status item.
@main
struct OptimusClipApp: App {
    var body: some Scene {
        // Placeholder: Empty scene to satisfy App protocol
        // Phase 1 will replace this with MenuBarExtra
        WindowGroup {
            Text("Optimus Clip")
                .frame(width: 200, height: 100)
        }
    }
}
