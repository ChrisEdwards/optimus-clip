import Testing
@testable import OptimusClip

@Suite("SmartPreview Helper")
struct SmartPreviewTests {
    @Test("Simple text returns unchanged")
    func simpleText() {
        #expect(smartPreview(for: "Hello world") == "Hello world")
    }

    @Test("Leading newlines are trimmed")
    func leadingNewlines() {
        #expect(smartPreview(for: "\n\nFixed text here") == "Fixed text here")
    }

    @Test("Only first line is returned")
    func multiLine() {
        #expect(smartPreview(for: "Line one\nLine two") == "Line one")
    }

    @Test("Long text is truncated with ellipsis")
    func longText() {
        let longText = String(repeating: "a", count: 100)
        let result = smartPreview(for: longText, maxLength: 80)
        #expect(result.count == 80)
        #expect(result.hasSuffix("…"))
        #expect(result.hasPrefix("aaa"))
    }

    @Test("Empty string returns placeholder")
    func emptyString() {
        #expect(smartPreview(for: "") == "(empty)")
    }

    @Test("Whitespace-only string returns placeholder")
    func whitespaceOnly() {
        #expect(smartPreview(for: "   ") == "(empty)")
        #expect(smartPreview(for: "\n\n\n") == "(empty)")
        #expect(smartPreview(for: "  \t\n  ") == "(empty)")
    }

    @Test("Leading whitespace and newlines are trimmed")
    func leadingWhitespace() {
        #expect(smartPreview(for: "   Hello") == "Hello")
        #expect(smartPreview(for: "\t\tHello") == "Hello")
    }

    @Test("Trailing whitespace is trimmed")
    func trailingWhitespace() {
        #expect(smartPreview(for: "Hello   ") == "Hello")
        #expect(smartPreview(for: "Hello\n\n") == "Hello")
    }

    @Test("Custom maxLength is respected")
    func customMaxLength() {
        let result = smartPreview(for: "This is a longer text", maxLength: 10)
        #expect(result.count == 10)
        #expect(result == "This is a…")
    }

    @Test("Text exactly at maxLength is not truncated")
    func exactLength() {
        let text = String(repeating: "x", count: 80)
        #expect(smartPreview(for: text, maxLength: 80) == text)
    }

    @Test("Text one char over maxLength is truncated")
    func oneOverLength() {
        let text = String(repeating: "x", count: 81)
        let result = smartPreview(for: text, maxLength: 80)
        #expect(result.count == 80)
        #expect(result.hasSuffix("…"))
    }

    @Test("Unicode characters are handled correctly")
    func unicodeHandling() {
        #expect(smartPreview(for: "Hello 🌍 World") == "Hello 🌍 World")
        #expect(smartPreview(for: "👋🏻👋🏼👋🏽👋🏾👋🏿") == "👋🏻👋🏼👋🏽👋🏾👋🏿")
    }

    @Test("Emoji at truncation boundary")
    func emojiTruncation() {
        // 78 chars + emoji should truncate properly
        let text = String(repeating: "a", count: 78) + "🎉🎉"
        let result = smartPreview(for: text, maxLength: 80)
        #expect(result.count == 80)
    }

    @Test("Multiline with leading newlines extracts first content line")
    func multilineWithLeadingNewlines() {
        let text = "\n\n\nFirst actual line\nSecond line\nThird line"
        #expect(smartPreview(for: text) == "First actual line")
    }
}
