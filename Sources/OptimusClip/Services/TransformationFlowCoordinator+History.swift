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
