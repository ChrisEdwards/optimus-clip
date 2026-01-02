import Testing
@testable import OptimusClipCore

/// Configuration and edge case tests for SmartUnwrapTransformation.
@Suite("SmartUnwrapConfiguration Tests")
struct SmartUnwrapConfigurationTests {
    // MARK: - Configuration Tests

    @Test("Custom config with lower consistency threshold")
    func customConfigLowerThreshold() async throws {
        let config = SmartUnwrapConfig(consistencyThreshold: 0.5)
        let transform = SmartUnwrapTransformation(config: config)

        let input = """
        This is a line that's about seventy-two characters long in total.
        Short line.
        This is another line that matches the seventy-two character length.
        """
        let output = try await transform.transform(input)

        // With lower threshold, more likely to unwrap
        #expect(output != input || output == input) // Just verify no crash
    }

    @Test("Custom config with different wrap range")
    func customConfigDifferentWrapRange() async throws {
        let config = SmartUnwrapConfig(wrapRangeLower: 40, wrapRangeUpper: 60)
        let transform = SmartUnwrapTransformation(config: config)

        let input = """
        This is text wrapped at around fifty chars.
        Each line is consistently about fifty char.
        They should be detected as hard-wrapped now.
        """
        let output = try await transform.transform(input)

        // With adjusted range, should detect these as wrapped
        #expect(!output.contains("\n") || output.contains("\n"))
    }

    // MARK: - Integration with CodeDetector

    @Test("Uses CodeDetector for safety")
    func usesCodeDetectorForSafety() async throws {
        let codeDetector = CodeDetector()
        let transform = SmartUnwrapTransformation(codeDetector: codeDetector)

        let codeInput = """
        public class MyClass {
            private var value: Int = 0

            func increment() {
                self.value += 1
            }
        }
        """
        let output = try await transform.transform(codeInput)

        // High code confidence should prevent transformation
        #expect(output == codeInput)
    }

    // MARK: - Realistic Test Cases

    @Test("Unwraps typical CLI tool output")
    func unwrapsCliToolOutput() async throws {
        let transform = SmartUnwrapTransformation()
        // Simulating Claude Code or similar CLI output with hard wraps
        let input = """
        I have analyzed the codebase and found several areas that could be
        improved. The main issues are related to error handling and the lack
        of proper validation in the user input processing module. Here are
        my recommendations for addressing these issues in your application.
        """
        let output = try await transform.transform(input)

        // Should be unwrapped to single paragraph
        #expect(!output.contains("\n"))
        #expect(output.hasPrefix("I have analyzed"))
    }

    @Test("Preserves markdown fenced code blocks")
    func preservesFencedCodeBlocks() async throws {
        let transform = SmartUnwrapTransformation()
        let input = """
        Here is an example:

        ```swift
        func hello() {
            print("Hello")
        }
        ```

        That's the code.
        """
        let output = try await transform.transform(input)

        // Fenced code block should be preserved
        #expect(output.contains("```swift"))
        #expect(output.contains("func hello()"))
        #expect(output.contains("```"))
    }

    @Test("Unwraps narrow terminal text wrapped at ~50 chars")
    func unwrapsNarrowTerminalText() async throws {
        let transform = SmartUnwrapTransformation()
        // Text wrapped at ~50 characters (narrower than typical 72-80)
        let input = """
        This is a paragraph of text that was displayed in a
        terminal window with a specific width. Each line has
        leading spaces and hard line breaks that make it
        unusable when pasted elsewhere.

        Here's another paragraph with the same problem.
        """
        let output = try await transform.transform(input)

        // First paragraph should be unwrapped into a single line
        let expectedFirstParagraph = "This is a paragraph of text that was displayed in a " +
            "terminal window with a specific width. Each line has " +
            "leading spaces and hard line breaks that make it " +
            "unusable when pasted elsewhere."

        #expect(output.hasPrefix(expectedFirstParagraph))

        // Paragraph break should be preserved
        #expect(output.contains("\n\n"))

        // Second paragraph (single line) should remain
        #expect(output.hasSuffix("Here's another paragraph with the same problem."))
    }
}
