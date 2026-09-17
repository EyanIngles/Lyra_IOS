//
//  lyra_keychain.swift
//  lyra-ios
//
//  Created by Lyrindra Labs on 17/9/2026.
//

import Foundation
internal import Security

/// Access + refresh tokens only. Never stores the password.
/// Accessible after first unlock on this device (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`).
enum LyraKeychain {
    static let service = "lyra-ios"
    static let accessTokenAccount = "access_token"
    static let refreshTokenAccount = "refresh_token"

    static var accessToken: String? { loadItem(account: accessTokenAccount) }
    static var refreshToken: String? { loadItem(account: refreshTokenAccount) }

    static func save(accessToken: String, refreshToken: String) throws {
        try set(accessToken, account: accessTokenAccount)
        try set(refreshToken, account: refreshTokenAccount)
    }

    static func deleteAll() {
        delete(account: accessTokenAccount)
        delete(account: refreshTokenAccount)
    }

    private static func set(_ value: String, account: String) throws {
        delete(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw APIError(error: "Keychain save failed", statusCode: 0)
        }
    }

    private static func loadItem(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
