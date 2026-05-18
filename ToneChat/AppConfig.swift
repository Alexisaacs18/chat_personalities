import Foundation

enum AppConfig {
    /// Override in scheme: TONECHAT_API_BASE = http://127.0.0.1:8787 for Simulator
    static var apiBaseURL: URL {
        if let env = ProcessInfo.processInfo.environment["TONECHAT_API_BASE"],
           let url = URL(string: env) {
            return url
        }
        if let plist = Bundle.main.object(forInfoDictionaryKey: "TONECHAT_API_BASE") as? String,
           let url = URL(string: plist) {
            return url
        }
        return URL(string: "http://127.0.0.1:8787")!
    }

    static let privacyPolicyURL = URL(string: "https://github.com/alexisaacs/chat_personalities/blob/main/PRIVACY.md")!

    static let voiceTestPrompt = "Say hello and tell me what you think of rainy days."
}
