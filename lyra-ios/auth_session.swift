//
//  auth_session.swift
//  lyra-ios
//
//  Created by Lyrindra Labs on 17/9/2026.
//

import Foundation
internal import Combine
internal import CryptoKit
internal import Security

/// PKCE S256 + Keychain session. Source of truth for Bearer tokens.
@MainActor
final class AuthSession: ObservableObject {
    static let shared = AuthSession()

    @Published private(set) var isLoggedIn: Bool

    private let client: LyraAPIClient
    private var isRefreshing = false
    private var refreshWaiters: [CheckedContinuation<Void, Error>] = []

    var accessToken: String? {
        let token = LyraKeychain.accessToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return token.isEmpty ? nil : token
    }

    private init(client: LyraAPIClient = .shared) {
        self.client = client
        Self.clearLegacyAccessTokenIfPresent()
        let refresh = LyraKeychain.refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        isLoggedIn = !refresh.isEmpty
    }

    func login(username: String, password: String) async throws {
        let verifier = PKCE.makeVerifier()
        let challenge = PKCE.s256(verifier)
        let auth = try await client.authorize(
            username: username,
            password: password,
            codeChallenge: challenge
        )
        let tokens = try await client.exchangeAuthorizationCode(
            code: auth.code,
            codeVerifier: verifier
        )
        try LyraKeychain.save(accessToken: tokens.access_token, refreshToken: tokens.refresh_token)
        isLoggedIn = true
    }

    func logout() {
        LyraKeychain.deleteAll()
        isLoggedIn = false
    }

    /// On launch: refresh if a refresh token exists, else `GET /current_user` with access.
    func restore() async {
        Self.clearLegacyAccessTokenIfPresent()

        let refresh = LyraKeychain.refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !refresh.isEmpty {
            do {
                try await performRefresh()
                isLoggedIn = true
                return
            } catch {
                // Refresh failed (network or invalid_grant); try existing access token.
                let access = LyraKeychain.accessToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !access.isEmpty {
                    do {
                        _ = try await client.getCurrentUser()
                        isLoggedIn = true
                        return
                    } catch {
                        logout()
                        return
                    }
                }
                logout()
                return
            }
        }

        let access = LyraKeychain.accessToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !access.isEmpty {
            do {
                _ = try await client.getCurrentUser()
                isLoggedIn = true
                return
            } catch {
                logout()
                return
            }
        }

        logout()
    }

    /// One in-flight refresh for 401 `invalid_token` retries. Failure logs out.
    func refreshAccessToken() async throws {
        do {
            try await performRefresh()
        } catch {
            logout()
            throw error
        }
    }

    private func performRefresh() async throws {
        if isRefreshing {
            try await withCheckedThrowingContinuation { continuation in
                refreshWaiters.append(continuation)
            }
            return
        }

        isRefreshing = true
        do {
            let refresh = LyraKeychain.refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !refresh.isEmpty else {
                throw APIError(error: "invalid_token", statusCode: 401)
            }
            let tokens = try await client.refreshTokens(refreshToken: refresh)
            try LyraKeychain.save(accessToken: tokens.access_token, refreshToken: tokens.refresh_token)
            isRefreshing = false
            let waiters = refreshWaiters
            refreshWaiters.removeAll()
            waiters.forEach { $0.resume() }
        } catch {
            isRefreshing = false
            let waiters = refreshWaiters
            refreshWaiters.removeAll()
            waiters.forEach { $0.resume(throwing: error) }
            throw error
        }
    }

    static func clearLegacyAccessTokenIfPresent() {
        let key = LyraSettings.legacyAccessTokenKey
        if UserDefaults.standard.object(forKey: key) != nil {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

enum PKCE {
    /// 32 random bytes → base64url no pad (43 chars, RFC 7636).
    static func makeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            bytes = (0..<32).map { _ in UInt8.random(in: 0...255) }
        }
        return Data(bytes).base64URLNoPad()
    }

    /// SHA256(verifier UTF-8) then base64url no pad — same as Rust `URL_SAFE_NO_PAD.encode(Sha256(verifier))`.
    static func s256(_ verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLNoPad()
    }
}

private extension Data {
    func base64URLNoPad() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
