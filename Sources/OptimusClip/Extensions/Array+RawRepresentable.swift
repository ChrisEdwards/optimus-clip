import Foundation

// MARK: - Array+RawRepresentable

/// Extension to make arrays of Codable elements work with @AppStorage.
///
/// @AppStorage natively supports basic types (Bool, Int, Double, String),
/// but not complex types like arrays of structs. This extension bridges
/// that gap by conforming Array to RawRepresentable with a String raw value.
///
/// ## How It Works
/// 1. When setting a value, the array is JSON-encoded to a String
/// 2. When getting a value, the String is JSON-decoded back to an Array
/// 3. If encoding/decoding fails, returns empty array or "[]"
///
/// ## Usage
/// ```swift
/// @AppStorage("transformations") private var transformations: [TransformationConfig] = []
/// ```
///
/// ## Performance
/// - JSON encoding is fast for small arrays (<1ms for dozens of items)
/// - UserDefaults handles disk writes asynchronously
/// - Safe to write frequently (internally debounced)
///
/// ## Limitations
/// - Only works with Codable elements
/// - Array elements must be consistent (no type erasure)
/// - Large arrays (1000+ items) should use SwiftData instead
///
/// ## Error Handling
/// - Corrupt JSON returns nil (empty array fallback)
/// - Encoding failures return "[]" string
/// - This is intentional: settings should never crash the app
extension Array: @retroactive RawRepresentable where Element: Codable {
    /// Initialize from a JSON string.
    ///
    /// - Parameter rawValue: JSON-encoded string representation of the array.
    /// - Returns: Decoded array, or nil if decoding fails.
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data) else {
            return nil
        }
        self = result
    }

    /// JSON string representation of the array.
    ///
    /// - Returns: JSON-encoded string, or "[]" if encoding fails.
    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return result
    }
}
