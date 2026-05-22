import Foundation
import SwiftUI

/// Global default voice for new chats; synced from Settings.
enum VoicePreferences {
    static let defaultVoiceIdKey = "defaultVoiceId"
    private static let highFidelityKey = "highFidelityReplies"

    static var defaultVoiceId: String {
        get {
            UserDefaults.standard.string(forKey: defaultVoiceIdKey)
                ?? PresetLoader.defaultPersona.id
        }
        set {
            UserDefaults.standard.set(newValue, forKey: defaultVoiceIdKey)
        }
    }

    static var highFidelityReplies: Bool {
        get { UserDefaults.standard.bool(forKey: highFidelityKey) }
        set { UserDefaults.standard.set(newValue, forKey: highFidelityKey) }
    }
}
