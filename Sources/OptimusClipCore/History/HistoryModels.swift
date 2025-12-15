import Foundation
import SwiftData

/// Lightweight value used to request that a history entry be persisted.
public struct HistoryEntry: Sendable, Equatable {
    public let timestamp: Date
    public let transformationId: String
    public let transformationName: String
    public let providerName: String?
    public let modelUsed: String?
    public let systemPrompt: String?
    public let inputText: String
    public let outputText: String
    public let processingTimeMs: Int
    public let wasSuccessful: Bool
    public let errorMessage: String?

    public init(
        timestamp: Date = .now,
        transformationId: String,
        transformationName: String,
        providerName: String? = nil,
        modelUsed: String? = nil,
        systemPrompt: String? = nil,
        inputText: String,
        outputText: String,
        processingTimeMs: Int,
        wasSuccessful: Bool,
        errorMessage: String? = nil
    ) {
        self.timestamp = timestamp
        self.transformationId = transformationId
        self.transformationName = transformationName
        self.providerName = providerName
        self.modelUsed = modelUsed
        self.systemPrompt = systemPrompt
        self.inputText = inputText
        self.outputText = outputText
        self.processingTimeMs = max(processingTimeMs, 0)
        self.wasSuccessful = wasSuccessful
        self.errorMessage = errorMessage
    }
}

/// Snapshot returned to consumers so they do not hold onto SwiftData-managed objects.
public struct HistoryRecord: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let transformationId: String
    public let transformationName: String
    public let providerName: String?
    public let modelUsed: String?
    public let systemPrompt: String?
    public let inputText: String
    public let outputText: String
    public let inputCharCount: Int
    public let processingTimeMs: Int
    public let wasSuccessful: Bool
    public let errorMessage: String?

    public init(
        id: UUID,
        timestamp: Date,
        transformationId: String,
        transformationName: String,
        providerName: String?,
        modelUsed: String?,
        systemPrompt: String?,
        inputText: String,
        outputText: String,
        inputCharCount: Int,
        processingTimeMs: Int,
        wasSuccessful: Bool,
        errorMessage: String?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.transformationId = transformationId
        self.transformationName = transformationName
        self.providerName = providerName
        self.modelUsed = modelUsed
        self.systemPrompt = systemPrompt
        self.inputText = inputText
        self.outputText = outputText
        self.inputCharCount = inputCharCount
        self.processingTimeMs = processingTimeMs
        self.wasSuccessful = wasSuccessful
        self.errorMessage = errorMessage
    }
}

@Model
public final class TransformationLog {
    @Attribute(.unique) public var id: UUID
    public var timestamp: Date
    public var transformationId: String
    public var transformationName: String
    public var providerName: String?
    public var modelUsed: String?
    public var systemPrompt: String?
    public var inputText: String
    public var outputText: String
    public var inputCharCount: Int
    public var processingTimeMs: Int
    public var wasSuccessful: Bool
    public var errorMessage: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        transformationId: String,
        transformationName: String,
        providerName: String? = nil,
        modelUsed: String? = nil,
        systemPrompt: String? = nil,
        inputText: String,
        outputText: String,
        inputCharCount: Int,
        processingTimeMs: Int,
        wasSuccessful: Bool,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.transformationId = transformationId
        self.transformationName = transformationName
        self.providerName = providerName
        self.modelUsed = modelUsed
        self.systemPrompt = systemPrompt
        self.inputText = inputText
        self.outputText = outputText
        self.inputCharCount = inputCharCount
        self.processingTimeMs = processingTimeMs
        self.wasSuccessful = wasSuccessful
        self.errorMessage = errorMessage
    }
}

extension TransformationLog {
    /// Convenience initializer that maps a transient history entry into a persisted model.
    public convenience init(entry: HistoryEntry) {
        self.init(
            timestamp: entry.timestamp,
            transformationId: entry.transformationId,
            transformationName: entry.transformationName,
            providerName: entry.providerName,
            modelUsed: entry.modelUsed,
            systemPrompt: entry.systemPrompt,
            inputText: entry.inputText,
            outputText: entry.outputText,
            inputCharCount: entry.inputText.count,
            processingTimeMs: entry.processingTimeMs,
            wasSuccessful: entry.wasSuccessful,
            errorMessage: entry.errorMessage
        )
    }

    /// Converts the persisted model back into an immutable record for callers.
    public func asRecord() -> HistoryRecord {
        HistoryRecord(
            id: self.id,
            timestamp: self.timestamp,
            transformationId: self.transformationId,
            transformationName: self.transformationName,
            providerName: self.providerName,
            modelUsed: self.modelUsed,
            systemPrompt: self.systemPrompt,
            inputText: self.inputText,
            outputText: self.outputText,
            inputCharCount: self.inputCharCount,
            processingTimeMs: self.processingTimeMs,
            wasSuccessful: self.wasSuccessful,
            errorMessage: self.errorMessage
        )
    }
}
