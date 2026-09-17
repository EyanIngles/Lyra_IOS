//
//  api_client.swift
//  lyra-ios
//
//  Created by Lyrindra Labs on 16/9/2026.
//

import Foundation

/// One URLSession for Lyra JSON.
///
/// Does not call `POST /login` or any DELETE routes.
/// Always sends `Authorization: Bearer` when AuthSession/Keychain has an access token.
/// On HTTP 401 `invalid_token`, refreshes once and retries the original request.
final class LyraAPIClient {
    static let shared = LyraAPIClient()

    private let settings: LyraSettings
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(settings: LyraSettings = .shared, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        // Explicit CodingKeys on models match CONTRACT snake_case.
        // convertFromSnakeCase is not used so `type` cannot be rewritten.
    }

    func getTickets() async throws -> [Ticket] {
        try await get("/tickets")
    }

    func getTicket(id: Int) async throws -> Ticket {
        try await get("/tickets/\(id)")
    }

    func getProjects() async throws -> [Project] {
        try await get("/projects")
    }

    func getCurrentUser() async throws -> CurrentUser {
        try await get("/current_user")
    }

    func createTicket(_ body: TicketCreate) async throws -> Ticket {
        try await post("/tickets", body: body)
    }

    /// POST /projects JSON with Bearer. Server returns 201 empty body — do not decode JSON.
    /// Server does not yet require JWT; iOS still sends Bearer. Human-only gate is a later Lyra_server PR.
    func createProject(_ body: CreateProject) async throws {
        try await postDiscardingBody("/projects", body: body)
    }

    func addComment(ticketId: Int, _ body: CommentCreate) async throws -> Comment {
        try await post("/tickets/\(ticketId)/comments", body: body)
    }

    func getPendingPermissions() async throws -> [PermissionRequest] {
        try await get("/permissions?status=pending")
    }

    func approvePermission(id: Int) async throws -> PermissionRequest {
        try await postNoBody("/permissions/\(id)/approve")
    }

    func denyPermission(id: Int) async throws -> PermissionRequest {
        try await postNoBody("/permissions/\(id)/deny")
    }

    func requestPR(ticketId: Int) async throws -> Ticket {
        try await postNoBody("/tickets/\(ticketId)/actions/request_pr")
    }

    func closeTicket(ticketId: Int) async throws -> Ticket {
        try await postNoBody("/tickets/\(ticketId)/actions/close")
    }

    func deployTicket(ticketId: Int) async throws -> Ticket {
        try await postNoBody("/tickets/\(ticketId)/actions/deploy")
    }

    func authorize(username: String, password: String, codeChallenge: String) async throws -> AuthorizeResponse {
        try await post(
            "/oauth/authorize",
            body: AuthorizeRequest(
                username: username,
                password: password,
                client_id: Constants.client_id,
                code_challenge: codeChallenge,
                code_challenge_method: "S256"
            )
        )
    }

    func exchangeAuthorizationCode(code: String, codeVerifier: String) async throws -> TokenResponse {
        try await post(
            "/oauth/token",
            body: AuthorizationCodeTokenRequest(
                grant_type: "authorization_code",
                client_id: Constants.client_id,
                code: code,
                code_verifier: codeVerifier
            )
        )
    }

    func refreshTokens(refreshToken: String) async throws -> TokenResponse {
        try await post(
            "/oauth/token",
            body: RefreshTokenRequest(
                grant_type: "refresh_token",
                refresh_token: refreshToken
            )
        )
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let data = try await perform(method: "GET", path: path, body: nil)
        return try decoder.decode(T.self, from: data)
    }

    private func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        let data = try await perform(method: "POST", path: path, body: body)
        return try decoder.decode(T.self, from: data)
    }

    /// POST with no JSON body (`perform(..., body: nil)`), then decode.
    private func postNoBody<T: Decodable>(_ path: String) async throws -> T {
        let data = try await perform(method: "POST", path: path, body: nil)
        return try decoder.decode(T.self, from: data)
    }

    /// POST that treats 201/200 OK as success and discards the body.
    private func postDiscardingBody<B: Encodable>(_ path: String, body: B) async throws {
        _ = try await perform(method: "POST", path: path, body: body)
    }

    private func perform(
        method: String,
        path: String,
        body: (any Encodable)?,
        isRetry: Bool = false
    ) async throws -> Data {
        let url = try makeURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = AuthSession.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError(error: "Invalid response", statusCode: 0)
        }

        if (400...599).contains(http.statusCode) {
            let apiError: APIError
            if let payload = try? decoder.decode(ErrorBody.self, from: data) {
                apiError = APIError(error: payload.error, statusCode: http.statusCode)
            } else {
                apiError = APIError(error: "Request failed (\(http.statusCode))", statusCode: http.statusCode)
            }

            if http.statusCode == 401, apiError.error == "invalid_token" {
                if !isRetry, shouldAttemptTokenRefresh(path: path) {
                    try await AuthSession.shared.refreshAccessToken()
                    return try await perform(method: method, path: path, body: body, isRetry: true)
                }
                if isRetry {
                    AuthSession.shared.logout()
                }
            }

            throw apiError
        }

        guard (200...299).contains(http.statusCode) else {
            throw APIError(error: "Unexpected status (\(http.statusCode))", statusCode: http.statusCode)
        }

        return data
    }

    private func shouldAttemptTokenRefresh(path: String) -> Bool {
        path != "/oauth/authorize" && path != "/oauth/token"
    }

    private func makeURL(path: String) throws -> URL {
        let base = settings.baseURL
        guard !base.isEmpty else {
            throw APIError(error: "Invalid URL", statusCode: 0)
        }
        let suffix = path.hasPrefix("/") ? path : "/\(path)"
        guard let url = URL(string: base + suffix) else {
            throw APIError(error: "Invalid URL", statusCode: 0)
        }
        return url
    }
}

private struct ErrorBody: Decodable {
    let error: String
}
