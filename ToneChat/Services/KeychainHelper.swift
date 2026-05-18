import Foundation
import Security

enum KeychainHelper {
    private static let service = "com.tonechat.app"
    private static let tokenAccount = "authToken"
    private static let tierAccount = "sessionTier"
    private static let deviceIdAccount = "deviceId"

    // MARK: - Auth token

    static func saveToken(_ token: String, tier: String) {
        saveString(token, account: tokenAccount)
        saveString(tier, account: tierAccount)
    }

    static func readToken() -> String? {
        readString(account: tokenAccount)
    }

    static func readTier() -> String? {
        readString(account: tierAccount)
    }

    static func deleteToken() {
        deleteItem(account: tokenAccount)
        deleteItem(account: tierAccount)
    }

    // MARK: - Device ID

    static func deviceId() -> String {
        if let existing = readString(account: deviceIdAccount) {
            return existing
        }
        let id = UUID().uuidString
        saveString(id, account: deviceIdAccount)
        return id
    }

    // MARK: - Private

    private static func saveString(_ value: String, account: String) {
        let data = Data(value.utf8)
        deleteItem(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func readString(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func deleteItem(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
