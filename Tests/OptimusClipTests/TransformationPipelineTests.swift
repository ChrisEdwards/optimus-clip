import Foundation
import Testing
@testable import OptimusClipCore

/// Test suite for TransformationPipeline.
@Suite("TransformationPipeline Tests")
struct TransformationPipelineTests {
    // MARK: - Basic Execution Tests

    @Test("Pipeline executes single transformation")
    func executeSingleTransformation() async throws {
        let pipeline = TransformationPipeline(
            transformations: [IdentityTransformation()],
            config: .algorithmic
        )

        let result = try await pipeline.execute("Hello, World!")

        #expect(result.output == "Hello, World!")
        #expect(result.stageCount == 1)
        #expect(result.stageResults[0].transformationId == "identity")
    }

    @Test("Pipeline executes transformations in order")
    func executeInOrder() async throws {
        let first = AppendTransformation(suffix: "A")
        let second = AppendTransformation(suffix: "B")

        let pipeline = TransformationPipeline(
            transformations: [first, second],
            config: .algorithmic
        )

        let result = try await pipeline.execute("Text")

        #expect(result.output == "TextAB")
        #expect(result.stageCount == 2)
        #expect(result.stageResults[0].output == "TextA")
        #expect(result.stageResults[1].output == "TextAB")
    }

    @Test("Pipeline passes output to next stage")
    func outputPassedToNextStage() async throws {
        let strip = WhitespaceStripTransformation()
        let identity = IdentityTransformation()

        let pipeline = TransformationPipeline(
            transformations: [strip, identity],
            config: .algorithmic
        )

        let result = try await pipeline.execute("  Hello\n  World")

        #expect(result.output == "Hello\nWorld")
        #expect(result.stageCount == 2)
    }

    // MARK: - Empty Input Tests

    @Test("Pipeline throws on empty input")
    func throwsOnEmptyInput() async {
        let pipeline = TransformationPipeline(
            transformations: [IdentityTransformation()],
            config: .algorithmic
        )

        await #expect(throws: TransformationError.self) {
            try await pipeline.execute("")
        }
    }

    @Test("Pipeline throws on whitespace-only input")
    func throwsOnWhitespaceOnlyInput() async {
        let pipeline = TransformationPipeline(
            transformations: [IdentityTransformation()],
            config: .algorithmic
        )

        await #expect(throws: TransformationError.self) {
            try await pipeline.execute("   \n\t  ")
        }
    }

    // MARK: - Empty Pipeline Tests

    @Test("Empty pipeline throws error")
    func emptyPipelineThrows() async {
        let pipeline = TransformationPipeline(
            transformations: [],
            config: .algorithmic
        )

        await #expect(throws: PipelineError.self) {
            try await pipeline.execute("Hello")
        }
    }

    // MARK: - Error Handling Tests

    @Test("Pipeline fails fast on error")
    func failFastOnError() async {
        let first = IdentityTransformation()
        let failing = FailingTransformation()
        let third = AppendTransformation(suffix: "C")

        let pipeline = TransformationPipeline(
            transformations: [first, failing, third],
            config: PipelineConfig(timeout: 5.0, failFast: true)
        )

        await #expect(throws: PipelineError.self) {
            try await pipeline.execute("Text")
        }
    }

    @Test("Pipeline wraps stage error with context")
    func wrapsStageError() async {
        let failing = FailingTransformation()

        let pipeline = TransformationPipeline(
            transformations: [failing],
            config: .algorithmic
        )

        do {
            _ = try await pipeline.execute("Text")
            Issue.record("Expected error to be thrown")
        } catch let error as PipelineError {
            if case let .stageFailed(stage, transformationId, _) = error {
                #expect(stage == 0)
                #expect(transformationId == "failing")
            } else {
                Issue.record("Expected stageFailed error")
            }
        } catch {
            Issue.record("Expected PipelineError, got \(error)")
        }
    }

    // MARK: - Timeout Tests

    @Test("Pipeline respects timeout")
    func respectsTimeout() async {
        let slow = SlowTransformation(delay: 10.0)

        let pipeline = TransformationPipeline(
            transformations: [slow],
            config: PipelineConfig(timeout: 0.1, failFast: true)
        )

        await #expect(throws: PipelineError.self) {
            try await pipeline.execute("Text")
        }
    }

    @Test("Pipeline completes before timeout")
    func completesBeforeTimeout() async throws {
        let fast = IdentityTransformation()

        let pipeline = TransformationPipeline(
            transformations: [fast],
            config: PipelineConfig(timeout: 5.0, failFast: true)
        )

        let result = try await pipeline.execute("Text")
        #expect(result.output == "Text")
    }

    // MARK: - Metrics Tests

    @Test("Pipeline records stage durations")
    func recordsStageDurations() async throws {
        let pipeline = TransformationPipeline(
            transformations: [IdentityTransformation(), IdentityTransformation()],
            config: .algorithmic
        )

        let result = try await pipeline.execute("Text")

        #expect(result.stageResults.count == 2)
        for stage in result.stageResults {
            #expect(stage.duration >= 0)
        }
        #expect(result.totalDuration >= 0)
    }

    @Test("Pipeline result includes transformation metadata")
    func includesTransformationMetadata() async throws {
        let pipeline = TransformationPipeline(
            transformations: [WhitespaceStripTransformation()],
            config: .algorithmic
        )

        let result = try await pipeline.execute("  Hello")

        #expect(result.stageResults[0].transformationId == "whitespace-strip")
        #expect(result.stageResults[0].transformationName == "Strip Whitespace")
    }

    // MARK: - Factory Method Tests

    @Test("Clean terminal text pipeline strips and unwraps")
    func cleanTerminalTextPipeline() async throws {
        let pipeline = TransformationPipeline.cleanTerminalText()

        // Input with 2-space indent (common CLI output)
        let input = "  Hello\n  World"

        let result = try await pipeline.execute(input)

        // Should strip whitespace (stage 1), then smart unwrap may or may not join
        // depending on line characteristics
        #expect(result.stageCount == 2)
        #expect(result.stageResults[0].transformationId == "whitespace-strip")
        #expect(result.stageResults[1].transformationId == "smart-unwrap")
    }

    @Test("Single transformation pipeline")
    func singleTransformationPipeline() async throws {
        let pipeline = TransformationPipeline.single(IdentityTransformation())

        let result = try await pipeline.execute("Hello")

        #expect(result.output == "Hello")
        #expect(result.stageCount == 1)
    }

    // MARK: - PipelineError Description Tests

    @Test("PipelineError.emptyPipeline has description")
    func emptyPipelineErrorDescription() {
        let error = PipelineError.emptyPipeline
        #expect(error.errorDescription == "No transformations configured")
    }

    @Test("PipelineError.timeout has description")
    func timeoutErrorDescription() {
        let error = PipelineError.timeout(seconds: 5)
        #expect(error.errorDescription == "Pipeline timed out after 5 seconds")
    }

    @Test("PipelineError.cancelled has description")
    func cancelledErrorDescription() {
        let error = PipelineError.cancelled
        #expect(error.errorDescription == "Pipeline execution was cancelled")
    }

    @Test("PipelineError.stageFailed has description")
    func stageFailedErrorDescription() {
        let underlying = TransformationError.processingError("test error")
        let error = PipelineError.stageFailed(stage: 0, transformationId: "test", underlying: underlying)
        #expect(error.errorDescription?.contains("Stage 1") == true)
        #expect(error.errorDescription?.contains("test") == true)
    }

    // MARK: - Integration Tests

    @Test("Real transformations work in pipeline")
    func realTransformationsInPipeline() async throws {
        // Real CLI output with 2-space indent
        let cliOutput = """
          def hello():
              print("world")
        """

        let pipeline = TransformationPipeline(
            transformations: [WhitespaceStripTransformation()],
            config: .algorithmic
        )

        let result = try await pipeline.execute(cliOutput)

        // Should strip the 2-space indent, preserving relative indentation
        let expected = """
        def hello():
            print("world")
        """
        #expect(result.output == expected)
    }
}

// MARK: - Test Helpers

/// Transformation that appends a suffix for testing order.
struct AppendTransformation: Transformation {
    let suffix: String

    var id: String { "append-\(self.suffix.lowercased())" }
    var displayName: String { "Append \(self.suffix)" }

    func transform(_ input: String) async throws -> String {
        input + self.suffix
    }
}

/// Transformation that always fails for testing error handling.
struct FailingTransformation: Transformation {
    let id = "failing"
    let displayName = "Failing Transform"

    func transform(_: String) async throws -> String {
        throw TransformationError.processingError("Intentional failure for testing")
    }
}

/// Transformation that delays for testing timeouts.
struct SlowTransformation: Transformation {
    let delay: TimeInterval

    var id: String { "slow" }
    var displayName: String { "Slow Transform" }

    func transform(_ input: String) async throws -> String {
        try await Task.sleep(for: .seconds(self.delay))
        return input
    }
}
