import Foundation
import SwiftUI

// MARK: - Onboarding Step

/// Represents the steps in the onboarding flow.
enum OnboardingStep: Int, CaseIterable, Sendable {
    case welcome = 0
    case permissions = 1
    case providers = 2
    case firstTransformation = 3
    case complete = 4

    /// Human-readable name for each step.
    var title: String {
        switch self {
        case .welcome: "Welcome"
        case .permissions: "Permissions"
        case .providers: "Provider Setup"
        case .firstTransformation: "First Transformation"
        case .complete: "Complete"
        }
    }

    /// The next step in the sequence, or nil if this is the last step.
    var next: OnboardingStep? {
        OnboardingStep(rawValue: self.rawValue + 1)
    }

    /// The previous step in the sequence, or nil if this is the first step.
    var previous: OnboardingStep? {
        guard self.rawValue > 0 else { return nil }
        return OnboardingStep(rawValue: self.rawValue - 1)
    }
}

// MARK: - Onboarding State Manager

/// Observable manager for onboarding flow state.
///
/// Tracks whether the user has completed onboarding and which step
/// they're currently on. Persists state to UserDefaults via @AppStorage.
///
/// ## Usage
/// ```swift
/// @StateObject private var onboardingState = OnboardingStateManager()
///
/// if onboardingState.shouldShowOnboarding {
///     OnboardingSheet()
///         .environmentObject(onboardingState)
/// }
/// ```
@MainActor
final class OnboardingStateManager: ObservableObject {
    // MARK: - Persisted State

    /// Whether the app has been launched at least once.
    @AppStorage(SettingsKey.hasLaunchedBefore) private var hasLaunchedBefore = DefaultSettings.hasLaunchedBefore

    /// Whether onboarding has been completed.
    @AppStorage(SettingsKey.onboardingCompleted) private var onboardingCompleted = DefaultSettings.onboardingCompleted

    /// Current onboarding step (raw value).
    @AppStorage(SettingsKey.onboardingStep) private var onboardingStepRaw = DefaultSettings.onboardingStep

    // MARK: - Published State

    /// Whether the onboarding sheet is currently presented.
    @Published var isPresented: Bool = false

    // MARK: - Computed Properties

    /// The current onboarding step.
    var currentStep: OnboardingStep {
        get { OnboardingStep(rawValue: self.onboardingStepRaw) ?? .welcome }
        set { self.onboardingStepRaw = newValue.rawValue }
    }

    /// Whether onboarding should be shown.
    ///
    /// Returns `true` if this is the first launch or onboarding hasn't been completed.
    var shouldShowOnboarding: Bool {
        !self.hasLaunchedBefore || !self.onboardingCompleted
    }

    /// Progress through the onboarding flow (0.0 to 1.0).
    var progress: Double {
        let totalSteps = Double(OnboardingStep.allCases.count - 1)
        return Double(self.currentStep.rawValue) / totalSteps
    }

    // MARK: - Initialization

    init() {
        // Mark that we've launched before
        if !self.hasLaunchedBefore {
            self.hasLaunchedBefore = true
        }
    }

    // MARK: - Navigation

    /// Advances to the next onboarding step.
    ///
    /// If already at the final step, marks onboarding as complete.
    func advance() {
        if let next = self.currentStep.next {
            self.currentStep = next
            if next == .complete {
                self.complete()
            }
        } else {
            self.complete()
        }
    }

    /// Goes back to the previous onboarding step.
    func goBack() {
        if let previous = self.currentStep.previous {
            self.currentStep = previous
        }
    }

    /// Skips the onboarding flow without completing it.
    ///
    /// The user can re-enter onboarding later from Settings.
    func skip() {
        self.isPresented = false
        // Don't set onboardingCompleted = true so it can be resumed
    }

    /// Marks onboarding as complete and closes the sheet.
    func complete() {
        self.onboardingCompleted = true
        self.isPresented = false
    }

    /// Resets onboarding state for testing or re-onboarding.
    func reset() {
        self.hasLaunchedBefore = true
        self.onboardingCompleted = false
        self.onboardingStepRaw = OnboardingStep.welcome.rawValue
    }

    /// Shows the onboarding flow.
    func show() {
        self.isPresented = true
    }
}
