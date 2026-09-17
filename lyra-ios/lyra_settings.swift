//
//  lyra_settings.swift
//  lyra-ios
//
//  Created by Lyrindra Labs on 16/9/2026.
//

import Foundation
internal import Combine

/// Persisted Pi vs custom BASE_URL. Tokens live in the Keychain via AuthSession.
final class LyraSettings: ObservableObject {
    static let shared = LyraSettings()

    static let legacyAccessTokenKey = "lyra.accessToken"

    private enum Keys {
        static let usePi = "lyra.usePi"
        static let customBaseURL = "lyra.customBaseURL"
    }

    @Published var usePi: Bool {
        didSet { UserDefaults.standard.set(usePi, forKey: Keys.usePi) }
    }

    @Published var customBaseURL: String {
        didSet { UserDefaults.standard.set(customBaseURL, forKey: Keys.customBaseURL) }
    }

    var baseURL: String {
        let raw = usePi ? Constants.piBaseURL : customBaseURL
        return Self.stripTrailingSlash(raw)
    }

    private init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Keys.usePi) == nil {
            usePi = true
        } else {
            usePi = defaults.bool(forKey: Keys.usePi)
        }
        customBaseURL = defaults.string(forKey: Keys.customBaseURL) ?? ""
        if defaults.object(forKey: Self.legacyAccessTokenKey) != nil {
            defaults.removeObject(forKey: Self.legacyAccessTokenKey)
        }
    }

    func save(usePi: Bool, customBaseURL: String) {
        self.usePi = usePi
        self.customBaseURL = Self.stripTrailingSlash(customBaseURL)
    }

    static func stripTrailingSlash(_ url: String) -> String {
        var result = url.trimmingCharacters(in: .whitespacesAndNewlines)
        while result.hasSuffix("/") {
            result.removeLast()
        }
        return result
    }
}

func load_base_url() -> String {
    LyraSettings.shared.baseURL
}
