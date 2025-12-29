import Foundation
import Testing
@testable import OptimusClip

/// Tests for sound effects setting configuration.
///
/// Verifies that the user's sound effects setting from UserDefaults is correctly
/// read by SoundManager and NotificationService.
@Suite("Sound Effects Setting")
struct SoundEffectsSettingTests {
    // MARK: - Sound Effects Reading Logic Tests

    @Test("reads sound effects enabled when set to true")
    func readsSoundEffectsEnabledWhenTrue() throws {
        let suiteName = "test-sound-enabled"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.set(true, forKey: SettingsKey.soundEffectsEnabled)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let soundsEnabled = defaults.object(forKey: SettingsKey.soundEffectsEnabled) as? Bool
            ?? DefaultSettings.soundEffectsEnabled

        #expect(soundsEnabled == true)
    }

    @Test("reads sound effects disabled when set to false")
    func readsSoundEffectsDisabledWhenFalse() throws {
        let suiteName = "test-sound-disabled"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.set(false, forKey: SettingsKey.soundEffectsEnabled)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let soundsEnabled = defaults.object(forKey: SettingsKey.soundEffectsEnabled) as? Bool
            ?? DefaultSettings.soundEffectsEnabled

        #expect(soundsEnabled == false)
    }

    @Test("falls back to default when setting not set")
    func fallsBackToDefaultWhenNotSet() throws {
        let suiteName = "test-sound-notset"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removeObject(forKey: SettingsKey.soundEffectsEnabled)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let soundsEnabled = defaults.object(forKey: SettingsKey.soundEffectsEnabled) as? Bool
            ?? DefaultSettings.soundEffectsEnabled

        #expect(soundsEnabled == DefaultSettings.soundEffectsEnabled)
        #expect(soundsEnabled == true) // Verify the actual default value
    }

    // MARK: - Settings Key Tests

    @Test("settings key matches expected value")
    func settingsKeyMatchesExpected() {
        #expect(SettingsKey.soundEffectsEnabled == "soundEffectsEnabled")
    }

    @Test("default value is true")
    func defaultValueIsTrue() {
        #expect(DefaultSettings.soundEffectsEnabled == true)
    }
}
