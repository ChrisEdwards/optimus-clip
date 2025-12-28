import AppKit
import SwiftUI

// MARK: - Native ComboBox

/// A SwiftUI wrapper for NSComboBox providing native autocomplete functionality.
///
/// This component wraps AppKit's NSComboBox to provide:
/// - Native macOS autocomplete behavior
/// - Dropdown list of suggestions
/// - Free-form text entry (user can type values not in the list)
///
/// Used in provider settings and transformation editor for model selection.
struct ComboBox: NSViewRepresentable {
    @Binding var text: String
    var items: [String]
    var placeholder: String

    func makeNSView(context: Context) -> NSComboBox {
        let comboBox = NSComboBox()
        comboBox.usesDataSource = false
        comboBox.completes = true
        comboBox.delegate = context.coordinator
        comboBox.placeholderString = self.placeholder
        comboBox.addItems(withObjectValues: self.items)
        comboBox.stringValue = self.text
        return comboBox
    }

    func updateNSView(_ nsView: NSComboBox, context _: Context) {
        // Update items if changed
        let currentItems = nsView.objectValues.compactMap { $0 as? String }
        if currentItems != self.items {
            // Dismiss popup before updating items to prevent stuck dropdown
            if nsView.isButtonBordered {
                nsView.window?.makeFirstResponder(nil)
            }
            nsView.removeAllItems()
            nsView.addItems(withObjectValues: self.items)
        }

        // Update text if changed externally
        if nsView.stringValue != self.text {
            nsView.stringValue = self.text
        }
    }

    static func dismantleNSView(_ nsView: NSComboBox, coordinator _: Coordinator) {
        // Ensure popup is dismissed when view is removed
        nsView.window?.makeFirstResponder(nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSComboBoxDelegate, NSTextFieldDelegate {
        var parent: ComboBox

        init(_ parent: ComboBox) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let comboBox = obj.object as? NSComboBox else { return }
            self.parent.text = comboBox.stringValue
        }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox,
                  comboBox.indexOfSelectedItem >= 0,
                  let selected = comboBox.objectValueOfSelectedItem as? String else { return }
            self.parent.text = selected
            // Dismiss the dropdown after selection
            comboBox.window?.makeFirstResponder(nil)
        }
    }
}
