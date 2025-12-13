import Foundation

/// Configuration options for whitespace stripping behavior.
public struct WhitespaceStripConfig: Sendable {
    /// Maximum spaces to strip (prevents over-stripping). Default: 8.
    public var maximumStrip: Int

    /// Strip trailing whitespace from each line. Default: true.
    public var stripTrailing: Bool

    /// Normalize CRLF to LF line endings. Default: true.
    public var normalizeLineEndings: Bool

    /// Creates a configuration with the specified options.
    public init(
        maximumStrip: Int = 8,
        stripTrailing: Bool = true,
        normalizeLineEndings: Bool = true
    ) {
        self.maximumStrip = maximumStrip
        self.stripTrailing = stripTrailing
        self.normalizeLineEndings = normalizeLineEndings
    }

    /// Default configuration for typical CLI output.
    public static let `default` = WhitespaceStripConfig()
}

/// Strips common leading whitespace from text while preserving relative indentation.
///
/// This transformation is designed for CLI tool outputs (like Claude Code) that add
/// consistent leading indentation. It detects the minimum common indentation across
/// all non-empty lines and removes exactly that amount, preserving relative structure.
///
/// ## Example
/// ```
/// Input:
///     def hello():        # 4 spaces
///         print("hi")     # 8 spaces
///
/// Output:
/// def hello():            # 0 spaces
///     print("hi")         # 4 spaces (relative preserved)
/// ```
///
/// ## Edge Cases
/// - Empty lines remain empty (not counted in minimum calculation)
/// - Single lines have all leading whitespace stripped
/// - Tabs are treated as 4 spaces for calculation, stripped proportionally
/// - Mixed tabs/spaces are handled conservatively
public struct WhitespaceStripTransformation: Transformation {
    public let id = "whitespace-strip"
    public let displayName = "Strip Whitespace"

    private let config: WhitespaceStripConfig

    /// Creates a whitespace strip transformation with the given configuration.
    public init(config: WhitespaceStripConfig = .default) {
        self.config = config
    }

    /// Transforms the input by stripping common leading whitespace.
    ///
    /// - Parameter input: Text with consistent leading whitespace
    /// - Returns: Text with common prefix removed, relative indentation preserved
    /// - Throws: `TransformationError.emptyInput` if input is empty
    public func transform(_ input: String) async throws -> String {
        guard !input.isEmpty else {
            throw TransformationError.emptyInput
        }

        var result = input

        // 1. Normalize line endings if configured
        if self.config.normalizeLineEndings {
            result = result.replacingOccurrences(of: "\r\n", with: "\n")
        }

        // 2. Strip common leading whitespace
        result = self.stripCommonLeadingWhitespace(result)

        // 3. Optionally strip trailing whitespace per line
        if self.config.stripTrailing {
            result = self.stripTrailingWhitespace(result)
        }

        return result
    }

    // MARK: - Private Implementation

    /// Calculates the common leading whitespace and strips it from all lines.
    private func stripCommonLeadingWhitespace(_ text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0) }

        // Find non-empty lines (lines with at least one non-whitespace char)
        let nonEmptyLines = lines.filter { !$0.allSatisfy(\.isWhitespace) }

        // If all lines are empty/whitespace-only, return unchanged
        guard !nonEmptyLines.isEmpty else {
            return text
        }

        // Calculate minimum indentation (in spaces, treating tab as 4 spaces)
        let minIndent = nonEmptyLines
            .map { self.countLeadingWhitespace($0) }
            .min() ?? 0

        // Apply maximum limit from config
        let stripAmount = min(minIndent, self.config.maximumStrip)

        // If nothing to strip, return unchanged
        guard stripAmount > 0 else {
            return text
        }

        // Strip from each line
        let strippedLines = lines.map { line -> String in
            self.stripLeadingWhitespace(from: line, amount: stripAmount)
        }

        return strippedLines.joined(separator: "\n")
    }

    /// Counts leading whitespace in a line, treating tabs as 4 spaces.
    private func countLeadingWhitespace(_ line: String) -> Int {
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

    /// Strips a specified amount of whitespace from the beginning of a line.
    private func stripLeadingWhitespace(from line: String, amount: Int) -> String {
        var remaining = amount
        var index = line.startIndex

        while remaining > 0, index < line.endIndex {
            let char = line[index]
            if char == " " {
                remaining -= 1
                index = line.index(after: index)
            } else if char == "\t" {
                // Tab consumes up to 4 spaces worth
                let tabValue = min(4, remaining)
                remaining -= tabValue
                index = line.index(after: index)
            } else {
                // Non-whitespace reached, stop stripping
                break
            }
        }

        return String(line[index...])
    }

    /// Strips trailing whitespace (spaces and tabs) from each line.
    private func stripTrailingWhitespace(_ text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0) }

        let trimmedLines = lines.map { line -> String in
            var endIndex = line.endIndex
            while endIndex > line.startIndex {
                let prevIndex = line.index(before: endIndex)
                let char = line[prevIndex]
                if char == " " || char == "\t" {
                    endIndex = prevIndex
                } else {
                    break
                }
            }
            return String(line[line.startIndex ..< endIndex])
        }

        return trimmedLines.joined(separator: "\n")
    }
}
