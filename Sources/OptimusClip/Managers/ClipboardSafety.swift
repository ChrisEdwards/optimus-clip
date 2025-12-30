import AppKit
import OptimusClipCore

// Re-export ClipboardContentType, ClipboardReadResult, and ClipboardReadError from OptimusClipCore
// so consumers can use them without importing OptimusClipCore directly.
public typealias ClipboardContentType = OptimusClipCore.ClipboardContentType
public typealias ClipboardReadResult = OptimusClipCore.ClipboardReadResult
public typealias ClipboardReadError = OptimusClipCore.ClipboardReadError

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
    ///
    /// This list must be comprehensive to prevent binary data from reaching
    /// LLM APIs. Missing types cause crashes, API errors, or wasted calls.
    public static let binaryTypes: Set<NSPasteboard.PasteboardType> = [
        // Images
        .png,
        .tiff,
        NSPasteboard.PasteboardType("public.jpeg"),
        NSPasteboard.PasteboardType("public.heic"),
        NSPasteboard.PasteboardType("public.heif"),
        NSPasteboard.PasteboardType("public.gif"),
        NSPasteboard.PasteboardType("public.bmp"),
        NSPasteboard.PasteboardType("public.webp"),
        NSPasteboard.PasteboardType("public.ico"),
        NSPasteboard.PasteboardType("public.svg-image"),
        NSPasteboard.PasteboardType("com.apple.icns"),

        // Files
        .fileURL,
        NSPasteboard.PasteboardType("public.file-url"),
        NSPasteboard.PasteboardType("com.apple.finder.node"),
        NSPasteboard.PasteboardType("NSFilenamesPboardType"),
        NSPasteboard.PasteboardType("public.url"),

        // Documents
        .pdf,
        NSPasteboard.PasteboardType("com.adobe.pdf"),
        NSPasteboard.PasteboardType("public.pdf"),

        // Video (including screen recordings)
        NSPasteboard.PasteboardType("public.movie"),
        NSPasteboard.PasteboardType("public.video"),
        NSPasteboard.PasteboardType("com.apple.quicktime-movie"),
        NSPasteboard.PasteboardType("public.mpeg-4"),
        NSPasteboard.PasteboardType("com.apple.m4v-video"),

        // Audio
        NSPasteboard.PasteboardType("public.audio"),
        NSPasteboard.PasteboardType("public.mp3"),
        NSPasteboard.PasteboardType("com.apple.m4a-audio"),
        NSPasteboard.PasteboardType("public.aiff-audio"),

        // Archives
        NSPasteboard.PasteboardType("public.zip-archive"),
        NSPasteboard.PasteboardType("org.gnu.gnu-tar-archive"),
        NSPasteboard.PasteboardType("public.archive"),
        NSPasteboard.PasteboardType("com.apple.bom-compressed-cpio"),

        // Raw data that should never be processed
        NSPasteboard.PasteboardType("public.data"),
        NSPasteboard.PasteboardType("public.content")
    ]

    /// Pasteboard types that indicate processable text content.
    public static let textTypes: Set<NSPasteboard.PasteboardType> = [
        .string,
        .rtf,
        .html,
        NSPasteboard.PasteboardType("public.utf8-plain-text"),
        NSPasteboard.PasteboardType("public.utf16-plain-text"),
        NSPasteboard.PasteboardType("public.utf16-external-plain-text"),
        NSPasteboard.PasteboardType("public.text")
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

        // Check for text types
        if types.contains(where: { self.textTypes.contains($0) }) {
            return .text
        }

        // Check for binary types after text so URLs with string fall through to text
        if let binaryType = types.first(where: { self.binaryTypes.contains($0) }) {
            return .binary(type: binaryType.rawValue)
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

    /// Mapping of UTI types to human-readable descriptions.
    private nonisolated static let typeDescriptions: [String: String] = {
        var map: [String: String] = [
            // Images
            "public.png": "an image (PNG)",
            "public.jpeg": "an image (JPEG)",
            "public.jpg": "an image (JPEG)",
            "public.tiff": "an image (TIFF)",
            "public.heic": "an image (HEIC)",
            "public.heif": "an image (HEIF)",
            "public.gif": "an image (GIF)",
            "public.bmp": "an image (BMP)",
            "public.webp": "an image (WebP)",
            "public.ico": "an icon",
            "public.svg-image": "an image (SVG)",
            "com.apple.icns": "an icon",
            // Files
            "public.file-url": "a file",
            "public.url": "a URL",
            "com.apple.finder.node": "a file",
            "NSFilenamesPboardType": "a file",
            // Documents
            "com.adobe.pdf": "a PDF document",
            "public.pdf": "a PDF document",
            // Video
            "public.movie": "a video",
            "public.video": "a video",
            "com.apple.quicktime-movie": "a video (QuickTime)",
            "public.mpeg-4": "a video (MP4)",
            "com.apple.m4v-video": "a video (M4V)",
            // Audio
            "public.audio": "audio",
            "public.mp3": "audio (MP3)",
            "com.apple.m4a-audio": "audio (M4A)",
            "public.aiff-audio": "audio (AIFF)",
            // Archives
            "public.zip-archive": "an archive (ZIP)",
            "org.gnu.gnu-tar-archive": "an archive (TAR)",
            "public.archive": "an archive",
            "com.apple.bom-compressed-cpio": "an archive",
            // Raw data
            "public.data": "binary data",
            "public.content": "non-text content"
        ]
        // Add NSPasteboard type raw values
        map[NSPasteboard.PasteboardType.png.rawValue] = "an image (PNG)"
        map[NSPasteboard.PasteboardType.tiff.rawValue] = "an image (TIFF)"
        map[NSPasteboard.PasteboardType.fileURL.rawValue] = "a file"
        map[NSPasteboard.PasteboardType.pdf.rawValue] = "a PDF document"
        return map
    }()

    /// Returns a user-friendly description of a binary content type.
    ///
    /// - Parameter type: The UTI type string.
    /// - Returns: A human-readable description suitable for error messages.
    public nonisolated static func friendlyName(for type: String) -> String {
        self.typeDescriptions[type] ?? "non-text content"
    }

    /// Returns a description of the current clipboard binary content.
    ///
    /// - Returns: A user-friendly description, or `nil` if no binary content.
    public static func binaryContentDescription() -> String? {
        guard let types = NSPasteboard.general.types else {
            return nil
        }

        guard let binaryType = types.first(where: { self.binaryTypes.contains($0) }) else {
            return nil
        }
        return self.friendlyName(for: binaryType.rawValue)
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
