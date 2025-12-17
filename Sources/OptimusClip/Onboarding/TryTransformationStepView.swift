import AppKit
import SwiftUI

/// Interactive walkthrough step teaching users their first transformation.
///
/// This final onboarding step demonstrates the copy → hotkey → paste workflow
/// using the built-in "Clean Terminal Text" transformation:
/// 1. User copies sample terminal text (auto-detected via clipboard monitoring)
/// 2. User presses the hotkey (⌃⌥T) to transform
/// 3. Result is shown with celebration animation
///
/// ## Design
/// - Uses sample text that clearly demonstrates terminal prompt removal
/// - Monitors clipboard to confirm user copied the sample
/// - Observes TransformationFlowCoordinator for completion
/// - Celebration animation on success
///
/// ## Dependencies
/// - TransformationFlowCoordinator: For observing transformation state
/// - AccessibilityPermissionManager: Permission should be granted (blocked earlier)
struct TryTransformationStepView: View {
    /// Action to perform when user finishes the walkthrough.
    let onContinue: () -> Void

    /// Action to skip this step.
    let onSkip: () -> Void

    /// Reference to the transformation flow coordinator for observing state.
    @ObservedObject private var flowCoordinator = TransformationFlowCoordinator.shared

    /// Tracks the current walkthrough step.
    @State private var walkthroughStep: WalkthroughStep = .copyText

    /// Timer for polling clipboard content and transformation state.
    @State private var monitorTimer: Timer?

    /// Tracks if we're currently processing (for state change detection).
    @State private var wasProcessing = false

    /// The expected clipboard content (sample text).
    @State private var expectedClipboardContent: String = ""

    /// Whether the transformation completed successfully.
    @State private var transformationSucceeded = false

    /// The transformed result text.
    @State private var transformedResult: String?

    /// Whether to show celebration animation.
    @State private var showCelebration = false

    // MARK: - Sample Data

    /// Sample terminal text that demonstrates the transformation well.
    private let sampleText = """
    user@macbook:~/projects$ ls -la
    total 24
    drwxr-xr-x  5 user staff  160 Dec 15 10:30 .
    drwxr-xr-x  8 user staff  256 Dec 14 09:15 ..
    -rw-r--r--  1 user staff  847 Dec 15 10:30 README.md
    """

    /// The expected result after transformation (prompts removed).
    private let expectedResult = """
    ls -la
    total 24
    drwxr-xr-x  5 user staff  160 Dec 15 10:30 .
    drwxr-xr-x  8 user staff  256 Dec 14 09:15 ..
    -rw-r--r--  1 user staff  847 Dec 15 10:30 README.md
    """

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            self.iconSection
            self.titleSection
            self.contentSection
            Spacer()
            self.actionButtons
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            self.startMonitoring()
        }
        .onDisappear {
            self.stopMonitoring()
        }
    }

    // MARK: - Icon Section

    @ViewBuilder
    private var iconSection: some View {
        ZStack {
            if self.showCelebration {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .scaleEffect(1.3)
            }

            Image(systemName: self.showCelebration ? "sparkles" : "wand.and.stars")
                .font(.system(size: 48))
                .foregroundStyle(self.showCelebration ? .green : .purple)
                .scaleEffect(self.showCelebration ? 1.1 : 1.0)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: self.showCelebration)
    }

    // MARK: - Title Section

    @ViewBuilder
    private var titleSection: some View {
        VStack(spacing: 8) {
            Text("Try Your First Transformation!")
                .font(.title2.bold())

            Text("Let's clean up some messy terminal text.")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Content Section

    @ViewBuilder
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Step 1: Copy the sample text
            self.stepView(
                number: 1,
                title: "Copy this sample text",
                isActive: self.walkthroughStep == .copyText,
                isCompleted: self.walkthroughStep.rawValue > WalkthroughStep.copyText.rawValue
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    self.sampleTextBox

                    if self.walkthroughStep == .copyText {
                        Button {
                            self.copyToClipboard()
                        } label: {
                            Label("Copy to Clipboard", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Label("Copied!", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }
            }

            // Step 2: Press the hotkey
            self.stepView(
                number: 2,
                title: "Press the hotkey",
                isActive: self.walkthroughStep == .pressHotkey,
                isCompleted: self.walkthroughStep.rawValue > WalkthroughStep.pressHotkey.rawValue
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Text("Press")
                            .foregroundStyle(.secondary)
                        Text("⌃⌥T")
                            .font(.system(.body, design: .monospaced).bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Text("(Control + Option + T)")
                            .foregroundStyle(.secondary)
                    }

                    if self.walkthroughStep == .pressHotkey {
                        if self.flowCoordinator.isProcessing {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Transforming...")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        } else {
                            Text("Waiting for hotkey...")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    } else if self.transformationSucceeded {
                        Label("Transformation ran!", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }
            }

            // Step 3: See the result
            self.stepView(
                number: 3,
                title: "See the result",
                isActive: self.walkthroughStep == .seeResult,
                isCompleted: self.walkthroughStep == .seeResult && self.transformationSucceeded
            ) {
                if self.walkthroughStep == .seeResult, let result = self.transformedResult {
                    VStack(alignment: .leading, spacing: 8) {
                        self.resultTextBox(text: result)

                        Text("The terminal prompt was removed! Paste this anywhere.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Complete steps 1 and 2 first")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Step View

    @ViewBuilder
    private func stepView(
        number: Int,
        title: String,
        isActive: Bool,
        isCompleted: Bool,
        @ViewBuilder content: () -> some View
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Step number circle
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.green : (isActive ? Color.accentColor : Color.secondary.opacity(0.3)))
                    .frame(width: 24, height: 24)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                } else {
                    Text("\(number)")
                        .font(.caption.bold())
                        .foregroundStyle(isActive ? .white : .secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(isActive || isCompleted ? .primary : .secondary)

                content()
                    .opacity(isActive || isCompleted ? 1.0 : 0.5)
            }
        }
    }

    // MARK: - Text Boxes

    @ViewBuilder
    private var sampleTextBox: some View {
        Text(self.sampleText)
            .font(.system(.caption, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func resultTextBox(text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color.green.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 12) {
            if self.walkthroughStep == .seeResult, self.transformationSucceeded {
                Button {
                    self.onContinue()
                } label: {
                    Text("Finish Setup")
                        .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button {
                    self.onSkip()
                } label: {
                    Text("Skip for Now")
                        .frame(minWidth: 120)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        self.expectedClipboardContent = self.sampleText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            Task { @MainActor in
                self.checkState()
            }
        }
    }

    private func stopMonitoring() {
        self.monitorTimer?.invalidate()
        self.monitorTimer = nil
    }

    private func checkState() {
        // Check for clipboard copy in step 1
        if self.walkthroughStep == .copyText {
            if let clipboardString = NSPasteboard.general.string(forType: .string) {
                let trimmed = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed == self.expectedClipboardContent {
                    withAnimation {
                        self.walkthroughStep = .pressHotkey
                    }
                }
            }
        }

        // Check for transformation completion in step 2
        if self.walkthroughStep == .pressHotkey {
            let isCurrentlyProcessing = self.flowCoordinator.isProcessing

            // Detect transition from processing to not processing
            if self.wasProcessing, !isCurrentlyProcessing {
                // Check if clipboard changed (transformation completed)
                if let clipboardString = NSPasteboard.general.string(forType: .string) {
                    let trimmed = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
                    // If clipboard changed from our sample, transformation likely ran
                    if trimmed != self.expectedClipboardContent {
                        self.transformedResult = trimmed
                        self.transformationSucceeded = true
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            self.walkthroughStep = .seeResult
                            self.showCelebration = true
                        }
                    }
                }
            }

            self.wasProcessing = isCurrentlyProcessing
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(self.sampleText, forType: .string)
        withAnimation {
            self.walkthroughStep = .pressHotkey
        }
    }
}

// MARK: - Walkthrough Step

/// Steps in the first transformation walkthrough.
private enum WalkthroughStep: Int, Comparable {
    case copyText = 0
    case pressHotkey = 1
    case seeResult = 2

    static func < (lhs: WalkthroughStep, rhs: WalkthroughStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Preview

#Preview("Try Transformation Step") {
    TryTransformationStepView(onContinue: {}, onSkip: {})
        .frame(width: 520, height: 580)
}
