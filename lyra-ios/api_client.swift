//
//  api_client.swift
//  lyra-ios
//
//  Created by Lyrindra Labs on 16/9/2026.
//

import Foundation

/// One URLSession for Lyra JSON.
///
/// Does not call `POST /login`, `POST /projects`, or any DELETE routes.
/// Server GETs `/tickets` and `/projects` work without JWT; iOS sends
/// `Authorization: Bearer` when Settings has a non-empty token.
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

    func addComment(ticketId: Int, _ body: CommentCreate) async throws -> Comment {
        try await post("/tickets/\(ticketId)/comments", body: body)
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let data = try await perform(method: "GET", path: path, body: nil)
        return try decoder.decode(T.self, from: data)
    }

    private func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        let data = try await perform(method: "POST", path: path, body: body)
        return try decoder.decode(T.self, from: data)
    }

    private func perform(method: String, path: String, body: (any Encodable)?) async throws -> Data {
        let url = try makeURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let token = settings.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !token.isEmpty {
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
            if let payload = try? decoder.decode(ErrorBody.self, from: data) {
                throw APIError(error: payload.error, statusCode: http.statusCode)
            }
            throw APIError(error: "Request failed (\(http.statusCode))", statusCode: http.statusCode)
        }

        guard (200...299).contains(http.statusCode) else {
            throw APIError(error: "Unexpected status (\(http.statusCode))", statusCode: http.statusCode)
        }

        return data
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
