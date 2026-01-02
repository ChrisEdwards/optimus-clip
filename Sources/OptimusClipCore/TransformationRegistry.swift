import Foundation

/// Category of transformation for organizational purposes.
public enum TransformationCategory: Sendable {
    /// LLM-powered transformations
    case llm
    /// Custom LLM transforms created by user
    case userDefined
}

/// Entry in the transformation registry.
public struct RegistryEntry: Sendable {
    /// The transformation instance
    public let transformation: any Transformation
    /// Whether this transformation is currently enabled
    public var isEnabled: Bool
    /// Category (builtin or user-defined)
    public let category: TransformationCategory
    /// When the transformation was registered
    public let createdAt: Date

    /// Creates a registry entry.
    public init(
        transformation: any Transformation,
        isEnabled: Bool = true,
        category: TransformationCategory,
        createdAt: Date = Date()
    ) {
        self.transformation = transformation
        self.isEnabled = isEnabled
        self.category = category
        self.createdAt = createdAt
    }
}

/// Central registry for all transformations in the application.
///
/// The registry provides:
/// - ID-based lookup for hotkey mapping
/// - Enable/disable state management per transformation
/// - Discovery of all available transformations for UI
/// - Thread-safe concurrent access via @MainActor
///
/// ## Usage
/// ```swift
/// // Get a transformation by ID
/// let transform = TransformationRegistry.shared.transformation(for: "my-transform")
///
/// // List all transformations
/// let all = TransformationRegistry.shared.allTransformations()
///
/// // Enable/disable
/// TransformationRegistry.shared.setEnabled(false, for: "my-transform")
/// ```
///
/// ## Design Decisions
/// - @MainActor for UI safety (no explicit locks needed)
/// - Singleton pattern for global access
/// - Testable via internal initializer
@MainActor
public final class TransformationRegistry {
    /// Shared singleton instance for production use.
    public static let shared = TransformationRegistry()

    /// Storage for registered transformations, keyed by ID.
    private var transformations: [String: RegistryEntry] = [:]

    /// Creates a registry instance.
    public init() {}

    // MARK: - Registration

    /// Register a new transformation.
    ///
    /// - Parameters:
    ///   - transformation: The transformation to register
    ///   - category: Built-in or user-defined (default: userDefined)
    ///   - enabled: Initial enabled state (default: true)
    /// - Returns: True if registered successfully, false if ID already exists
    @discardableResult
    public func register(
        _ transformation: any Transformation,
        category: TransformationCategory = .userDefined,
        enabled: Bool = true
    ) -> Bool {
        let id = transformation.id

        // Check for duplicate ID
        guard self.transformations[id] == nil else {
            return false
        }

        // Register
        let entry = RegistryEntry(
            transformation: transformation,
            isEnabled: enabled,
            category: category
        )

        self.transformations[id] = entry
        return true
    }

    /// Unregister a transformation by ID.
    ///
    /// - Parameter id: Transformation ID to remove
    /// - Returns: True if unregistered, false if not found
    @discardableResult
    public func unregister(_ id: String) -> Bool {
        guard self.transformations.removeValue(forKey: id) != nil else {
            return false
        }
        return true
    }

    // MARK: - Lookup

    /// Get transformation by ID (only if enabled).
    ///
    /// - Parameter id: Transformation ID
    /// - Returns: Transformation if found and enabled, nil otherwise
    public func transformation(for id: String) -> (any Transformation)? {
        guard let entry = self.transformations[id], entry.isEnabled else {
            return nil
        }
        return entry.transformation
    }

    /// Get transformation by ID regardless of enabled state.
    ///
    /// - Parameter id: Transformation ID
    /// - Returns: Transformation if found, nil otherwise
    public func transformationIgnoringEnabled(for id: String) -> (any Transformation)? {
        self.transformations[id]?.transformation
    }

    /// Get all transformations (regardless of enabled state).
    ///
    /// - Returns: Array of all registered transformations
    public func allTransformations() -> [any Transformation] {
        self.transformations.values.map(\.transformation)
    }

    /// Get transformations by category.
    ///
    /// - Parameter category: Built-in or user-defined
    /// - Returns: Array of transformations in that category
    public func transformations(in category: TransformationCategory) -> [any Transformation] {
        self.transformations.values
            .filter { $0.category == category }
            .map(\.transformation)
    }

    /// Get enabled transformations only.
    ///
    /// - Returns: Array of enabled transformations
    public func enabledTransformations() -> [any Transformation] {
        self.transformations.values
            .filter(\.isEnabled)
            .map(\.transformation)
    }

    /// Check if transformation exists.
    ///
    /// - Parameter id: Transformation ID
    /// - Returns: True if registered, false otherwise
    public func exists(_ id: String) -> Bool {
        self.transformations[id] != nil
    }

    // MARK: - State Management

    /// Enable or disable a transformation.
    ///
    /// - Parameters:
    ///   - enabled: New enabled state
    ///   - id: Transformation ID
    /// - Returns: True if updated, false if not found
    @discardableResult
    public func setEnabled(_ enabled: Bool, for id: String) -> Bool {
        guard var entry = self.transformations[id] else {
            return false
        }

        entry.isEnabled = enabled
        self.transformations[id] = entry
        return true
    }

    /// Check if transformation is enabled.
    ///
    /// - Parameter id: Transformation ID
    /// - Returns: True if enabled, false if disabled or not found
    public func isEnabled(_ id: String) -> Bool {
        self.transformations[id]?.isEnabled ?? false
    }

    /// Enable all transformations.
    public func enableAll() {
        for (id, var entry) in self.transformations {
            entry.isEnabled = true
            self.transformations[id] = entry
        }
    }

    /// Disable all transformations.
    public func disableAll() {
        for (id, var entry) in self.transformations {
            entry.isEnabled = false
            self.transformations[id] = entry
        }
    }

    // MARK: - Convenience

    /// Get transformation display names for UI.
    ///
    /// - Returns: Dictionary mapping IDs to display names
    public func transformationNames() -> [String: String] {
        Dictionary(
            uniqueKeysWithValues: self.transformations.map { id, entry in
                (id, entry.transformation.displayName)
            }
        )
    }

    /// Get all registry entries.
    ///
    /// - Returns: Array of all registry entries (includes enabled state and category)
    public func allEntries() -> [RegistryEntry] {
        Array(self.transformations.values)
    }

    /// Get entry for a specific transformation.
    ///
    /// - Parameter id: Transformation ID
    /// - Returns: Registry entry if found, nil otherwise
    public func entry(for id: String) -> RegistryEntry? {
        self.transformations[id]
    }

    /// Get count of registered transformations.
    public var count: Int {
        self.transformations.count
    }

    /// Get count of enabled transformations.
    public var enabledCount: Int {
        self.transformations.values.filter(\.isEnabled).count
    }

    /// Get all transformation IDs.
    public var allIDs: [String] {
        Array(self.transformations.keys)
    }

    /// Clear all registrations (useful for testing).
    public func clear() {
        self.transformations.removeAll()
    }
}
