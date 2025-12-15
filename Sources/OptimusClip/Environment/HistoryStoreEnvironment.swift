import OptimusClipCore
import SwiftUI

private struct HistoryStoreKey: EnvironmentKey {
    static let defaultValue: HistoryStore = {
        do {
            return try HistoryStore(container: HistoryModelContainerFactory.makeInMemoryContainer())
        } catch {
            fatalError("Failed to create fallback HistoryStore: \(error)")
        }
    }()
}

extension EnvironmentValues {
    public var historyStore: HistoryStore {
        get { self[HistoryStoreKey.self] }
        set { self[HistoryStoreKey.self] = newValue }
    }
}
