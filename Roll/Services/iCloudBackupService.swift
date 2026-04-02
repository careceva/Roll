import Foundation
import Security

/// Persists album names to the iOS Keychain so they survive app reinstalls.
/// Keychain data is not removed when an app is deleted, unlike UserDefaults or SwiftData.
class iCloudBackupService {
    static let shared = iCloudBackupService()

    private let albumsKey = "roll_album_names"
    private let hasLaunchedKey = "roll_has_launched"

    private init() {}

    // MARK: - Write

    func saveAlbums(_ names: [String]) {
        guard let data = try? JSONEncoder().encode(names) else { return }
        save(key: albumsKey, data: data)
        save(key: hasLaunchedKey, data: Data([1]))
    }

    // MARK: - Read

    /// Album names saved from a previous install.
    func recoverableAlbumNames() -> [String] {
        guard load(key: hasLaunchedKey) != nil,
              let data = load(key: albumsKey),
              let names = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return names
    }

    // MARK: - Reset

    func clear() {
        delete(key: albumsKey)
        delete(key: hasLaunchedKey)
    }

    // MARK: - Keychain Helpers

    private func save(key: String, data: Data) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func load(key: String) -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        return result as? Data
    }

    private func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
