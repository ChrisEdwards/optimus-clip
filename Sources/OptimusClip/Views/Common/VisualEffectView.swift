import AppKit
import SwiftUI

/// NSViewRepresentable wrapper for NSVisualEffectView.
/// Provides blur/vibrancy effects for macOS windows and views.
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context _: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = self.material
        visualEffectView.blendingMode = self.blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context _: Context) {
        visualEffectView.material = self.material
        visualEffectView.blendingMode = self.blendingMode
    }
}
