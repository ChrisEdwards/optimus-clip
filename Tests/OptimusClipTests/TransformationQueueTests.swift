import Foundation
import Testing
@testable import OptimusClip

@Suite("TransformationQueue")
struct TransformationQueueTests {
    @Test("Start registers task and blocks concurrent starts")
    func startPreventsOverlap() async throws {
        let queue = TransformationQueue()
        let request = TransformationRequest(timeout: 1, source: .pipeline)
        let task = Task<TransformationFlowOutcome, Error> {
            TransformationFlowOutcome(request: request, originalText: "a", transformedText: "b")
        }

        try await queue.start(request: request, task: task)

        #expect(await queue.isProcessing)
        #expect(await queue.request() == request)

        let secondRequest = TransformationRequest(timeout: 1, source: .single(transformationId: "next"))
        let secondTask = Task<TransformationFlowOutcome, Error> {
            TransformationFlowOutcome(request: secondRequest, originalText: "c", transformedText: "d")
        }

        do {
            try await queue.start(request: secondRequest, task: secondTask)
            Issue.record("Expected alreadyProcessing error")
        } catch let error as TransformationFlowError {
            switch error {
            case .alreadyProcessing:
                break
            default:
                Issue.record("Unexpected error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }

        await queue.cancel()
    }

    @Test("Cancel propagates to running task and clears state")
    func cancelCancelsTask() async throws {
        let queue = TransformationQueue()
        let request = TransformationRequest(timeout: 1, source: .single(transformationId: "cancel-test"))

        let longTask = Task<TransformationFlowOutcome, Error> {
            try await Task.sleep(for: .seconds(2))
            return TransformationFlowOutcome(request: request, originalText: "x", transformedText: "y")
        }

        try await queue.start(request: request, task: longTask)
        await queue.cancel()

        #expect(longTask.isCancelled)
        #expect(await queue.request() == nil)
        #expect(await queue.isProcessing == false)
    }

    @Test("Finish clears request and processing flag")
    func finishResetsState() async throws {
        let queue = TransformationQueue()
        let request = TransformationRequest(timeout: 1, source: .single(transformationId: "finish"))
        let task = Task<TransformationFlowOutcome, Error> {
            TransformationFlowOutcome(request: request, originalText: "q", transformedText: "r")
        }

        try await queue.start(request: request, task: task)
        await queue.finish()

        #expect(await queue.request() == nil)
        #expect(await queue.isProcessing == false)
    }
}
