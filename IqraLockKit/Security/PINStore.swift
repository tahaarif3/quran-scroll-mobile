import Foundation
import Security

/// Stores a parent PIN in the Keychain for child-mode restrictions.
public enum PINStore {
    private static let service = "com.tahaarif.iqralock.parent-pin"

    public static var isConfigured: Bool {
        load() != nil
    }

    @discardableResult
    public static func save(pin: String) -> Bool {
        guard pin.count >= 4, let data = pin.data(using: .utf8) else { return false }
        delete()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "parent",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    public static func verify(pin: String) -> Bool {
        guard let stored = load() else { return false }
        return stored == pin
    }

    public static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "parent"
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "parent",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let pin = String(data: data, encoding: .utf8) else { return nil }
        return pin
    }
}
