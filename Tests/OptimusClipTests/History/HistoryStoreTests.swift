import Foundation
import Testing
@testable import OptimusClipCore

@Suite("HistoryStore")
struct HistoryStoreTests {
    @Test("record persists entries")
    func recordPersistsEntries() async throws {
        let store = try HistoryStoreHarness.makeStore(entryLimit: 10)
        let entry = HistoryEntry(
            transformationId: "whitespace-strip",
            transformationName: "Strip Whitespace",
            inputText: "  hello  ",
            outputText: "hello",
            processingTimeMs: 12,
            wasSuccessful: true
        )

        try await store.record(entry)
        let records = try await store.fetchRecent()

        #expect(records.count == 1)
        let record = try #require(records.first)
        #expect(record.transformationId == entry.transformationId)
        #expect(record.transformationName == entry.transformationName)
        #expect(record.inputCharCount == entry.inputText.count)
        #expect(record.wasSuccessful)
    }

    @Test("prunes old entries beyond limit")
    func prunesOldEntriesBeyondLimit() async throws {
        let store = try HistoryStoreHarness.makeStore(entryLimit: 2)

        for index in 0 ..< 3 {
            let entry = HistoryEntry(
                timestamp: Date().addingTimeInterval(TimeInterval(index)),
                transformationId: "entry-\(index)",
                transformationName: "Entry #\(index)",
                inputText: "input-\(index)",
                outputText: "output-\(index)",
                processingTimeMs: 5,
                wasSuccessful: true
            )
            try await store.record(entry)
        }

        let records = try await store.fetchRecent()
        #expect(records.count == 2)
        #expect(records.map(\.transformationId) == ["entry-2", "entry-1"])
    }

    @Test("fetch respects limit and ordering")
    func fetchRespectsLimit() async throws {
        let store = try HistoryStoreHarness.makeStore(entryLimit: 10)

        for index in 0 ..< 3 {
            let entry = HistoryEntry(
                timestamp: Date().addingTimeInterval(TimeInterval(index)),
                transformationId: "ix-\(index)",
                transformationName: "Ix #\(index)",
                inputText: "input-\(index)",
                outputText: "output-\(index)",
                processingTimeMs: index * 10,
                wasSuccessful: index % 2 == 0,
                errorMessage: index % 2 == 0 ? nil : "boom"
            )
            try await store.record(entry)
        }

        let limited = try await store.fetchRecent(limit: 1)
        #expect(limited.count == 1)
        #expect(limited.first?.transformationId == "ix-2")
    }

    @Test("updating entry limit prunes overflow")
    func updatingEntryLimitPrunesOverflow() async throws {
        let store = try HistoryStoreHarness.makeStore(entryLimit: 5)

        for index in 0 ..< 5 {
            let entry = HistoryEntry(
                transformationId: "initial-\(index)",
                transformationName: "Initial #\(index)",
                inputText: "in-\(index)",
                outputText: "out-\(index)",
                processingTimeMs: 1,
                wasSuccessful: true
            )
            try await store.record(entry)
        }

        try await store.updateEntryLimit(2)

        let records = try await store.fetchRecent()
        #expect(records.count == 2)
        #expect(records.map(\.transformationId) == ["initial-4", "initial-3"])
    }
}

private enum HistoryStoreHarness {
    static func makeStore(entryLimit: Int) throws -> HistoryStore {
        let container = try HistoryModelContainerFactory.makeInMemoryContainer()
        return HistoryStore(container: container, configuration: .init(entryLimit: entryLimit))
    }
}
