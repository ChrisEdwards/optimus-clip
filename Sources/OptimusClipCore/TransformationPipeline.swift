import Foundation

/// Configuration for pipeline execution behavior.
public struct PipelineConfig: Sendable {
    /// Timeout for entire pipeline execution in seconds. Default: 5.0 for algorithmic, 30.0 for LLM.
    public var timeout: TimeInterval

    /// Whether to fail immediately on first error (true) or collect all errors (false). Default: true.
    public var failFast: Bool

    /// Creates a pipeline configuration with the specified options.
    public init(
        timeout: TimeInterval = 5.0,
        failFast: Bool = true
    ) {
        self.timeout = timeout
        self.failFast = failFast
    }

    /// Default configuration for algorithmic transforms (fast, fail-fast).
    public static let algorithmic = PipelineConfig(timeout: 5.0, failFast: true)

    /// Configuration for LLM transforms (longer timeout).
    public static let llm = PipelineConfig(timeout: 30.0, failFast: true)
}

/// Result of a single transformation stage.
public struct StageResult: Sendable {
    /// ID of the transformation that ran.
    public let transformationId: String

    /// Name of the transformation for display.
    public let transformationName: String

    /// Output text from this stage.
    public let output: String

    /// Duration of this stage in seconds.
    public let duration: TimeInterval

    /// Optional metadata describing provider/model information (LLM stages).
    public let metadata: TransformationHistoryMetadata?
}

/// Result of complete pipeline execution.
public struct PipelineResult: Sendable {
    /// Final transformed text.
    public let output: String

    /// Results from each stage, in execution order.
    public let stageResults: [StageResult]

    /// Total execution time in seconds.
    public var totalDuration: TimeInterval {
        self.stageResults.reduce(0) { $0 + $1.duration }
    }

    /// Number of transformations executed.
    public var stageCount: Int {
        self.stageResults.count
    }
}

/// Errors specific to pipeline execution.
public enum PipelineError: Error, Sendable, LocalizedError {
    /// Pipeline has no transformations configured.
    case emptyPipeline

    /// A specific transformation stage failed.
    case stageFailed(stage: Int, transformationId: String, underlying: Error)

    /// Pipeline execution timed out.
    case timeout(seconds: Int)

    /// Pipeline was cancelled.
    case cancelled

    /// User-friendly error description for display.
    public var errorDescription: String? {
        switch self {
        case .emptyPipeline:
            return "No transformations configured"
        case let .stageFailed(stage, transformationId, underlying):
            let underlyingDesc = (underlying as? LocalizedError)?.errorDescription ?? underlying.localizedDescription
            return "Stage \(stage + 1) (\(transformationId)) failed: \(underlyingDesc)"
        case let .timeout(seconds):
            return "Pipeline timed out after \(seconds) seconds"
        case .cancelled:
            return "Pipeline execution was cancelled"
        }
    }
}

/// Executes a sequence of transformations as a pipeline.
///
/// The pipeline processes text through multiple transformations in order,
/// where the output of each stage becomes the input of the next stage.
///
/// ## Example
/// ```swift
/// let pipeline = TransformationPipeline(
///     transformations: [stripTransform, unwrapTransform],
///     config: .algorithmic
/// )
/// let result = try await pipeline.execute("  Hello\n  World")
/// print(result.output) // "Hello World"
/// ```
///
/// ## Error Handling
/// - Fail-fast: On error, execution stops and the original input is preserved.
/// - Timeout: Entire pipeline has a configurable timeout.
/// - Empty input: Throws `TransformationError.emptyInput`.
///
/// ## Thread Safety
/// Pipeline is `Sendable` and safe to use from any actor context.
public struct TransformationPipeline: Sendable {
    /// The ordered list of transformations to execute.
    private let transformations: [any Transformation]

    /// Pipeline execution configuration.
    private let config: PipelineConfig

    /// Creates a pipeline with the specified transformations and configuration.
    ///
    /// - Parameters:
    ///   - transformations: Transformations to execute in order.
    ///   - config: Execution configuration (timeout, fail-fast behavior).
    public init(
        transformations: [any Transformation],
        config: PipelineConfig = .algorithmic
    ) {
        self.transformations = transformations
        self.config = config
    }

    /// Display names of all transformations in the pipeline, in execution order.
    public var transformationDisplayNames: [String] {
        self.transformations.map(\.displayName)
    }

    /// Number of transformations in the pipeline.
    public var transformationCount: Int {
        self.transformations.count
    }

    /// Provider name from the first LLM transformation in the pipeline, if any.
    public var providerName: String? {
        for transform in self.transformations {
            if let metadataProvider = transform as? TransformationHistoryMetadataProviding {
                return metadataProvider.historyMetadata.providerName
            }
        }
        return nil
    }

    /// Execute all transformations in sequence.
    ///
    /// - Parameter input: Original text from clipboard.
    /// - Returns: Pipeline result with final output and stage metrics.
    /// - Throws: `TransformationError.emptyInput`, `PipelineError.stageFailed`,
    ///           `PipelineError.timeout`, or `PipelineError.cancelled`.
    public func execute(_ input: String) async throws -> PipelineResult {
        // Validate input
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TransformationError.emptyInput
        }

        // Validate pipeline has transformations
        guard !self.transformations.isEmpty else {
            throw PipelineError.emptyPipeline
        }

        // Execute with timeout using shared utility
        return try await withTimeout(
            self.config.timeout,
            timeoutError: PipelineError.timeout(seconds: Int(self.config.timeout))
        ) {
            try await self.executeStages(input)
        }
    }

    /// Execute stages sequentially without timeout wrapper.
    private func executeStages(_ input: String) async throws -> PipelineResult {
        var current = input
        var stageResults: [StageResult] = []

        for (index, transform) in self.transformations.enumerated() {
            // Check for cancellation
            try Task.checkCancellation()

            let stageStart = ContinuousClock.now

            do {
                // Execute transformation
                let output = try await transform.transform(current)

                let duration = stageStart.duration(to: .now)
                let metadataProvider = transform as? any TransformationHistoryMetadataProviding
                let stageResult = StageResult(
                    transformationId: transform.id,
                    transformationName: transform.displayName,
                    output: output,
                    duration: duration.seconds,
                    metadata: metadataProvider?.historyMetadata
                )

                stageResults.append(stageResult)
                current = output

            } catch is CancellationError {
                throw PipelineError.cancelled
            } catch {
                // Fail-fast: wrap and rethrow immediately
                if self.config.failFast {
                    throw PipelineError.stageFailed(
                        stage: index,
                        transformationId: transform.id,
                        underlying: error
                    )
                }
                // Future: non-fail-fast mode could collect errors and continue
            }
        }

        return PipelineResult(output: current, stageResults: stageResults)
    }
}

// MARK: - Duration Extension

extension Duration {
    /// Convert Duration to seconds as TimeInterval.
    var seconds: TimeInterval {
        let (seconds, attoseconds) = self.components
        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    }
}

// MARK: - Convenience Factory Methods

extension TransformationPipeline {
    /// Creates a "Clean Terminal Text" pipeline with strip whitespace and smart unwrap.
    ///
    /// This is the default algorithmic transformation pipeline for
    /// cleaning up CLI output before pasting.
    ///
    /// - Returns: Pipeline configured with whitespace strip and smart unwrap.
    public static func cleanTerminalText() -> TransformationPipeline {
        TransformationPipeline(
            transformations: [
                WhitespaceStripTransformation(),
                SmartUnwrapTransformation()
            ],
            config: .algorithmic
        )
    }

    /// Creates a pipeline with a single transformation.
    ///
    /// - Parameters:
    ///   - transformation: The single transformation to execute.
    ///   - config: Execution configuration.
    /// - Returns: Pipeline with single transformation.
    public static func single(
        _ transformation: any Transformation,
        config: PipelineConfig = .algorithmic
    ) -> TransformationPipeline {
        TransformationPipeline(
            transformations: [transformation],
            config: config
        )
    }
}
