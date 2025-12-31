import Foundation

/// Configuration for code detection behavior.
public struct CodePreservationConfig: Sendable, Equatable {
    /// Confidence threshold to skip transformation (0.0 - 1.0)
    public var skipThreshold: Double

    /// Confidence threshold for conservative mode
    public var conservativeThreshold: Double

    /// Always preserve fenced code blocks (```)
    public var preserveFencedBlocks: Bool

    /// Always preserve 4-space indented blocks
    public var preserveIndentedBlocks: Bool

    public init(
        skipThreshold: Double = 0.7,
        conservativeThreshold: Double = 0.4,
        preserveFencedBlocks: Bool = true,
        preserveIndentedBlocks: Bool = true
    ) {
        self.skipThreshold = skipThreshold
        self.conservativeThreshold = conservativeThreshold
        self.preserveFencedBlocks = preserveFencedBlocks
        self.preserveIndentedBlocks = preserveIndentedBlocks
    }

    /// Default configuration with standard thresholds
    public static let `default` = CodePreservationConfig()
}

/// Detects whether text content is likely to be code.
///
/// Uses a multi-signal approach to calculate confidence that text is code:
/// - Signal 1: Braces and brackets (`{}[]`)
/// - Signal 2: Language keywords (`func`, `def`, `class`, etc.)
/// - Signal 3: Indentation hierarchy (multiple indent levels)
/// - Signal 4: Special syntax (`=>`, `->`, `::`, etc.)
/// - Signal 5: Line structure (lines ending in `;`, `{`, `}`, etc.)
///
/// This is critical for preventing transformations from corrupting code.
/// For example, unwrapping hard-wrapped Python would destroy indentation semantics.
public struct CodeDetector: Sendable {
    public let config: CodePreservationConfig

    public init(config: CodePreservationConfig = .default) {
        self.config = config
    }

    // MARK: - Main Detection API

    /// Returns confidence score 0.0 - 1.0 that text is code.
    ///
    /// - Parameter text: The text to analyze
    /// - Returns: Confidence score where 0.0 = definitely not code, 1.0 = definitely code
    public func codeConfidence(_ text: String) -> Double {
        guard !text.isEmpty else { return 0.0 }

        // Check for fenced code blocks first (definite code marker)
        if self.config.preserveFencedBlocks, self.containsFencedCodeBlock(text) {
            return 1.0
        }

        // Calculate individual signal scores
        let bracesScore = self.hasBracesScore(text)
        let keywordsScore = self.hasKeywordsScore(text)
        let indentationScore = self.hasIndentationHierarchyScore(text)
        let syntaxScore = self.hasSpecialSyntaxScore(text)
        let lineStructureScore = self.hasCodeLineStructureScore(text)

        // Weighted average (braces and keywords most important)
        let weights = [0.3, 0.3, 0.15, 0.15, 0.1]
        let scores = [bracesScore, keywordsScore, indentationScore, syntaxScore, lineStructureScore]

        let weightedSum = zip(scores, weights).map { $0 * $1 }.reduce(0.0, +)
        return min(max(weightedSum, 0.0), 1.0)
    }

    /// Determines if the transformation should be skipped entirely.
    ///
    /// - Parameter text: The text to check
    /// - Returns: true if confidence exceeds skip threshold
    public func shouldSkipTransformation(_ text: String) -> Bool {
        self.codeConfidence(text) > self.config.skipThreshold
    }

    /// Determines if conservative transformation mode should be used.
    ///
    /// - Parameter text: The text to check
    /// - Returns: true if confidence is between conservative and skip thresholds
    public func shouldUseConservativeMode(_ text: String) -> Bool {
        let confidence = self.codeConfidence(text)
        return confidence > self.config.conservativeThreshold && confidence <= self.config.skipThreshold
    }

    // MARK: - Signal 1: Braces and Brackets

    /// Score based on presence of braces and brackets.
    ///
    /// Code typically contains balanced braces `{}` and brackets `[]`.
    /// High presence of these characters strongly indicates code.
    public func hasBracesScore(_ text: String) -> Double {
        let braceChars: Set<Character> = ["{", "}", "[", "]"]
        let braceCount = text.count(where: { braceChars.contains($0) })

        // If we see braces, very likely code
        if braceCount >= 4 { return 1.0 }
        if braceCount >= 2 { return 0.7 }
        if braceCount >= 1 { return 0.3 }
        return 0.0
    }

    // MARK: - Signal 2: Language Keywords

    /// Score based on presence of programming language keywords.
    ///
    /// Common keywords across many languages indicate code content.
    public func hasKeywordsScore(_ text: String) -> Double {
        // Keywords that are specific to programming and unlikely in normal prose
        // Avoiding common English words like: this, new, with, return, from, for, while, if, else, case, etc.
        // Use word boundary matching to avoid false positives
        let keywordMatches = CodeDetectorRegexes.keywordRegexes.count { regex in
            regex.containsMatch(in: text)
        }

        if keywordMatches >= 5 { return 1.0 }
        if keywordMatches >= 3 { return 0.7 }
        if keywordMatches >= 1 { return 0.4 }
        return 0.0
    }

    // MARK: - Signal 3: Indentation Hierarchy

    /// Score based on indentation patterns.
    ///
    /// Code typically has multiple distinct indentation levels,
    /// indicating nested structure (functions, loops, conditionals).
    public func hasIndentationHierarchyScore(_ text: String) -> Double {
        let lines = text.components(separatedBy: "\n")
        var indentLevels = Set<Int>()

        for line in lines {
            // Skip empty lines
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }

            // Count leading whitespace
            var indent = 0
            for char in line {
                if char == " " {
                    indent += 1
                } else if char == "\t" {
                    indent += 4 // Treat tab as 4 spaces
                } else {
                    break
                }
            }

            // Include all indent levels (including 0) to detect hierarchy
            indentLevels.insert(indent)
        }

        // Multiple distinct indent levels = likely code
        // 3+ levels (e.g., 0, 4, 8) = high confidence
        // 2 levels (e.g., 0, 4) = medium confidence
        if indentLevels.count >= 3 { return 1.0 }
        if indentLevels.count >= 2 { return 0.6 }
        return 0.0
    }

    // MARK: - Signal 4: Special Syntax

    /// Score based on presence of programming-specific syntax.
    ///
    /// Certain character sequences are unique to code:
    /// arrows, operators, interpolation, preprocessor directives.
    public func hasSpecialSyntaxScore(_ text: String) -> Double {
        let syntaxPatterns = [
            "=>", // Arrow functions (JS, C#, Scala)
            "->", // Return type / lambda (Swift, Rust, Haskell)
            "::", // Namespace / method reference
            "===", "!==", // Strict equality (JS)
            "&&", "||", // Logical operators
            "#{", // String interpolation (Ruby)
            "$(", "${", // Shell/template variables
            "#include", "#define", "#import", // C/C++/ObjC preprocessor
            "#if", "#endif", // Preprocessor conditionals
            "///", "/**", // Doc comments
            "@objc", "@main", "@Published", // Swift attributes
            "@Override", "@Test" // Java/Kotlin annotations
        ]

        let matches = syntaxPatterns.count(where: { text.contains($0) })

        if matches >= 3 { return 1.0 }
        if matches >= 2 { return 0.6 }
        if matches >= 1 { return 0.3 }
        return 0.0
    }

    // MARK: - Signal 5: Line Structure

    /// Score based on how lines end.
    ///
    /// Code often has lines ending in specific characters:
    /// semicolons, braces, parentheses, commas.
    public func hasCodeLineStructureScore(_ text: String) -> Double {
        let lines = text.components(separatedBy: "\n")
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard !nonEmptyLines.isEmpty else { return 0.0 }

        // Code often has lines ending in specific characters
        let codeLineEndings = [";", "{", "}", ",", ":", "(", ")", "\\"]
        let codeEndingCount = nonEmptyLines.count(where: { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return codeLineEndings.contains { trimmed.hasSuffix($0) }
        })

        let ratio = Double(codeEndingCount) / Double(nonEmptyLines.count)
        return min(ratio * 2, 1.0) // Scale up, cap at 1.0
    }

    // MARK: - Fenced Code Block Detection

    /// Checks if text contains fenced code blocks (```).
    ///
    /// Fenced code blocks are a definitive code indicator in markdown.
    public func containsFencedCodeBlock(_ text: String) -> Bool {
        guard let regex = CodeDetectorRegexes.fencedStartRegex else {
            return false
        }

        return regex.containsMatch(in: text)
    }

    /// Detects code block ranges within mixed content.
    ///
    /// Returns ranges of text that appear to be code blocks,
    /// allowing transformations to preserve these sections.
    ///
    /// - Parameter text: The text to analyze
    /// - Returns: Array of ranges containing code blocks
    public func detectCodeBlocks(_ text: String) -> [Range<String.Index>] {
        var codeBlocks: [Range<String.Index>] = []

        // Pattern 1: Fenced code blocks (```...```)
        codeBlocks.append(contentsOf: self.detectFencedBlocks(text))

        // Pattern 2: 4+ space indented blocks
        if self.config.preserveIndentedBlocks {
            codeBlocks.append(contentsOf: self.detectIndentedBlocks(text))
        }

        return codeBlocks.sorted { $0.lowerBound < $1.lowerBound }
    }

    // MARK: - Private Helpers

    /// Matches a keyword as a complete word, not part of a larger word.
    private func detectFencedBlocks(_ text: String) -> [Range<String.Index>] {
        var blocks: [Range<String.Index>] = []
        guard let regex = CodeDetectorRegexes.fencedBlockRegex else {
            return blocks
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        for match in matches {
            if let swiftRange = Range(match.range, in: text) {
                blocks.append(swiftRange)
            }
        }

        return blocks
    }

    /// Detects blocks where all lines are indented with 4+ spaces.
    private func detectIndentedBlocks(_ text: String) -> [Range<String.Index>] {
        var blocks: [Range<String.Index>] = []
        let lines = text.components(separatedBy: "\n")

        var blockStart: String.Index?
        var currentIndex = text.startIndex

        for (lineIndex, line) in lines.enumerated() {
            let isIndented = line.hasPrefix("    ") || line.hasPrefix("\t")
            let isEmpty = line.trimmingCharacters(in: .whitespaces).isEmpty

            if isIndented || (isEmpty && blockStart != nil) {
                if blockStart == nil {
                    blockStart = currentIndex
                }
            } else if let start = blockStart {
                // End of indented block
                let range = Range(uncheckedBounds: (start, currentIndex))
                blocks.append(range)
                blockStart = nil
            }

            // Move to next line (account for newline character)
            if lineIndex < lines.count - 1 {
                let lineEndIndex = text.index(currentIndex, offsetBy: line.count)
                currentIndex = text.index(after: lineEndIndex)
            }
        }

        // Handle block at end of text
        if let start = blockStart {
            let range = Range(uncheckedBounds: (start, text.endIndex))
            blocks.append(range)
        }

        return blocks
    }
}

// MARK: - Regex Cache

private enum CodeDetectorRegexes {
    static let codeKeywords: [String] = [
        // Function/method definitions (high specificity)
        "function", "func", "def", "async", "await",
        // Type definitions (high specificity)
        "class", "interface", "struct", "enum", "trait", "protocol",
        // Variable declarations (high specificity)
        "const", "var", "val", "mut", "let",
        // Access modifiers (high specificity)
        "public", "private", "protected", "static",
        // Import statements (high specificity)
        "import", "export", "require", "include",
        // Exception handling (high specificity)
        "catch", "throw", "throws", "finally", "except",
        // Language-specific keywords (very high specificity)
        "fn", "impl", "pub", "mod", "crate", // Rust
        "fun", "suspend", "companion", // Kotlin
        "guard", "defer", "extension", // Swift
        "elif", "lambda", "yield", // Python
        "chan", // Go
        "nullptr", "sizeof", "typedef", // C/C++
        "instanceof", "typeof" // JavaScript
    ]

    static let keywordRegexes: [NSRegularExpression] =
        Self.codeKeywords.compactMap { keyword in
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b"
            return try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        }

    static let fencedBlockRegex = try? NSRegularExpression(pattern: "```[a-zA-Z]*[\\s\\S]*?```")
    static let fencedStartRegex = try? NSRegularExpression(pattern: "```[a-zA-Z]*\\s*\\n")
}

extension NSRegularExpression {
    fileprivate func containsMatch(in text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return self.firstMatch(in: text, range: range) != nil
    }
}
