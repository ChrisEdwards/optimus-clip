import Testing
@testable import OptimusClipCore

/// Test suite for TransformationRegistry.
///
/// Tests cover:
/// - Registration and unregistration
/// - Lookup by ID (with enabled/disabled states)
/// - Enable/disable state management
/// - Category filtering
/// - Edge cases (duplicates, missing IDs)
@Suite("TransformationRegistry Tests")
struct TransformationRegistryTests {
    // MARK: - Helper Mock Transformation

    /// Mock transformation for testing registry behavior.
    struct MockTransformation: Transformation {
        let id: String
        let displayName: String

        init(id: String = "mock", displayName: String = "Mock Transformation") {
            self.id = id
            self.displayName = displayName
        }

        func transform(_ input: String) async throws -> String {
            input
        }
    }

    // MARK: - Initialization Tests

    @Test("Registry auto-registers built-in transformations by default")
    @MainActor
    func autoRegistersBuiltIns() {
        let registry = TransformationRegistry(registerBuiltIns: true)

        // Check built-ins are registered
        #expect(registry.exists("whitespace-strip"))
        #expect(registry.exists("smart-unwrap"))
        #expect(registry.exists("identity"))
    }

    @Test("Registry can be created without built-ins for testing")
    @MainActor
    func emptyRegistryForTesting() {
        let registry = TransformationRegistry(registerBuiltIns: false)

        #expect(registry.count == 0)
        #expect(!registry.exists("whitespace-strip"))
    }

    // MARK: - Registration Tests

    @Test("Register transformation returns true on success")
    @MainActor
    func registerSuccess() {
        let registry = TransformationRegistry(registerBuiltIns: false)
        let mock = MockTransformation(id: "test-1", displayName: "Test 1")

        let result = registry.register(mock)

        #expect(result == true)
        #expect(registry.exists("test-1"))
        #expect(registry.count == 1)
    }

    @Test("Register with duplicate ID returns false")
    @MainActor
    func registerDuplicateID() {
        let registry = TransformationRegistry(registerBuiltIns: false)
        let mock1 = MockTransformation(id: "test", displayName: "Test 1")
        let mock2 = MockTransformation(id: "test", displayName: "Test 2")

        let result1 = registry.register(mock1)
        let result2 = registry.register(mock2)

        #expect(result1 == true)
        #expect(result2 == false)
        #expect(registry.count == 1)

        // First registration wins
        let stored = registry.transformationIgnoringEnabled(for: "test")
        #expect(stored?.displayName == "Test 1")
    }

    @Test("Register with category sets correct category")
    @MainActor
    func registerWithCategory() {
        let registry = TransformationRegistry(registerBuiltIns: false)
        let builtin = MockTransformation(id: "builtin-1", displayName: "Built-in")
        let user = MockTransformation(id: "user-1", displayName: "User")

        registry.register(builtin, category: .builtin)
        registry.register(user, category: .userDefined)

        let builtins = registry.transformations(in: .builtin)
        let userDefined = registry.transformations(in: .userDefined)

        #expect(builtins.count == 1)
        #expect(userDefined.count == 1)
        #expect(builtins.first?.id == "builtin-1")
        #expect(userDefined.first?.id == "user-1")
    }

    @Test("Register with enabled state sets correct state")
    @MainActor
    func registerWithEnabledState() {
        let registry = TransformationRegistry(registerBuiltIns: false)
        let enabled = MockTransformation(id: "enabled", displayName: "Enabled")
        let disabled = MockTransformation(id: "disabled", displayName: "Disabled")

        registry.register(enabled, enabled: true)
        registry.register(disabled, enabled: false)

        #expect(registry.isEnabled("enabled") == true)
        #expect(registry.isEnabled("disabled") == false)
    }

    // MARK: - Unregistration Tests

    @Test("Unregister returns true when found")
    @MainActor
    func unregisterSuccess() {
        let registry = TransformationRegistry(registerBuiltIns: false)
        let mock = MockTransformation(id: "test", displayName: "Test")

        registry.register(mock)
        let result = registry.unregister("test")

        #expect(result == true)
        #expect(!registry.exists("test"))
        #expect(registry.count == 0)
    }

    @Test("Unregister returns false when not found")
    @MainActor
    func unregisterNotFound() {
        let registry = TransformationRegistry(registerBuiltIns: false)

        let result = registry.unregister("nonexistent")

        #expect(result == false)
    }

    // MARK: - Lookup Tests

    @Test("Lookup returns transformation when enabled")
    @MainActor
    func lookupEnabled() {
        let registry = TransformationRegistry(registerBuiltIns: false)
        let mock = MockTransformation(id: "test", displayName: "Test")

        registry.register(mock, enabled: true)

        let result = registry.transformation(for: "test")

        #expect(result != nil)
        #expect(result?.id == "test")
    }

    @Test("Lookup returns nil when disabled")
    @MainActor
    func lookupDisabled() {
        let registry = TransformationRegistry(registerBuiltIns: false)
        let mock = MockTransformation(id: "test", displayName: "Test")

        registry.register(mock, enabled: false)

        let result = registry.transformation(for: "test")

        #expect(result == nil)
    }

    @Test("Lookup returns nil when not found")
    @MainActor
    func lookupNotFound() {
        let registry = TransformationRegistry(registerBuiltIns: false)

        let result = registry.transformation(for: "nonexistent")

        #expect(result == nil)
    }

    @Test("LookupIgnoringEnabled returns transformation regardless of state")
    @MainActor
    func lookupIgnoringEnabled() {
        let registry = TransformationRegistry(registerBuiltIns: false)
        let mock = MockTransformation(id: "test", displayName: "Test")

        registry.register(mock, enabled: false)

        let result = registry.transformationIgnoringEnabled(for: "test")

        #expect(result != nil)
        #expect(result?.id == "test")
    }

    // MARK: - State Management Tests

    @Test("SetEnabled updates transformation state")
    @MainActor
    func setEnabled() {
        let registry = TransformationRegistry(registerBuiltIns: false)
        let mock = MockTransformation(id: "test", displayName: "Test")

        registry.register(mock, enabled: true)
        #expect(registry.isEnabled("test") == true)

        registry.setEnabled(false, for: "test")
        #expect(registry.isEnabled("test") == false)

        registry.setEnabled(true, for: "test")
        #expect(registry.isEnabled("test") == true)
    }

    @Test("SetEnabled returns false for nonexistent ID")
    @MainActor
    func setEnabledNotFound() {
        let registry = TransformationRegistry(registerBuiltIns: false)

        let result = registry.setEnabled(true, for: "nonexistent")

        #expect(result == false)
    }

    @Test("IsEnabled returns false for nonexistent ID")
    @MainActor
    func isEnabledNotFound() {
        let registry = TransformationRegistry(registerBuiltIns: false)

        #expect(registry.isEnabled("nonexistent") == false)
    }

    @Test("EnableAll enables all transformations")
    @MainActor
    func enableAll() {
        let registry = TransformationRegistry(registerBuiltIns: false)
        let mock1 = MockTransformation(id: "test-1", displayName: "Test 1")
        let mock2 = MockTransformation(id: "test-2", displayName: "Test 2")

        registry.register(mock1, enabled: false)
        registry.register(mock2, enabled: false)

        registry.enableAll()

        #expect(registry.isEnabled("test-1") == true)
        #expect(registry.isEnabled("test-2") == true)
        #expect(registry.enabledCount == 2)
    }

    @Test("DisableAll disables all transformations")
    @MainActor
    func disableAll() {
        let registry = TransformationRegistry(registerBuiltIns: false)
        let mock1 = MockTransformation(id: "test-1", displayName: "Test 1")
        let mock2 = MockTransformation(id: "test-2", displayName: "Test 2")

        registry.register(mock1, enabled: true)
        registry.register(mock2, enabled: true)

        registry.disableAll()

        #expect(registry.isEnabled("test-1") == false)
        #expect(registry.isEnabled("test-2") == false)
        #expect(registry.enabledCount == 0)
    }

    // MARK: - Query Tests

    @Test("AllTransformations returns all registered transformations")
    @MainActor
    func allTransformations() {
        let registry = TransformationRegistry(registerBuiltIns: false)
        let mock1 = MockTransformation(id: "test-1", displayName: "Test 1")
        let mock2 = MockTransformation(id: "test-2", displayName: "Test 2")

        registry.register(mock1, enabled: true)
        registry.register(mock2, enabled: false)

        let all = registry.allTransformations()

        #expect(all.count == 2)
    }

    @Test("EnabledTransformations returns only enabled")
    @MainActor
    func enabledTransformations() {
        let registry = TransformationRegistry(registerBuiltIns: false)
        let mock1 = MockTransformation(id: "test-1", displayName: "Test 1")
        let mock2 = MockTransformation(id: "test-2", displayName: "Test 2")

        registry.register(mock1, enabled: true)
        registry.register(mock2, enabled: false)

        let enabled = registry.enabledTransformations()

        #expect(enabled.count == 1)
        #expect(enabled.first?.id == "test-1")
    }

    @Test("TransformationNames returns ID to displayName mapping")
    @MainActor
    func transformationNames() {
        let registry = TransformationRegistry(registerBuiltIns: false)
        let mock1 = MockTransformation(id: "test-1", displayName: "Test One")
        let mock2 = MockTransformation(id: "test-2", displayName: "Test Two")

        registry.register(mock1)
        registry.register(mock2)

        let names = registry.transformationNames()

        #expect(names["test-1"] == "Test One")
        #expect(names["test-2"] == "Test Two")
    }

    @Test("AllIDs returns all registered IDs")
    @MainActor
    func allIDs() {
        let registry = TransformationRegistry(registerBuiltIns: false)
        let mock1 = MockTransformation(id: "test-1", displayName: "Test 1")
        let mock2 = MockTransformation(id: "test-2", displayName: "Test 2")

        registry.register(mock1)
        registry.register(mock2)

        let ids = registry.allIDs

        #expect(ids.contains("test-1"))
        #expect(ids.contains("test-2"))
        #expect(ids.count == 2)
    }

    @Test("Entry returns full registry entry")
    @MainActor
    func entry() {
        let registry = TransformationRegistry(registerBuiltIns: false)
        let mock = MockTransformation(id: "test", displayName: "Test")

        registry.register(mock, category: .builtin, enabled: false)

        let entry = registry.entry(for: "test")

        #expect(entry != nil)
        #expect(entry?.transformation.id == "test")
        #expect(entry?.isEnabled == false)
        #expect(entry?.category == .builtin)
    }

    // MARK: - Clear Tests

    @Test("Clear removes all registrations")
    @MainActor
    func clear() {
        let registry = TransformationRegistry(registerBuiltIns: true)

        #expect(registry.count > 0)

        registry.clear()

        #expect(registry.count == 0)
        #expect(!registry.exists("whitespace-strip"))
    }

    // MARK: - Count Tests

    @Test("Count reflects number of registrations")
    @MainActor
    func count() {
        let registry = TransformationRegistry(registerBuiltIns: false)

        #expect(registry.count == 0)

        registry.register(MockTransformation(id: "1", displayName: "1"))
        #expect(registry.count == 1)

        registry.register(MockTransformation(id: "2", displayName: "2"))
        #expect(registry.count == 2)

        registry.unregister("1")
        #expect(registry.count == 1)
    }

    @Test("EnabledCount reflects number of enabled registrations")
    @MainActor
    func enabledCount() {
        let registry = TransformationRegistry(registerBuiltIns: false)

        registry.register(MockTransformation(id: "1", displayName: "1"), enabled: true)
        registry.register(MockTransformation(id: "2", displayName: "2"), enabled: false)
        registry.register(MockTransformation(id: "3", displayName: "3"), enabled: true)

        #expect(registry.count == 3)
        #expect(registry.enabledCount == 2)
    }
}
