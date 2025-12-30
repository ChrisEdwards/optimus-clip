import AppKit
import OptimusClip
import Testing

@Suite("ClipboardSafety URL handling")
struct ClipboardSafetyURLTests {
    @MainActor
    @Test("Treats URL with string content as text")
    func urlWithStringIsText() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        pasteboard.setString("https://example.com", forType: .string)
        pasteboard.setString("https://example.com", forType: .URL)

        let type = ClipboardSafety.detectContentType()
        #expect(type == .text)
    }
}
