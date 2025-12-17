import SwiftUI

/// Top-level container for the onboarding flow.
///
/// Presents each onboarding step in sequence using `OnboardingStateManager`
/// for navigation and progress tracking. Steps included:
/// - Welcome
/// - Accessibility permissions
/// - Optional provider setup
/// - First transformation walkthrough (placeholder)
/// - Completion
struct OnboardingFlowView: View {
    @EnvironmentObject private var onboardingState: OnboardingStateManager

    var body: some View {
        VStack(spacing: 24) {
            self.header
            self.stepContent
            self.footer
        }
        .padding(32)
        .frame(minWidth: 520, minHeight: 580)
    }

    // MARK: - Sections

    @ViewBuilder
    private var header: some View {
        VStack(spacing: 8) {
            Text("Get Started with Optimus Clip")
                .font(.title.bold())

            Text(self.onboardingState.currentStep.title)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch self.onboardingState.currentStep {
        case .welcome:
            WelcomeStepView(
                onContinue: { self.onboardingState.advance() },
                onSkip: { self.onboardingState.skip() }
            )

        case .permissions:
            PermissionStepView(onContinue: { self.onboardingState.advance() })

        case .providers:
            ProviderSetupStepView(
                onContinue: { self.onboardingState.advance() },
                onSkip: { self.onboardingState.advance() }
            )

        case .firstTransformation:
            FirstTransformationPlaceholderView(
                onContinue: { self.onboardingState.advance() },
                onSkip: { self.onboardingState.advance() }
            )

        case .complete:
            CompletionStepView(onFinish: { self.onboardingState.complete() })
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 8) {
            ProgressView(
                value: self.onboardingState.progress,
                total: 1.0
            )
            .progressViewStyle(.linear)

            Text("Step \(self.onboardingState.currentStep.rawValue + 1) of \(OnboardingStep.allCases.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Welcome

private struct WelcomeStepView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Optimus Clip transforms your clipboard with a hotkey.")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 8) {
                Label("Press a hotkey to clean, format, or enhance text", systemImage: "bolt.fill")
                Label("Optional AI providers for smarter transformations", systemImage: "sparkles")
                Label("History keeps recent inputs and outputs handy", systemImage: "clock.arrow.circlepath")
            }
            .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 12) {
                Button {
                    self.onContinue()
                } label: {
                    Text("Start Setup")
                        .frame(minWidth: 160)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - First Transformation Placeholder

/// Placeholder step for the first transformation walkthrough (oc-nbd.2.5).
/// Provides a simple CTA until the dedicated guided experience is built.
private struct FirstTransformationPlaceholderView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Try Your First Transformation")
                .font(.title3.weight(.semibold))

            Text(
                "A guided walkthrough will appear here to help you run your first transformation. "
                    + "For now, continue to finish setup or skip to use the app."
            )
            .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 12) {
                Button {
                    self.onContinue()
                } label: {
                    Text("Continue")
                        .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    self.onSkip()
                } label: {
                    Text("Skip")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Completion

private struct CompletionStepView: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("You're All Set!")
                .font(.title2.weight(.semibold))

            Text("You can revisit onboarding any time from Settings.")
                .foregroundStyle(.secondary)

            Button {
                self.onFinish()
            } label: {
                Text("Finish")
                    .frame(minWidth: 160)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("Onboarding Flow") {
    OnboardingFlowView()
        .environmentObject(OnboardingStateManager())
}
