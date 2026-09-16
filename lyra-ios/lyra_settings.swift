//
//  lyra_settings.swift
//  lyra-ios
//
//  Created by Lyrindra Labs on 16/9/2026.
//

import Foundation
import Combine

/// Persisted Pi vs custom BASE_URL and a temporary access token (Keychain is step 3).
/// The API client reads `baseURL` / `accessToken` per request so Save is visible immediately.
final class LyraSettings: ObservableObject {
    static let shared = LyraSettings()

    private enum Keys {
        static let usePi = "lyra.usePi"
        static let customBaseURL = "lyra.customBaseURL"
        static let accessToken = "lyra.accessToken"
    }

    @Published var usePi: Bool {
        didSet { UserDefaults.standard.set(usePi, forKey: Keys.usePi) }
    }

    @Published var customBaseURL: String {
        didSet { UserDefaults.standard.set(customBaseURL, forKey: Keys.customBaseURL) }
    }

    /// Temporary paste field until step 3 Keychain.
    @Published var accessToken: String {
        didSet { UserDefaults.standard.set(accessToken, forKey: Keys.accessToken) }
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
        accessToken = defaults.string(forKey: Keys.accessToken) ?? ""
    }

    func save(usePi: Bool, customBaseURL: String, accessToken: String) {
        self.usePi = usePi
        self.customBaseURL = Self.stripTrailingSlash(customBaseURL)
        self.accessToken = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
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
