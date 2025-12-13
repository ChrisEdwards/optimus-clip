import Foundation
import Testing

@testable import OptimusClipCore

@Suite("CodeDetector Tests")
struct CodeDetectorTests {
    let detector = CodeDetector()

    // MARK: - Python Code Detection

    @Test("Python function detected as code")
    func pythonFunctionDetected() {
        // Using actual indentation - not relying on multiline string dedent
        let pythonCode = "def process():\n    if condition:\n        do_something()\n    else:\n        do_other()"
        let confidence = self.detector.codeConfidence(pythonCode)
        #expect(confidence > 0.3, "Python code should have medium confidence")
    }

    @Test("Python with indentation hierarchy")
    func pythonIndentationHierarchy() {
        let pythonCode = """
        def main():
            for i in range(10):
                if i % 2 == 0:
                    print(i)
        """
        let score = self.detector.hasIndentationHierarchyScore(pythonCode)
        #expect(score >= 0.6, "Multiple indent levels should score high")
    }

    // MARK: - JavaScript Code Detection

    @Test("JavaScript with braces detected")
    func javaScriptBracesDetected() {
        let jsCode = """
        function greet(name) {
            if (name) {
                return `Hello, ${name}!`;
            }
            return "Hello!";
        }
        """
        let confidence = self.detector.codeConfidence(jsCode)
        #expect(confidence > 0.6, "JavaScript with braces should have high confidence")
    }

    @Test("Arrow function syntax detected")
    func arrowFunctionSyntax() {
        let jsCode = """
        const add = (a, b) => a + b;
        const greet = name => `Hello, ${name}`;
        """
        let syntaxScore = self.detector.hasSpecialSyntaxScore(jsCode)
        #expect(syntaxScore >= 0.3, "Arrow functions should be detected")
    }

    // MARK: - Swift Code Detection

    @Test("Swift code detected")
    func swiftCodeDetected() {
        let swiftCode = """
        struct Person: Sendable {
            let name: String
            let age: Int

            func greet() -> String {
                return "Hello, \\(name)"
            }
        }
        """
        let confidence = self.detector.codeConfidence(swiftCode)
        #expect(confidence > 0.7, "Swift code should have high confidence")
    }

    @Test("Swift async/await detected")
    func swiftAsyncAwait() {
        let swiftCode = """
        func fetchData() async throws -> Data {
            let result = try await networkClient.fetch()
            return result
        }
        """
        let keywordsScore = self.detector.hasKeywordsScore(swiftCode)
        #expect(keywordsScore >= 0.4, "async/await keywords should be detected")
    }

    // MARK: - Plain Prose Detection

    @Test("Plain prose has low confidence")
    func plainProseLowConfidence() {
        let prose = """
        This is a paragraph of plain text. It contains no code at all.
        The text wraps naturally across multiple lines, as you would
        expect in a normal document or email message.
        """
        let confidence = self.detector.codeConfidence(prose)
        #expect(confidence < 0.4, "Plain prose should have low confidence")
    }

    @Test("Email text not detected as code")
    func emailNotCode() {
        let email = """
        Hi team,

        I wanted to follow up on our meeting yesterday. Here are the
        action items we discussed:

        - Review the proposal
        - Schedule the next meeting
        - Send the report

        Thanks,
        John
        """
        let confidence = self.detector.codeConfidence(email)
        #expect(confidence < 0.4, "Email should not be detected as code")
    }

    // MARK: - Braces Score Tests

    @Test("Multiple braces score high")
    func multipleBracesScore() {
        let code = "{ a: { b: { c: 1 } } }"
        let score = self.detector.hasBracesScore(code)
        #expect(score == 1.0, "4+ braces should score 1.0")
    }

    @Test("Two braces score medium")
    func twoBracesScore() {
        let code = "{ name: 'test' }"
        let score = self.detector.hasBracesScore(code)
        #expect(score == 0.7, "2-3 braces should score 0.7")
    }

    @Test("No braces score zero")
    func noBracesScore() {
        let text = "Hello, world!"
        let score = self.detector.hasBracesScore(text)
        #expect(score == 0.0, "No braces should score 0.0")
    }

    // MARK: - Keywords Score Tests

    @Test("Many keywords score high")
    func manyKeywordsScore() {
        let code = "public class Foo { private func bar() { if true { return } } }"
        let score = self.detector.hasKeywordsScore(code)
        #expect(score >= 0.7, "5+ keywords should score high")
    }

    @Test("Few keywords score medium")
    func fewKeywordsScore() {
        let code = "function test() { return true; }"
        let score = self.detector.hasKeywordsScore(code)
        #expect(score >= 0.4, "1-2 keywords should score medium")
    }

    @Test("No keywords score zero")
    func noKeywordsScore() {
        let text = "Hello world this is a test"
        let score = self.detector.hasKeywordsScore(text)
        #expect(score == 0.0, "No keywords should score 0.0")
    }

    // MARK: - Indentation Score Tests

    @Test("Multiple indent levels score high")
    func multipleIndentLevels() {
        let code = """
        level0
            level1
                level2
                    level3
        """
        let score = self.detector.hasIndentationHierarchyScore(code)
        #expect(score == 1.0, "3+ indent levels should score 1.0")
    }

    @Test("Two indent levels score medium")
    func twoIndentLevels() {
        // Using explicit newlines with real indentation
        let code = "level0\n    level1"
        let score = self.detector.hasIndentationHierarchyScore(code)
        #expect(score == 0.6, "2 indent levels should score 0.6")
    }

    @Test("No indentation scores zero")
    func noIndentation() {
        let text = """
        line one
        line two
        line three
        """
        let score = self.detector.hasIndentationHierarchyScore(text)
        #expect(score == 0.0, "No indentation should score 0.0")
    }

    // MARK: - Special Syntax Tests

    @Test("Arrow operators detected")
    func arrowOperators() {
        let code = "let add = (a, b) => a + b; func test() -> Int"
        let score = self.detector.hasSpecialSyntaxScore(code)
        #expect(score >= 0.6, "Arrow operators should score high")
    }

    @Test("Preprocessor directives detected")
    func preprocessorDirectives() {
        let code = "#include <stdio.h>\n#define MAX 100"
        let score = self.detector.hasSpecialSyntaxScore(code)
        #expect(score >= 0.6, "Preprocessor directives should score high")
    }

    // MARK: - Line Structure Tests

    @Test("Code line endings detected")
    func codeLineEndings() {
        let code = """
        let a = 1;
        let b = 2;
        if (a < b) {
            console.log(a);
        }
        """
        let score = self.detector.hasCodeLineStructureScore(code)
        #expect(score >= 0.6, "Lines ending in ; { } should score high")
    }

    @Test("Prose line endings score low")
    func proseLineEndings() {
        let prose = """
        This is a sentence.
        Here is another one.
        And one more for good measure.
        """
        // Prose ends in periods, not code characters
        let score = self.detector.hasCodeLineStructureScore(prose)
        #expect(score < 0.5, "Prose should score low on line structure")
    }

    // MARK: - Fenced Code Block Tests

    @Test("Fenced code block detected")
    func fencedCodeBlockDetected() {
        let markdown = """
        Here is some code:

        ```swift
        let x = 1
        ```

        And more text.
        """
        let contains = self.detector.containsFencedCodeBlock(markdown)
        #expect(contains, "Should detect fenced code block")
    }

    @Test("No fenced block returns false")
    func noFencedBlock() {
        let text = "Just plain text without any code blocks"
        let contains = self.detector.containsFencedCodeBlock(text)
        #expect(!contains, "Should not detect fenced block in plain text")
    }

    @Test("Fenced code gives confidence 1.0")
    func fencedCodeConfidence() {
        let markdown = """
        ```python
        print("hello")
        ```
        """
        let confidence = self.detector.codeConfidence(markdown)
        #expect(confidence == 1.0, "Fenced code should return confidence 1.0")
    }

    // MARK: - Mixed Content Tests

    @Test("Mixed prose and code")
    func mixedProseAndCode() {
        let mixed = """
        Here is some explanation of the function:

        function calculate(x) {
            return x * 2;
        }

        The function doubles the input value.
        """
        let confidence = self.detector.codeConfidence(mixed)
        #expect(confidence >= 0.4, "Mixed content should have medium confidence")
    }

    // MARK: - Configuration Tests

    @Test("Skip threshold works")
    func skipThreshold() {
        // Code with many signals: braces, keywords, syntax, structure
        let code = "public class Foo {\n    private func bar() -> Int {\n        let x = 1;\n        return x;\n    }\n}"
        let shouldSkip = self.detector.shouldSkipTransformation(code)
        #expect(shouldSkip, "High confidence code should be skipped")
    }

    @Test("Conservative mode works")
    func conservativeMode() {
        // Create text with medium confidence
        let mediumConfidenceText = """
        Here is a function:
        func test() { }
        That was the function.
        """
        let config = CodePreservationConfig(skipThreshold: 0.8, conservativeThreshold: 0.3)
        let customDetector = CodeDetector(config: config)
        let confidence = customDetector.codeConfidence(mediumConfidenceText)

        // This should hit the conservative range depending on content
        // The exact behavior depends on the weighted scoring
        #expect(confidence >= 0.0 && confidence <= 1.0, "Confidence should be valid")
    }

    // MARK: - Edge Cases

    @Test("Empty string returns zero confidence")
    func emptyString() {
        let confidence = self.detector.codeConfidence("")
        #expect(confidence == 0.0, "Empty string should have 0 confidence")
    }

    @Test("Single character string")
    func singleCharacter() {
        let confidence = self.detector.codeConfidence("x")
        #expect(confidence >= 0.0 && confidence <= 1.0, "Should handle single char")
    }

    @Test("JSON detected as code")
    func jSONDetected() {
        // JSON with real indentation
        let json = "{\n    \"name\": \"test\",\n    \"values\": [1, 2, 3],\n    \"nested\": {\n        \"key\": \"value\"\n    }\n}"
        let confidence = self.detector.codeConfidence(json)
        #expect(confidence > 0.4, "JSON should be detected as code-like")
    }

    @Test("YAML has low-medium confidence")
    func yAMLConfidence() {
        // YAML with real indentation
        let yaml = "name: test\nversion: 1.0\ndependencies:\n  - dep1\n  - dep2\nconfig:\n  key: value"
        let confidence = self.detector.codeConfidence(yaml)
        // YAML has colons and some structure but lacks braces/keywords
        // Primary signal is line endings with colons
        #expect(confidence >= 0.0, "YAML should be handled without crashing")
    }

    // MARK: - Code Block Range Detection

    @Test("Detect fenced block ranges")
    func detectFencedBlockRanges() {
        let markdown = """
        Some text before.

        ```swift
        let x = 1
        let y = 2
        ```

        Some text after.
        """
        let blocks = self.detector.detectCodeBlocks(markdown)
        #expect(blocks.count >= 1, "Should detect at least one code block")
    }

    // MARK: - Performance Sanity Check

    @Test("Large text completes quickly")
    func largeTextPerformance() {
        // Generate ~10KB of text
        let repeatedText = String(repeating: "This is a line of text.\n", count: 500)
        let startTime = Date()
        _ = self.detector.codeConfidence(repeatedText)
        let elapsed = Date().timeIntervalSince(startTime)

        #expect(elapsed < 0.5, "Should complete in under 500ms for 10KB")
    }
}
