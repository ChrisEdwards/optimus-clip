import Foundation

/// Configuration options for smart unwrap behavior.
public struct SmartUnwrapConfig: Sendable, Equatable {
    /// Minimum consecutive lines to consider a block "wrapped"
    public var minConsecutiveLines: Int

    /// Tolerance for line length consistency (characters)
    public var lengthTolerance: Int

    /// Lower bound of typical hard-wrap line lengths
    public var wrapRangeLower: Int

    /// Upper bound of typical hard-wrap line lengths
    public var wrapRangeUpper: Int

    /// Minimum consistency ratio to trigger unwrap (0.0 - 1.0)
    public var consistencyThreshold: Double

    /// Always preserve code-like blocks
    public var preserveCodeBlocks: Bool

    /// Preserve lines starting with these characters (lists, quotes)
    public var preservePrefixes: [String]

    /// Creates a configuration with the specified options.
    public init(
        minConsecutiveLines: Int = 3,
        lengthTolerance: Int = 5,
        wrapRangeLower: Int = 65,
        wrapRangeUpper: Int = 85,
        consistencyThreshold: Double = 0.7,
        preserveCodeBlocks: Bool = true,
        preservePrefixes: [String] = ["-", "*", ">", "•", "1.", "2.", "3.", "4.", "5.", "6.", "7.", "8.", "9."]
    ) {
        self.minConsecutiveLines = minConsecutiveLines
        self.lengthTolerance = lengthTolerance
        self.wrapRangeLower = wrapRangeLower
        self.wrapRangeUpper = wrapRangeUpper
        self.consistencyThreshold = consistencyThreshold
        self.preserveCodeBlocks = preserveCodeBlocks
        self.preservePrefixes = preservePrefixes
    }

    /// Default configuration for typical hard-wrapped text.
    public static let `default` = SmartUnwrapConfig()
}

/// Smart transformation that unwraps hard-wrapped text while preserving code and structure.
///
/// Text from older systems (emails, terminals, git commits) is often "hard-wrapped" at a fixed
/// column width (typically 72-80 characters). This transformation detects and removes these
/// artificial line breaks while preserving intentional formatting.
///
/// ## Example
/// ```
/// Input (hard-wrapped at 72 chars):
/// This is a paragraph of text that was written in an email client
/// that automatically wrapped lines at 72 characters. Each line ends
/// with a hard return character.
///
/// Output:
/// This is a paragraph of text that was written in an email client that automatically wrapped
/// lines at 72 characters. Each line ends with a hard return character.
/// ```
///
/// ## Key Features
/// - Detects hard-wrapped blocks via line length consistency heuristics
/// - Preserves intentional paragraph breaks (empty lines)
/// - Never corrupts code (uses CodeDetector for safety)
/// - Preserves lists, quotes, and other structural elements
public struct SmartUnwrapTransformation: Transformation {
    public let id = "smart-unwrap"
    public let displayName = "Smart Unwrap"

    private let config: SmartUnwrapConfig
    private let codeDetector: CodeDetector

    /// Creates a smart unwrap transformation with the given configuration.
    public init(config: SmartUnwrapConfig = .default, codeDetector: CodeDetector = .init()) {
        self.config = config
        self.codeDetector = codeDetector
    }

    /// Transforms the input by unwrapping hard-wrapped text blocks.
    ///
    /// - Parameter input: Text that may contain hard-wrapped paragraphs
    /// - Returns: Text with hard wraps removed, structure preserved
    /// - Throws: `TransformationError.emptyInput` if input is empty
    public func transform(_ input: String) async throws -> String {
        guard !input.isEmpty else {
            throw TransformationError.emptyInput
        }

        // Early exit: if high code confidence, return unchanged
        if self.config.preserveCodeBlocks, self.codeDetector.shouldSkipTransformation(input) {
            return input
        }

        // Split into blocks (separated by empty lines)
        let blocks = self.splitIntoBlocks(input)

        // Process each block
        var resultLines: [String] = []
        for block in blocks {
            if block.count == 1, block[0].isEmpty {
                // Preserve empty line as paragraph separator
                resultLines.append("")
            } else if self.shouldUnwrap(block) {
                // Unwrap this block into a single line
                resultLines.append(self.unwrapBlock(block))
            } else {
                // Preserve original line breaks
                resultLines.append(contentsOf: block)
            }
        }

        return resultLines.joined(separator: "\n")
    }

    // MARK: - Block Detection

    /// Splits text into blocks separated by empty lines.
    ///
    /// Each block is a group of consecutive non-empty lines.
    /// Empty lines become single-element blocks with an empty string.
    private func splitIntoBlocks(_ text: String) -> [[String]] {
        let lines = text.components(separatedBy: "\n")
        var blocks: [[String]] = []
        var currentBlock: [String] = []

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !currentBlock.isEmpty {
                    blocks.append(currentBlock)
                    currentBlock = []
                }
                blocks.append([""]) // Preserve empty line as separator
            } else {
                currentBlock.append(line)
            }
        }

        if !currentBlock.isEmpty {
            blocks.append(currentBlock)
        }

        return blocks
    }

    // MARK: - Unwrap Decision

    /// Determines if a block should be unwrapped.
    private func shouldUnwrap(_ lines: [String]) -> Bool {
        // Too few lines to determine pattern
        guard lines.count >= self.config.minConsecutiveLines else {
            return false
        }

        // Check for code indicators
        if self.config.preserveCodeBlocks, self.containsCodeIndicators(lines) {
            return false
        }

        // Check for list/quote prefixes
        let hasListPrefix = self.config.preservePrefixes.contains { prefix in
            lines.contains { $0.trimmingCharacters(in: .whitespaces).hasPrefix(prefix) }
        }
        if hasListPrefix {
            return false
        }

        // Check for indented continuation lines (could be a list)
        if self.hasIndentedContinuations(lines) {
            return false
        }

        // Check for hard-wrap pattern
        return self.isHardWrapped(lines)
    }

    /// Checks if lines have indented continuations (suggesting list structure).
    private func hasIndentedContinuations(_ lines: [String]) -> Bool {
        guard lines.count >= 2 else { return false }

        let firstLineIndent = self.countLeadingSpaces(lines[0])
        for i in 1 ..< lines.count {
            let indent = self.countLeadingSpaces(lines[i])
            // If a subsequent line has more indentation than the first,
            // it's likely a continuation (list, quote block, etc.)
            if indent > firstLineIndent, indent > 0 {
                return true
            }
        }
        return false
    }

    /// Counts leading spaces in a line.
    private func countLeadingSpaces(_ line: String) -> Int {
        var count = 0
        for char in line {
            if char == " " {
                count += 1
            } else if char == "\t" {
                count += 4
            } else {
                break
            }
        }
        return count
    }

    // MARK: - Hard-Wrap Detection

    /// Detects if lines appear to be hard-wrapped at a consistent width.
    ///
    /// The key insight: hard-wrapped paragraphs have suspiciously consistent line lengths.
    /// If 70%+ of lines are within 5 characters of the median, and the median is in the
    /// typical wrap range (65-85 chars), it's almost certainly hard-wrapped.
    private func isHardWrapped(_ lines: [String]) -> Bool {
        // Calculate line lengths (excluding the last line which may be short)
        let lengths: [Int] = if lines.count > 1 {
            // Exclude last line from analysis (it's often short)
            lines.dropLast().map(\.count)
        } else {
            lines.map(\.count)
        }

        guard !lengths.isEmpty else { return false }

        // Calculate median length
        let sortedLengths = lengths.sorted()
        let median = sortedLengths[sortedLengths.count / 2]

        // Check if median is in typical hard-wrap range
        guard median >= self.config.wrapRangeLower, median <= self.config.wrapRangeUpper else {
            return false
        }

        // Count lines within tolerance of median
        let consistentCount = lengths.count(where: { abs($0 - median) <= self.config.lengthTolerance })
        let consistencyRatio = Double(consistentCount) / Double(lengths.count)

        return consistencyRatio >= self.config.consistencyThreshold
    }

    // MARK: - Code Detection

    /// Checks for indicators that lines contain code.
    private func containsCodeIndicators(_ lines: [String]) -> Bool {
        let codeIndicators = [
            "func ", "def ", "class ", "struct ", "enum ",
            "import ", "from ", "require ", "#include",
            "if (", "for (", "while (", "switch ", "case ",
            "return ", "throw ", "try {", "catch ",
            "=>", "->", "//", "/*", "*/",
            "public ", "private ", "protected ", "static ",
            "const ", "let ", "var "
        ]

        return lines.contains { line in
            // Check for code keywords/symbols
            let hasCodeKeyword = codeIndicators.contains { line.contains($0) }
            if hasCodeKeyword { return true }

            // Check for braces (strong code indicator)
            if line.contains("{") || line.contains("}") { return true }

            // Check for indentation patterns (4+ spaces or tabs at start)
            if line.hasPrefix("    ") || line.hasPrefix("\t") { return true }

            // Check for lines ending in code-like characters
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasSuffix(";") || trimmed.hasSuffix("{") || trimmed.hasSuffix("}") { return true }

            return false
        }
    }

    // MARK: - Unwrap Operation

    /// Joins lines into a single paragraph.
    private func unwrapBlock(_ lines: [String]) -> String {
        lines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
    }
}
