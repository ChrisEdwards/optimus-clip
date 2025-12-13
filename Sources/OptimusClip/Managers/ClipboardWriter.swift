import AppKit

/// Errors that can occur during clipboard write operations.
public enum ClipboardWriteError: Error, Sendable, Equatable {
    /// Failed to write text content to clipboard.
    case textWriteFailed

    /// Failed to write self-write marker to clipboard.
    /// Text may have been written but loop prevention marker is missing.
    case markerWriteFailed

    /// Clipboard is unavailable (rare system error).
    case clipboardUnavailable

    /// User-friendly error message.
    public var message: String {
        switch self {
        case .textWriteFailed:
            "Failed to write text to clipboard"
        case .markerWriteFailed:
            "Failed to write clipboard marker (text may still be written)"
        case .clipboardUnavailable:
            "Clipboard is unavailable"
        }
    }
}

/// Writes transformed text to the system clipboard with self-write marker.
///
/// After transforming clipboard content, Optimus Clip writes the result back
/// to the clipboard. This write MUST include the self-write marker to prevent
/// ClipboardMonitor from reprocessing our own writes.
///
/// ## The Problem Without Markers
/// 1. User copies text → clipboard changes
/// 2. App reads → transforms → writes result
/// 3. Clipboard changes → app detects change (ITS OWN WRITE!)
/// 4. App reads → transforms again → infinite loop!
///
/// ## Solution
/// Include `SelfWriteMarker` with every write. ClipboardMonitor checks for
/// the marker and skips processing if present.
///
/// ## Usage
/// ```swift
/// // Simple write (recommended)
/// SelfWriteMarker.write("transformed text")
///
/// // Using ClipboardWriter for detailed error handling
/// switch await ClipboardWriter.shared.write("transformed text") {
/// case .success:
///     // Ready for paste simulation
/// case .failure(let error):
///     showError(error.message)
/// }
/// ```
///
/// ## Threading
/// All operations are MainActor-isolated for NSPasteboard safety.
/// Use async methods for proper main thread dispatch.
@MainActor
public final class ClipboardWriter {
    // MARK: - Singleton

    /// Shared clipboard writer instance.
    public static let shared = ClipboardWriter()

    // MARK: - State

    /// Flag indicating a write is in progress.
    /// ClipboardMonitor should skip processing while this is true.
    public private(set) var isWriting: Bool = false

    /// Duration to keep isWriting flag set after write completes.
    /// Allows clipboard to settle before monitoring resumes.
    private let settlingDelay: TimeInterval = 0.2

    // MARK: - Initialization

    private init() {}

    // MARK: - Write Operations

    /// Writes text to clipboard with self-write marker.
    ///
    /// This is the primary write method. It:
    /// 1. Sets `isWriting` flag to pause monitoring
    /// 2. Clears clipboard and declares types
    /// 3. Writes text content
    /// 4. Writes self-write marker
    /// 5. Clears flag after settling delay
    ///
    /// - Parameter text: The text to write to clipboard.
    /// - Returns: Result indicating success or specific failure reason.
    public func write(_ text: String) -> Result<Void, ClipboardWriteError> {
        // Set flag BEFORE writing to prevent monitoring
        self.isWriting = true

        // Perform the write
        let result = self.writeWithMarker(text)

        // Clear flag after delay to let clipboard settle
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(self.settlingDelay * 1_000_000_000))
            self.isWriting = false
        }

        return result
    }

    /// Writes text to clipboard with self-write marker (async version).
    ///
    /// - Parameter text: The text to write to clipboard.
    /// - Throws: `ClipboardWriteError` if write fails.
    public func writeAsync(_ text: String) async throws {
        let result = self.write(text)

        switch result {
        case .success:
            return
        case let .failure(error):
            throw error
        }
    }

    /// Writes text using the SelfWriteMarker utility.
    ///
    /// This is a convenience method that delegates to `SelfWriteMarker.write()`.
    /// Use when you don't need detailed error handling.
    ///
    /// - Parameter text: The text to write to clipboard.
    public func writeSimple(_ text: String) {
        self.isWriting = true
        SelfWriteMarker.write(text)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(self.settlingDelay * 1_000_000_000))
            self.isWriting = false
        }
    }

    // MARK: - Private

    /// Performs the actual write with marker.
    private func writeWithMarker(_ text: String) -> Result<Void, ClipboardWriteError> {
        let pasteboard = NSPasteboard.general

        // Declare both types atomically (clears clipboard)
        pasteboard.declareTypes([.string, SelfWriteMarker.markerType], owner: nil)

        // Write text content
        guard pasteboard.setString(text, forType: .string) else {
            return .failure(.textWriteFailed)
        }

        // Write marker (empty data - presence is what matters)
        guard pasteboard.setData(Data(), forType: SelfWriteMarker.markerType) else {
            // Text is written but marker failed
            // This is problematic but rare - keep text rather than losing it
            return .failure(.markerWriteFailed)
        }

        return .success(())
    }

    // MARK: - Advanced Write Operations

    /// Writes text with retry on failure.
    ///
    /// If the first write fails, waits briefly and tries once more.
    /// Useful when clipboard might be momentarily locked by another app.
    ///
    /// - Parameters:
    ///   - text: The text to write to clipboard.
    ///   - retryDelay: Delay before retry (default 0.1 seconds).
    /// - Returns: Result indicating success or failure after retry.
    public func writeWithRetry(
        _ text: String,
        retryDelay: TimeInterval = 0.1
    ) async -> Result<Void, ClipboardWriteError> {
        // First attempt
        let firstResult = self.write(text)

        if case .success = firstResult {
            return firstResult
        }

        // Wait and retry
        try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))

        return self.write(text)
    }

    /// Writes multiple content types to clipboard with marker.
    ///
    /// Use when you need to provide both plain text and rich text formats.
    ///
    /// - Parameters:
    ///   - text: Plain text content.
    ///   - rtf: Optional RTF data.
    ///   - html: Optional HTML string.
    /// - Returns: Result indicating success or failure.
    public func writeRich(text: String, rtf: Data? = nil, html: String? = nil) -> Result<Void, ClipboardWriteError> {
        self.isWriting = true

        let pasteboard = NSPasteboard.general

        // Build types list
        var types: [NSPasteboard.PasteboardType] = [.string, SelfWriteMarker.markerType]

        if rtf != nil {
            types.append(.rtf)
        }

        if html != nil {
            types.append(.html)
        }

        // Declare all types
        pasteboard.declareTypes(types, owner: nil)

        // Write text (required)
        guard pasteboard.setString(text, forType: .string) else {
            self.clearWritingFlagAfterDelay()
            return .failure(.textWriteFailed)
        }

        // Write marker
        guard pasteboard.setData(Data(), forType: SelfWriteMarker.markerType) else {
            self.clearWritingFlagAfterDelay()
            return .failure(.markerWriteFailed)
        }

        // Write optional RTF
        if let rtf {
            _ = pasteboard.setData(rtf, forType: .rtf)
        }

        // Write optional HTML
        if let html {
            _ = pasteboard.setString(html, forType: .html)
        }

        self.clearWritingFlagAfterDelay()
        return .success(())
    }

    /// Clears the isWriting flag after the settling delay.
    private func clearWritingFlagAfterDelay() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(self.settlingDelay * 1_000_000_000))
            self.isWriting = false
        }
    }
}
