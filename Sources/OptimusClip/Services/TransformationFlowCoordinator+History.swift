import Foundation
import OptimusClipCore
import OSLog

private let historyLogger = Logger(subsystem: "com.optimusclip", category: "HistoryFlow")

@MainActor
extension TransformationFlowCoordinator {
    func recordHistoryEntry(for outcome: TransformationFlowOutcome) {
        guard let store = self.historyStore else {
            return
        }

        let processingTimeSeconds = outcome.request.startedAt.distance(to: outcome.finishedAt)
        let descriptor = outcome.historyDescriptor

        let entry = HistoryEntry(
            timestamp: outcome.finishedAt,
            transformationId: descriptor.transformationId,
            transformationName: descriptor.transformationName,
            providerName: descriptor.providerName,
            modelUsed: descriptor.modelUsed,
            systemPrompt: descriptor.systemPrompt,
            inputText: outcome.originalText,
            outputText: outcome.transformedText,
            processingTimeMs: Int(max(processingTimeSeconds, 0) * 1000),
            wasSuccessful: true,
            errorMessage: nil
        )

        Task.detached(priority: .background) {
            do {
                try await store.record(entry)
            } catch {
                historyLogger.error("Failed to persist history entry: \(error.localizedDescription)")
            }
        }
    }

    /// Records a failed transformation to history.
    ///
    /// - Parameters:
    ///   - request: The transformation request that failed.
    ///   - error: The error that caused the failure.
    ///   - inputText: The original clipboard text, if available.
    func recordHistoryFailure(
        for request: TransformationRequest,
        error: TransformationFlowError,
        inputText: String?
    ) {
        guard let store = self.historyStore else {
            return
        }

        let finishedAt = Date()
        let processingTimeSeconds = request.startedAt.distance(to: finishedAt)

        // Build descriptor from current transformation or pipeline
        let descriptor: TransformationHistoryDescriptor = if self.pipeline != nil {
            TransformationHistoryDescriptor(
                transformationId: "pipeline",
                transformationName: "Pipeline"
            )
        } else {
            self.makeDescriptor(
                id: self.transformation.id,
                name: self.transformation.displayName,
                metadataProvider: self.transformation
            )
        }

        let entry = HistoryEntry(
            timestamp: finishedAt,
            transformationId: descriptor.transformationId,
            transformationName: descriptor.transformationName,
            providerName: descriptor.providerName,
            modelUsed: descriptor.modelUsed,
            systemPrompt: descriptor.systemPrompt,
            inputText: inputText ?? "",
            outputText: "",
            processingTimeMs: Int(max(processingTimeSeconds, 0) * 1000),
            wasSuccessful: false,
            errorMessage: error.message
        )

        Task.detached(priority: .background) {
            do {
                try await store.record(entry)
            } catch {
                historyLogger.error("Failed to persist failure history entry: \(error.localizedDescription)")
            }
        }
    }

    func makeDescriptor(from result: PipelineResult) -> TransformationHistoryDescriptor {
        guard let lastStage = result.stageResults.last else {
            return TransformationHistoryDescriptor(
                transformationId: "pipeline",
                transformationName: "Pipeline"
            )
        }

        return TransformationHistoryDescriptor(
            transformationId: lastStage.transformationId,
            transformationName: lastStage.transformationName,
            providerName: lastStage.metadata?.providerName,
            modelUsed: lastStage.metadata?.modelUsed,
            systemPrompt: lastStage.metadata?.systemPrompt
        )
    }

    func makeDescriptor(
        id: String,
        name: String,
        metadataProvider: any Transformation
    ) -> TransformationHistoryDescriptor {
        let metadataSource = metadataProvider as? any TransformationHistoryMetadataProviding
        let metadata = metadataSource?.historyMetadata

        return TransformationHistoryDescriptor(
            transformationId: id,
            transformationName: name,
            providerName: metadata?.providerName,
            modelUsed: metadata?.modelUsed,
            systemPrompt: metadata?.systemPrompt
        )
    }
}
