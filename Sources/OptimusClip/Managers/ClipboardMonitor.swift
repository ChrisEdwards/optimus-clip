import AppKit

/// Protocol for receiving clipboard change notifications.
///
/// Implement this protocol to be notified when the system clipboard content changes.
/// The delegate receives the new text content after the grace delay period.
@MainActor
public protocol ClipboardMonitorDelegate: AnyObject {
    /// Called when clipboard text content has changed.
    ///
    /// - Parameter text: The new clipboard text, or `nil` if clipboard contains non-text content.
    func clipboardDidChange(text: String?)
}

/// Monitors the system clipboard for changes using efficient polling.
///
/// macOS doesn't provide clipboard change notifications, so this class polls
/// `NSPasteboard.general.changeCount` to detect when content changes. The implementation
/// uses `DispatchSourceTimer` for power-efficient scheduling.
///
/// ## Polling Strategy
/// - **Interval**: 150ms (7 checks per second) balances responsiveness with efficiency
/// - **Leeway**: 50ms allows the system to coalesce timer events for power savings
/// - **Grace Delay**: 80ms wait after detecting change, allowing "promised" data to resolve
///
/// ## Text Reading
/// Uses multiple fallback strategies for reading text:
/// 1. `NSPasteboard.string(forType: .string)` - most common
/// 2. `readObjects(forClasses: [NSString.self])` - public.utf8-plain-text
/// 3. `data(forType: public.utf16-external-plain-text)` - UTF-16 encoded
/// 4. `data(forType: public.text)` - generic text
///
/// ## Usage
/// ```swift
/// let monitor = ClipboardMonitor()
/// monitor.delegate = self
/// monitor.startMonitoring()
/// // ... later
/// monitor.stopMonitoring()
/// ```
@MainActor
public final class ClipboardMonitor {
    // MARK: - Configuration

    /// Polling interval between clipboard checks.
    /// 150ms provides responsive detection without excessive CPU usage.
    private let pollInterval: TimeInterval = 0.15

    /// Timer leeway for power efficiency.
    /// Allows system to coalesce events, reducing battery impact on laptops.
    private let leeway: DispatchTimeInterval = .milliseconds(50)

    /// Grace delay after detecting change before reading content.
    /// Some apps use "promised" data (lazy loading) that isn't immediately available.
    private let graceDelay: TimeInterval = 0.08

    // MARK: - State

    /// The delegate to notify of clipboard changes.
    public weak var delegate: ClipboardMonitorDelegate?

    /// The underlying dispatch timer source.
    private var timer: DispatchSourceTimer?

    /// Last observed change count from NSPasteboard.
    /// Used to detect when clipboard content has changed.
    private var lastChangeCount: Int = 0

    /// Whether monitoring is currently active.
    public private(set) var isMonitoring: Bool = false

    /// Whether monitoring is currently suspended.
    /// When suspended, the timer is paused but not invalidated.
    public private(set) var isSuspended: Bool = false

    // MARK: - Initialization

    /// Creates a new clipboard monitor.
    ///
    /// Call `startMonitoring()` to begin detecting clipboard changes.
    public init() {
        // Initialize lastChangeCount to current value to avoid triggering
        // on content that was already in the clipboard before monitoring started.
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    deinit {
        // Ensure timer is properly cleaned up.
        // Note: This is MainActor-isolated, so cleanup is safe.
        self.timer?.cancel()
        self.timer = nil
    }

    // MARK: - Lifecycle

    /// Starts monitoring the clipboard for changes.
    ///
    /// Creates and starts a `DispatchSourceTimer` that polls the clipboard
    /// at the configured interval. Safe to call multiple times; subsequent
    /// calls are ignored if already monitoring.
    ///
    /// - Note: Monitoring occurs on the main queue for NSPasteboard access safety.
    public func startMonitoring() {
        guard !self.isMonitoring else { return }

        // Sync lastChangeCount to prevent false positive on first check
        self.lastChangeCount = NSPasteboard.general.changeCount

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(
            deadline: .now(),
            repeating: self.pollInterval,
            leeway: self.leeway
        )
        timer.setEventHandler { [weak self] in
            // Must be MainActor to access self properties safely
            MainActor.assumeIsolated {
                self?.checkClipboard()
            }
        }
        timer.resume()

        self.timer = timer
        self.isMonitoring = true
        self.isSuspended = false
    }

    /// Stops monitoring the clipboard.
    ///
    /// Cancels and releases the underlying timer. Safe to call multiple times;
    /// subsequent calls are ignored if not monitoring.
    public func stopMonitoring() {
        guard self.isMonitoring else { return }

        self.timer?.cancel()
        self.timer = nil
        self.isMonitoring = false
        self.isSuspended = false
    }

    /// Suspends clipboard monitoring temporarily.
    ///
    /// The timer is suspended but not invalidated, allowing quick resumption.
    /// Use this when the app becomes inactive or during certain operations.
    ///
    /// - Note: Only effective when monitoring is active and not already suspended.
    public func suspend() {
        guard self.isMonitoring, !self.isSuspended else { return }

        self.timer?.suspend()
        self.isSuspended = true
    }

    /// Resumes clipboard monitoring after suspension.
    ///
    /// - Note: Only effective when monitoring is active and currently suspended.
    public func resume() {
        guard self.isMonitoring, self.isSuspended else { return }

        // Sync lastChangeCount to avoid triggering on changes during suspension
        self.lastChangeCount = NSPasteboard.general.changeCount

        self.timer?.resume()
        self.isSuspended = false
    }

    // MARK: - Internal

    /// Checks if clipboard content has changed.
    ///
    /// Called by the timer on each poll interval. If changeCount differs from
    /// the last observed value, schedules a delayed read to handle promised data.
    private func checkClipboard() {
        let currentCount = NSPasteboard.general.changeCount

        guard currentCount != self.lastChangeCount else { return }

        self.lastChangeCount = currentCount

        // Wait grace period for promised data to resolve before reading
        DispatchQueue.main.asyncAfter(deadline: .now() + self.graceDelay) { [weak self] in
            MainActor.assumeIsolated {
                self?.readClipboardContent()
            }
        }
    }

    /// Reads text content from the clipboard using multiple fallback strategies.
    ///
    /// Different apps write clipboard content using different UTI types.
    /// This method tries several approaches to maximize compatibility.
    private func readClipboardContent() {
        let text = self.readTextFromPasteboard()
        self.delegate?.clipboardDidChange(text: text)
    }

    /// Attempts to read text from NSPasteboard using multiple fallback strategies.
    ///
    /// - Returns: The clipboard text content, or `nil` if no text is available.
    private func readTextFromPasteboard() -> String? {
        let pasteboard = NSPasteboard.general

        // Strategy 1: Direct string read (most common)
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            return text
        }

        // Strategy 2: Read objects for NSString class
        if let objects = pasteboard.readObjects(forClasses: [NSString.self], options: nil),
           let text = objects.first as? String, !text.isEmpty {
            return text
        }

        // Strategy 3: UTF-16 external plain text (some apps use this)
        let utf16Type = NSPasteboard.PasteboardType("public.utf16-external-plain-text")
        if let data = pasteboard.data(forType: utf16Type),
           let text = String(data: data, encoding: .utf16), !text.isEmpty {
            return text
        }

        // Strategy 4: Generic public.text (last resort)
        let textType = NSPasteboard.PasteboardType("public.text")
        if let data = pasteboard.data(forType: textType),
           let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return text
        }

        // No text content found
        return nil
    }
}
