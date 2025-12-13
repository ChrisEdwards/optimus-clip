/// Represents the type of content currently on the clipboard.
///
/// Used for binary safety detection to prevent sending non-text data to LLM APIs.
/// The transformation pipeline should only process `.text` content; all other types
/// should be rejected with appropriate user feedback.
///
/// ## Why This Matters
/// - LLM APIs expect text input; binary data causes errors or crashes
/// - Users get confusing errors if we try to transform images/files
/// - Preserving clipboard content on rejection provides better UX
public enum ClipboardContentType: Sendable, Equatable {
    /// Clipboard contains processable text content.
    /// This includes plain text, RTF (stripped to plain), and HTML (text extracted).
    case text

    /// Clipboard contains binary data that cannot be processed.
    /// The associated value is the UTI type string (e.g., "public.png").
    case binary(type: String)

    /// Clipboard is empty or has no recognizable content.
    case empty

    /// Clipboard contains content of unknown type.
    /// Treat as non-processable to be safe.
    case unknown
}

// MARK: - User-Friendly Descriptions

extension ClipboardContentType {
    /// Returns a human-readable description of the content type for user feedback.
    ///
    /// Used in notifications and error messages when binary content is detected.
    ///
    /// - Returns: A friendly string like "an image" or "a PDF".
    public var friendlyDescription: String {
        switch self {
        case .text:
            "text"
        case let .binary(type):
            Self.friendlyTypeName(for: type)
        case .empty:
            "nothing"
        case .unknown:
            "unknown content"
        }
    }

    /// Returns whether this content type is safe to process with transformations.
    ///
    /// Only `.text` content can be safely sent to LLM APIs or algorithmic transformers.
    public var isProcessable: Bool {
        switch self {
        case .text:
            true
        case .binary, .empty, .unknown:
            false
        }
    }

    /// Converts a UTI type string to a user-friendly description.
    ///
    /// - Parameter type: The UTI type string (e.g., "public.png", "com.adobe.pdf").
    /// - Returns: A friendly description like "an image" or "a PDF".
    public static func friendlyTypeName(for type: String) -> String {
        // Image types
        if self.imageTypes.contains(type) {
            return "an image"
        }

        // File URL types
        if self.fileTypes.contains(type) {
            return "a file"
        }

        // PDF
        if type == "com.adobe.pdf" || type == "public.pdf" {
            return "a PDF"
        }

        // Archive types
        if self.archiveTypes.contains(type) {
            return "an archive"
        }

        // Audio types
        if self.audioTypes.contains(type) {
            return "audio"
        }

        // Video types
        if self.videoTypes.contains(type) {
            return "video"
        }

        // Default fallback
        return "non-text content"
    }

    // MARK: - Type Constants

    /// Known image UTI types.
    // swiftlint:disable trailing_comma
    public static let imageTypes: Set<String> = [
        "public.png",
        "public.jpeg",
        "public.tiff",
        "public.heic",
        "public.heif",
        "public.gif",
        "public.bmp",
        "public.webp",
        "public.ico",
        "public.svg-image",
        "com.apple.icns",
    ]

    /// Known file URL UTI types.
    public static let fileTypes: Set<String> = [
        "public.file-url",
        "com.apple.finder.node",
        "public.url",
        "NSFilenamesPboardType",
    ]

    /// Known archive UTI types.
    public static let archiveTypes: Set<String> = [
        "public.zip-archive",
        "org.gnu.gnu-tar-archive",
        "public.archive",
    ]

    /// Known audio UTI types.
    public static let audioTypes: Set<String> = [
        "public.audio",
        "public.mp3",
        "com.apple.m4a-audio",
    ]

    /// Known video UTI types.
    public static let videoTypes: Set<String> = [
        "public.movie",
        "public.video",
        "com.apple.quicktime-movie",
    ]
    // swiftlint:enable trailing_comma
}

// MARK: - CustomStringConvertible

extension ClipboardContentType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .text:
            "ClipboardContentType.text"
        case let .binary(type):
            "ClipboardContentType.binary(\(type))"
        case .empty:
            "ClipboardContentType.empty"
        case .unknown:
            "ClipboardContentType.unknown"
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
            "Clipboard contains \(ClipboardContentType.friendlyTypeName(for: type)) - only text can be transformed"
        case .noTextContent:
            "Clipboard doesn't contain text"
        case .unknownContent:
            "Clipboard contains unrecognized content"
        }
    }
}
