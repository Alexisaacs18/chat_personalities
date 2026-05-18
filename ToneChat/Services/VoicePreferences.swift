import Foundation
import SwiftUI

/// Global default voice for new chats; synced from Settings.
enum VoicePreferences {
    private static let defaultVoiceKey = "defaultVoiceId"

    static var defaultVoiceId: String {
        get {
            UserDefaults.standard.string(forKey: defaultVoiceKey)
                ?? PresetLoader.defaultPersona.id
        }
        set {
            UserDefaults.standard.set(newValue, forKey: defaultVoiceKey)
        }
    }
}
