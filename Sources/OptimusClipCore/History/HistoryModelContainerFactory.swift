import Foundation
import SwiftData

/// Helper responsible for building ModelContainers used by the history store.
public enum HistoryModelContainerFactory {
    /// Builds the persistent container stored under Application Support/OptimusClip/History.store.
    public static func makePersistentContainer(fileManager: FileManager = .default) throws -> ModelContainer {
        let storeURL = try self.makeStoreURL(fileManager: fileManager)
        let configuration = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
        return try ModelContainer(for: TransformationLog.self, configurations: configuration)
    }

    /// Builds an in-memory container suitable for unit tests.
    public static func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: TransformationLog.self, configurations: configuration)
    }

    private static func makeStoreURL(fileManager: FileManager) throws -> URL {
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let directory = applicationSupport.appendingPathComponent("OptimusClip", isDirectory: true)
        if fileManager.fileExists(atPath: directory.path) == false {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory.appendingPathComponent("History.store", isDirectory: false)
    }
}
