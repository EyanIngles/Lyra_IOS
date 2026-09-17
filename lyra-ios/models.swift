//
//  models.swift
//  lyra-ios
//
//  Created by Lyrindra Labs on 16/9/2026.
//

import Foundation

// CONTRACT JSON uses snake_case keys. Models use explicit CodingKeys with those
// names (not convertFromSnakeCase) so fields like `type` decode safely.

enum TicketStatus: String, Codable, Hashable {
    case queued
    case running
    case awaiting_you
    case pr_opening
    case pending_review
    case closed
    case failed
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? ""
        self = TicketStatus(rawValue: raw) ?? .unknown
    }
}

struct Comment: Codable, Identifiable {
    let id: Int
    let text: String
    let author_name: String
    let author_type: String
    let author_role: String
    let model: String
    let format: String
    let display: String

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case author_name
        case author_type
        case author_role
        case model
        case format
        case display
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        author_name = try container.decodeIfPresent(String.self, forKey: .author_name) ?? ""
        author_type = try container.decodeIfPresent(String.self, forKey: .author_type) ?? ""
        author_role = try container.decodeIfPresent(String.self, forKey: .author_role) ?? ""
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
        format = try container.decodeIfPresent(String.self, forKey: .format) ?? ""
        display = try container.decodeIfPresent(String.self, forKey: .display) ?? ""
    }
}

struct Ticket: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String
    let project_id: Int
    let status: TicketStatus
    let github_pr_url: String
    let last_model: String
    let comments: [Comment]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case project_id
        case status
        case github_pr_url
        case last_model
        case comments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        project_id = try container.decode(Int.self, forKey: .project_id)
        status = try container.decodeIfPresent(TicketStatus.self, forKey: .status) ?? .unknown
        github_pr_url = try container.decodeIfPresent(String.self, forKey: .github_pr_url) ?? ""
        last_model = try container.decodeIfPresent(String.self, forKey: .last_model) ?? ""
        comments = try container.decodeIfPresent([Comment].self, forKey: .comments) ?? []
    }
}

struct Project: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String
    let tickets: [Ticket]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case tickets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        tickets = try container.decodeIfPresent([Ticket].self, forKey: .tickets) ?? []
    }
}

struct CreateProject: Codable {
    let name: String
    let description: String

    enum CodingKeys: String, CodingKey {
        case name
        case description
    }
}

struct TicketCreate: Codable {
    let name: String
    let description: String
    let project_id: Int

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case project_id
    }
}

struct CommentCreate: Codable {
    let text: String
}

struct CurrentUser: Codable, Identifiable {
    let id: Int
    let username: String
    let type: String
    let role: String
    let name: String
    let email: String

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case type
        case role
        case name
        case email
    }
}

struct APIError: Error, LocalizedError, Equatable {
    let error: String
    let statusCode: Int

    var errorDescription: String? { error }
}

struct AuthorizeRequest: Encodable {
    let username: String
    let password: String
    let client_id: String
    let code_challenge: String
    let code_challenge_method: String
}

struct AuthorizeResponse: Decodable {
    let code: String
}

struct AuthorizationCodeTokenRequest: Encodable {
    let grant_type: String
    let client_id: String
    let code: String
    let code_verifier: String
}

struct RefreshTokenRequest: Encodable {
    let grant_type: String
    let refresh_token: String
}

struct TokenResponse: Decodable {
    let access_token: String
    let refresh_token: String
    let token_type: String
    let expires_in: Int
}
