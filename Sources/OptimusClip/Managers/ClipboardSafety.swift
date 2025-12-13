import AppKit

/// Types of content that can be on the clipboard.
public enum ClipboardContentType: Sendable, Equatable {
    /// Plain text or rich text that can be transformed.
    case text

    /// Binary content (image, file, PDF) that cannot be transformed.
    /// The associated value is the UTI type string.
    case binary(type: String)

    /// Empty clipboard - nothing to process.
    case empty

    /// Unknown content type - treat as non-processable.
    case unknown
}

/// Provides clipboard content type detection and binary safety checks.
///
/// LLM providers expect text input. Sending binary data (images, PDFs, files)
/// to a text-only API causes API errors, crashes, or wasted API calls.
///
/// ## Problem Scenario
/// 1. User takes screenshot (Cmd+Shift+4) → clipboard contains image
/// 2. User hits transformation hotkey
/// 3. App tries to send PNG bytes to GPT-4 → chaos
///
/// ## Solution
/// Check clipboard content type BEFORE processing:
/// - **Text types**: Process normally
/// - **Binary types**: Reject with clear user feedback
/// - **Unknown**: Treat as non-processable
///
/// ## Usage
/// ```swift
/// switch ClipboardSafety.detectContentType() {
/// case .text:
///     // Safe to transform
/// case .binary(let type):
///     // Show error: "Cannot transform \(ClipboardSafety.friendlyName(for: type))"
/// case .empty, .unknown:
///     // Nothing to do
/// }
/// ```
@MainActor
public enum ClipboardSafety {
    // MARK: - Binary Types

    /// Pasteboard types that indicate binary content.
    /// If ANY of these are present, clipboard should not be processed.
    public static let binaryTypes: Set<NSPasteboard.PasteboardType> = [
        // Images
        .png,
        .tiff,
        NSPasteboard.PasteboardType("public.jpeg"),
        NSPasteboard.PasteboardType("public.heic"),
        NSPasteboard.PasteboardType("public.gif"),
        NSPasteboard.PasteboardType("public.bmp"),
        NSPasteboard.PasteboardType("public.ico"),
        NSPasteboard.PasteboardType("public.svg-image"),

        // Files
        .fileURL,
        NSPasteboard.PasteboardType("public.file-url"),
        NSPasteboard.PasteboardType("com.apple.finder.node"),
        NSPasteboard.PasteboardType("NSFilenamesPboardType"),

        // Documents
        .pdf,
        NSPasteboard.PasteboardType("com.adobe.pdf"),
    ]

    /// Pasteboard types that indicate processable text content.
    public static let textTypes: Set<NSPasteboard.PasteboardType> = [
        .string,
        .rtf,
        .html,
        NSPasteboard.PasteboardType("public.utf8-plain-text"),
        NSPasteboard.PasteboardType("public.utf16-plain-text"),
        NSPasteboard.PasteboardType("public.utf16-external-plain-text"),
        NSPasteboard.PasteboardType("public.text"),
    ]

    // MARK: - Detection

    /// Detects the type of content currently on the clipboard.
    ///
    /// Binary types are checked FIRST because clipboard often contains multiple
    /// types simultaneously (e.g., copying from web includes HTML + text + image).
    ///
    /// - Returns: The detected content type.
    public static func detectContentType() -> ClipboardContentType {
        let pasteboard = NSPasteboard.general

        guard let types = pasteboard.types, !types.isEmpty else {
            return .empty
        }

        // Check for binary types FIRST (they should block processing)
        for type in types {
            if self.binaryTypes.contains(type) {
                return .binary(type: type.rawValue)
            }
        }

        // Check for text types
        for type in types {
            if self.textTypes.contains(type) {
                return .text
            }
        }

        return .unknown
    }

    /// Checks if the clipboard contains binary content.
    ///
    /// - Returns: `true` if any binary type is present.
    public static func containsBinaryContent() -> Bool {
        guard let types = NSPasteboard.general.types else {
            return false
        }
        return types.contains { self.binaryTypes.contains($0) }
    }

    /// Checks if the clipboard contains processable text content.
    ///
    /// - Returns: `true` if text is present and no binary content blocks processing.
    public static func containsProcessableText() -> Bool {
        if case .text = self.detectContentType() {
            return true
        }
        return false
    }

    // MARK: - User Feedback

    /// Returns a user-friendly description of a binary content type.
    ///
    /// - Parameter type: The UTI type string.
    /// - Returns: A human-readable description suitable for error messages.
    public nonisolated static func friendlyName(for type: String) -> String {
        switch type {
        // Images
        case "public.png", NSPasteboard.PasteboardType.png.rawValue:
            "an image (PNG)"
        case "public.jpeg", "public.jpg":
            "an image (JPEG)"
        case "public.tiff", NSPasteboard.PasteboardType.tiff.rawValue:
            "an image (TIFF)"
        case "public.heic":
            "an image (HEIC)"
        case "public.gif":
            "an image (GIF)"
        case "public.bmp":
            "an image (BMP)"
        case "public.ico":
            "an icon"
        case "public.svg-image":
            "an image (SVG)"
        // Files
        case "public.file-url", NSPasteboard.PasteboardType.fileURL.rawValue,
             "com.apple.finder.node", "NSFilenamesPboardType":
            "a file"
        // Documents
        case "com.adobe.pdf", NSPasteboard.PasteboardType.pdf.rawValue:
            "a PDF document"
        default:
            "non-text content"
        }
    }

    /// Returns a description of the current clipboard binary content.
    ///
    /// - Returns: A user-friendly description, or `nil` if no binary content.
    public static func binaryContentDescription() -> String? {
        guard let types = NSPasteboard.general.types else {
            return nil
        }

        for type in types {
            if self.binaryTypes.contains(type) {
                return self.friendlyName(for: type.rawValue)
            }
        }

        return nil
    }

    // MARK: - Safe Reading

    /// Reads clipboard text only if safe to process (no binary content).
    ///
    /// This combines binary safety check with text reading.
    /// Use this instead of direct NSPasteboard access.
    ///
    /// - Returns: The clipboard text, or `nil` if unsafe or no text.
    public static func readTextIfSafe() -> String? {
        guard case .text = self.detectContentType() else {
            return nil
        }

        return NSPasteboard.general.string(forType: .string)
    }

    /// Reads clipboard text with detailed result.
    ///
    /// - Returns: A result indicating success with text, or failure with reason.
    public static func readText() -> ClipboardReadResult {
        switch self.detectContentType() {
        case .text:
            if let text = NSPasteboard.general.string(forType: .string) {
                return .success(text)
            }
            return .failure(.noTextContent)

        case let .binary(type):
            return .failure(.binaryContent(type: type))

        case .empty:
            return .failure(.empty)

        case .unknown:
            return .failure(.unknownContent)
        }
    }
}

// MARK: - Read Result

/// Result of attempting to read text from clipboard.
public enum ClipboardReadResult: Sendable {
    /// Successfully read text from clipboard.
    case success(String)

    /// Failed to read text from clipboard.
    case failure(ClipboardReadError)
}

/// Reasons why clipboard text could not be read.
public enum ClipboardReadError: Sendable, Equatable {
    /// Clipboard is empty.
    case empty

    /// Clipboard contains binary content that cannot be transformed.
    case binaryContent(type: String)

    /// Clipboard has types but no actual text content.
    case noTextContent

    /// Clipboard content type is unknown/unrecognized.
    case unknownContent

    /// User-friendly error message.
    public var message: String {
        switch self {
        case .empty:
            "Clipboard is empty"
        case let .binaryContent(type):
            "Clipboard contains \(ClipboardSafety.friendlyName(for: type)) - only text can be transformed"
        case .noTextContent:
            "Clipboard doesn't contain text"
        case .unknownContent:
            "Clipboard contains unrecognized content"
        }
    }
}
