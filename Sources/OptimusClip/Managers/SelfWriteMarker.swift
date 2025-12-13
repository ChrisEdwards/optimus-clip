import AppKit

/// Prevents infinite loops by marking clipboard writes from Optimus Clip.
///
/// Without self-write detection, the app would enter an infinite loop:
/// 1. User copies text → clipboard changes
/// 2. App detects change → reads clipboard
/// 3. App transforms text → writes to clipboard
/// 4. Clipboard changes → app detects its own write
/// 5. GOTO 4 (infinite loop)
///
/// The marker solves this by "tagging" our clipboard writes with a custom
/// pasteboard type that only we recognize.
///
/// ## How It Works
/// - When writing: Include both the text AND our marker type
/// - When reading: Check if marker is present → skip if it's our write
/// - Other apps: Only see/read the text, marker is invisible to them
///
/// ## Why This Approach
/// - **No race conditions**: Unlike change count tracking
/// - **No timing issues**: Unlike timestamp-based detection
/// - **100% deterministic**: Marker presence is binary
/// - **Industry standard**: Used by Paste, Maccy, and other clipboard apps
///
/// ## Usage
/// ```swift
/// // Check before processing clipboard content
/// if SelfWriteMarker.isSafeToProcess() {
///     let text = NSPasteboard.general.string(forType: .string)
///     // Process external clipboard content...
/// }
///
/// // Write transformed text with marker
/// SelfWriteMarker.write("transformed text")
/// ```
@MainActor
public enum SelfWriteMarker {
    // MARK: - Types

    /// Custom pasteboard type used as our self-write marker.
    /// Reverse DNS format ensures uniqueness across all apps.
    public static let markerType = NSPasteboard.PasteboardType("com.optimusclip.marker")

    // MARK: - Reading

    /// Checks if clipboard content is safe to process (not our own write).
    ///
    /// - Returns: `true` if clipboard content is from an external source;
    ///           `false` if it's our own write (marker present).
    ///
    /// - Note: Call this before processing clipboard content to prevent infinite loops.
    public static func isSafeToProcess() -> Bool {
        let pasteboard = NSPasteboard.general

        guard let types = pasteboard.types else {
            // No types means empty clipboard - nothing to process
            return false
        }

        // If our marker is present, this is our own write - skip it
        return !types.contains(self.markerType)
    }

    /// Reads clipboard text only if safe to process (not our own write).
    ///
    /// Convenience method combining `isSafeToProcess()` with text reading.
    ///
    /// - Returns: The clipboard text if it's from an external source;
    ///           `nil` if it's our write or clipboard has no text.
    public static func readTextIfSafe() -> String? {
        guard self.isSafeToProcess() else {
            return nil
        }

        return NSPasteboard.general.string(forType: .string)
    }

    // MARK: - Writing

    /// Writes text to clipboard with our self-write marker.
    ///
    /// The marker allows future reads to identify this as our own write
    /// and skip processing it, preventing infinite loops.
    ///
    /// - Parameter text: The text to write to the clipboard.
    ///
    /// - Note: The marker is invisible to other apps - they only see the text.
    public static func write(_ text: String) {
        let pasteboard = NSPasteboard.general

        // Clear existing contents (required before declaring new types)
        pasteboard.clearContents()

        // Declare both the text type and our marker
        pasteboard.declareTypes([.string, self.markerType], owner: nil)

        // Write the actual text content
        pasteboard.setString(text, forType: .string)

        // Write empty data for marker (presence is what matters, not content)
        pasteboard.setData(Data(), forType: self.markerType)
    }

    /// Writes multiple content types to clipboard with our self-write marker.
    ///
    /// Use this when you need to write both plain text and rich text formats.
    ///
    /// - Parameters:
    ///   - text: Plain text content (written as `.string` type)
    ///   - rtf: Optional RTF data (written as `.rtf` type)
    ///   - html: Optional HTML string (written as `.html` type)
    public static func write(text: String, rtf: Data? = nil, html: String? = nil) {
        let pasteboard = NSPasteboard.general

        // Build list of types to declare
        var types: [NSPasteboard.PasteboardType] = [.string, self.markerType]

        if rtf != nil {
            types.append(.rtf)
        }

        if html != nil {
            types.append(.html)
        }

        // Clear and declare all types
        pasteboard.clearContents()
        pasteboard.declareTypes(types, owner: nil)

        // Write all content
        pasteboard.setString(text, forType: .string)
        pasteboard.setData(Data(), forType: self.markerType)

        if let rtf {
            pasteboard.setData(rtf, forType: .rtf)
        }

        if let html {
            pasteboard.setString(html, forType: .html)
        }
    }

    // MARK: - Debugging

    /// Checks if the clipboard currently contains our marker.
    ///
    /// Useful for debugging and testing.
    ///
    /// - Returns: `true` if our marker is present in the clipboard.
    public static func hasMarker() -> Bool {
        NSPasteboard.general.types?.contains(self.markerType) ?? false
    }
}
