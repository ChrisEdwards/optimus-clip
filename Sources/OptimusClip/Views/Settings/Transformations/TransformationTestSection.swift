import OptimusClipCore
import SwiftUI

// MARK: - Test State

/// State of the transformation test execution.
enum TransformationTestState: Equatable {
    case idle
    case running
    case success(duration: TimeInterval)
    case error(message: String)
}

// MARK: - Test Section View

/// Test mode section for transformation editor.
///
/// Provides input/output text areas and run button for testing transformations.
struct TransformationTestSection: View {
    let transformation: TransformationConfig

    @State private var testInput: String = ""
    @State private var testOutput: String = ""
    @State private var testState: TransformationTestState = .idle

    var body: some View {
        Section("Test Transformation") {
            VStack(alignment: .leading, spacing: 12) {
                self.inputArea
                self.runButtonRow
                self.outputArea
            }
        }
    }

    // MARK: - Input Area

    @ViewBuilder
    private var inputArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Input")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextEditor(text: self.$testInput)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 60, maxHeight: 100)
                .border(Color.secondary.opacity(0.3))
        }
    }

    // MARK: - Run Button Row

    @ViewBuilder
    private var runButtonRow: some View {
        HStack {
            Button {
                Task {
                    await self.runTest()
                }
            } label: {
                HStack(spacing: 4) {
                    if self.testState == .running {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "play.fill")
                    }
                    Text("Run Test")
                }
            }
            .disabled(self.testInput.isEmpty || self.testState == .running)
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Spacer()

            self.testStatusView
        }
    }

    // MARK: - Output Area

    @ViewBuilder
    private var outputArea: some View {
        if !self.testOutput.isEmpty || self.testState == .running {
            VStack(alignment: .leading, spacing: 4) {
                Text("Output")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if self.testState == .running {
                    HStack {
                        Spacer()
                        ProgressView("Running transformation...")
                        Spacer()
                    }
                    .frame(minHeight: 60)
                } else {
                    TextEditor(text: .constant(self.testOutput))
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 60, maxHeight: 100)
                        .border(Color.secondary.opacity(0.3))
                }
            }
        }
    }

    // MARK: - Test Status View

    @ViewBuilder
    private var testStatusView: some View {
        switch self.testState {
        case .idle:
            EmptyView()
        case .running:
            Text("Running...")
                .font(.caption)
                .foregroundColor(.secondary)
        case let .success(duration):
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text(String(format: "%.2fs", duration))
            }
            .font(.caption)
        case let .error(message):
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text(message)
                    .lineLimit(1)
            }
            .font(.caption)
            .help(message)
        }
    }

    // MARK: - Test Execution

    @MainActor
    private func runTest() async {
        guard !self.testInput.isEmpty else { return }

        let transformationSnapshot = self.transformation
        let inputSnapshot = self.testInput

        let startTime = Date()
        self.testState = .running
        self.testOutput = ""

        do {
            let tester = TransformationTester()
            let output = try await tester.runTest(
                transformation: transformationSnapshot,
                input: inputSnapshot
            )
            let duration = Date().timeIntervalSince(startTime)
            self.testOutput = output
            self.testState = .success(duration: duration)
        } catch {
            self.testState = .error(message: error.localizedDescription)
        }
    }
}
