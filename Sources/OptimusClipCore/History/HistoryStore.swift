import Foundation
import SwiftData

/// Configuration knobs for the history store.
public struct HistoryStoreConfiguration: Sendable, Equatable {
    public static let `default` = HistoryStoreConfiguration()

    /// Maximum number of entries to keep on disk. Older entries are pruned lazily.
    public var entryLimit: Int

    public init(entryLimit: Int = 100) {
        self.entryLimit = max(entryLimit, 0)
    }
}

/// Actor encapsulating all SwiftData interactions for the transformation history.
public actor HistoryStore {
    private let context: ModelContext
    private var entryLimit: Int

    public init(container: ModelContainer, configuration: HistoryStoreConfiguration = .default) {
        self.context = ModelContext(container)
        self.context.autosaveEnabled = false
        self.entryLimit = configuration.entryLimit
    }

    /// Persists a history entry and prunes old rows when the entry limit is exceeded.
    public func record(_ entry: HistoryEntry) throws {
        let log = TransformationLog(entry: entry)
        self.context.insert(log)
        try self.context.save()
        try self.pruneIfNeeded()
    }

    /// Returns the most recent history records, newest first.
    public func fetchRecent(limit: Int? = nil) throws -> [HistoryRecord] {
        var descriptor = self.makeDescriptor(order: .reverse)
        if let limit, limit > 0 {
            descriptor.fetchLimit = limit
        }
        return try self.context.fetch(descriptor).map { $0.asRecord() }
    }

    /// Deletes all persisted history entries. Intended for tests / troubleshooting.
    public func removeAll() throws {
        let descriptor = self.makeDescriptor(order: .forward)
        let existing = try self.context.fetch(descriptor)
        guard existing.isEmpty == false else {
            return
        }
        existing.forEach { self.context.delete($0) }
        try self.context.save()
    }

    /// Update the retention limit and prune immediately if needed.
    public func updateEntryLimit(_ newLimit: Int) throws {
        self.entryLimit = max(newLimit, 0)
        try self.pruneIfNeeded()
    }

    private func pruneIfNeeded() throws {
        guard self.entryLimit > 0 else {
            return
        }

        var descriptor = self.makeDescriptor(order: .reverse)
        descriptor.fetchOffset = self.entryLimit

        let overflow = try self.context.fetch(descriptor)
        guard overflow.isEmpty == false else {
            return
        }

        overflow.forEach { self.context.delete($0) }
        try self.context.save()
    }

    private func makeDescriptor(order: SortOrder) -> FetchDescriptor<TransformationLog> {
        FetchDescriptor(
            sortBy: [SortDescriptor(\TransformationLog.timestamp, order: order)]
        )
    }
}
