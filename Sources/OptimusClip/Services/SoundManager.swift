import AppKit
import Foundation

/// Manages sound effects for the application.
///
/// Provides subtle audio feedback for paste operations.
/// Uses system sounds by default but can be configured with custom sounds.
///
/// Reads the `soundEffectsEnabled` setting from UserDefaults to respect user preferences.
@MainActor
final class SoundManager {
    // MARK: - Singleton

    static let shared = SoundManager()

    // MARK: - Dependencies

    private let userDefaults: UserDefaults

    // MARK: - Configuration

    /// Whether sounds are enabled based on user setting.
    /// Reads from UserDefaults each time to stay in sync with Settings UI.
    var soundsEnabled: Bool {
        self.userDefaults.object(forKey: SettingsKey.soundEffectsEnabled) as? Bool
            ?? DefaultSettings.soundEffectsEnabled
    }

    /// Volume for sound effects (0.0 to 1.0). Defaults to 0.5 for subtlety.
    var volume: Float = 0.5

    /// The system sound to use for paste completion.
    /// Available options: Tink, Pop, Glass, Bottle, Purr, Ping, etc.
    var pasteSound: String = "Tink"

    // MARK: - Private Properties

    private var cachedSounds: [String: NSSound] = [:]

    // MARK: - Initialization

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Public API

    /// Plays a subtle sound when a paste operation completes successfully.
    func playPasteSound() {
        guard self.soundsEnabled else { return }
        self.playSystemSound(self.pasteSound)
    }

    /// Plays a sound indicating an error occurred.
    func playErrorSound() {
        guard self.soundsEnabled else { return }
        self.playSystemSound("Basso")
    }

    /// Plays the system beep sound, respecting the sound effects setting.
    ///
    /// Use this instead of calling `NSSound.beep()` directly.
    func playBeep() {
        guard self.soundsEnabled else { return }
        NSSound.beep()
    }

    // MARK: - Private Methods

    private func playSystemSound(_ name: String) {
        // Check cache first
        if let cached = self.cachedSounds[name] {
            cached.volume = self.volume
            cached.play()
            return
        }

        // Load from system sounds
        guard let sound = NSSound(named: NSSound.Name(name)) else {
            // Fallback to system beep if sound not found
            NSSound.beep()
            return
        }

        sound.volume = self.volume
        self.cachedSounds[name] = sound
        sound.play()
    }

    /// Plays a custom sound from a file path.
    /// - Parameter path: Path to the sound file (aiff, wav, mp3).
    func playCustomSound(at path: String) {
        guard self.soundsEnabled else { return }

        let url = URL(fileURLWithPath: path)
        guard let sound = NSSound(contentsOf: url, byReference: true) else {
            return
        }

        sound.volume = self.volume
        sound.play()
    }
}
