import Foundation

/// Centralized settings keys for @AppStorage persistence.
///
/// Using constants prevents typos and provides a single source of truth
/// for all UserDefaults keys used throughout the app.
///
/// ## Usage
/// ```swift
/// @AppStorage(SettingsKey.launchAtLogin) private var launchAtLogin = false
/// ```
///
/// ## Categories
/// - **General**: App-wide preferences
/// - **API Keys**: Provider credentials (migrate to Keychain in Phase 6)
/// - **Ollama**: Local model server configuration
/// - **AWS Bedrock**: AWS provider configuration
/// - **Transformations**: User-defined transformation configs
enum SettingsKey {
    // MARK: - General Settings

    /// Whether to launch the app when user logs in.
    static let launchAtLogin = "launchAtLogin"

    /// Whether to play audio feedback on transformation success/failure.
    static let soundEffectsEnabled = "soundEffectsEnabled"

    /// Maximum time (in seconds) to wait for LLM responses.
    static let transformationTimeout = "transformationTimeout"

    /// Maximum number of history entries to retain.
    static let historyEntryLimit = "historyEntryLimit"

    /// Whether global hotkey listening is enabled.
    static let hotkeyListeningEnabled = "hotkeyListeningEnabled"

    // MARK: - API Keys (legacy @AppStorage keys for Keychain migration)

    /// OpenAI API key for GPT models (legacy @AppStorage key; now migrated to Keychain).
    static let openAIKey = "openai_api_key"

    /// Anthropic API key for Claude models (legacy @AppStorage key; now migrated to Keychain).
    static let anthropicKey = "anthropic_api_key"

    /// OpenRouter API key for aggregated model access (legacy @AppStorage key; now migrated to Keychain).
    static let openRouterKey = "openrouter_api_key"

    // MARK: - Ollama Configuration

    /// Ollama server host URL (e.g., "http://localhost").
    static let ollamaHost = "ollama_host"

    /// Ollama server port (e.g., "11434").
    static let ollamaPort = "ollama_port"

    // MARK: - AWS Bedrock Configuration

    /// AWS authentication method (profile or access_key).
    static let awsAuthMethod = "aws_auth_method"

    /// AWS profile name for profile-based authentication.
    static let awsProfile = "aws_profile"

    /// AWS access key ID for key-based authentication (legacy @AppStorage key; now migrated to Keychain).
    static let awsAccessKey = "aws_access_key"

    /// AWS secret access key for key-based authentication (legacy @AppStorage key; now migrated to Keychain).
    static let awsSecretKey = "aws_secret_key"

    /// AWS region for Bedrock API calls.
    static let awsRegion = "aws_region"

    /// AWS bearer token for token-based authentication (legacy @AppStorage key; now migrated to Keychain).
    static let awsBearerToken = "aws_bearer_token"

    /// AWS Bedrock model ID.
    static let awsModelId = "aws_model_id"

    // MARK: - Transformations

    /// JSON-encoded array of TransformationConfig objects.
    static let transformations = "transformations"

    // MARK: - Onboarding

    /// Whether the app has been launched at least once.
    static let hasLaunchedBefore = "hasLaunchedBefore"

    /// Whether onboarding has been completed.
    static let onboardingCompleted = "onboardingCompleted"

    /// Current onboarding step (0-based index).
    static let onboardingStep = "onboardingStep"
}

// MARK: - Default Values

/// Default values for settings, used in @AppStorage declarations.
///
/// Centralizing defaults ensures consistency across the app
/// and makes it easy to reset to factory defaults.
enum DefaultSettings {
    // General
    static let launchAtLogin = false
    static let soundEffectsEnabled = true
    static let transformationTimeout = 30.0
    static let historyEntryLimit = 100
    static let hotkeyListeningEnabled = true

    // Ollama
    static let ollamaHost = "http://localhost"
    static let ollamaPort = "11434"

    // AWS
    static let awsRegion = "us-east-1"
    static let awsProfile = "default"

    // Onboarding
    static let hasLaunchedBefore = false
    static let onboardingCompleted = false
    static let onboardingStep = 0
}
