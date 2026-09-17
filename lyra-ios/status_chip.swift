//
//  status_chip.swift
//  lyra-ios
//
//  Created by Lyrindra Labs on 17/9/2026.
//

import SwiftUI

struct StatusChip: View {
    let status: TicketStatus

    var body: some View {
        let color = Constants.color(for: status)
        Text(Self.label(for: status))
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.18), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.35), lineWidth: 1)
            )
    }

    /// Display labels only. Do not change TicketStatus raw values / CONTRACT.
    static func label(for status: TicketStatus) -> String {
        switch status {
        case .queued: return "Agent: Queued"
        case .running: return "Agent: Running"
        case .pr_opening: return "Agent: PR opening"
        case .awaiting_you: return "Awaiting you"
        case .pending_review: return "Pending review"
        case .closed: return "Closed"
        case .failed: return "Failed"
        case .unknown: return "Unknown"
        }
    }
}

/// Opens `github_pr_url` in Safari / the GitHub app. Does not call GitHub APIs.
struct GitHubPRLink: View {
    let urlString: String
    var compact: Bool = false

    static func url(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    var body: some View {
        if let url = Self.url(from: urlString) {
            Link(destination: url) {
                if compact {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                        Text("PR")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.55, green: 0.45, blue: 1.0))
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.right.square")
                        Text("Open Pull Request")
                            .fontWeight(.medium)
                        Spacer(minLength: 0)
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.55, green: 0.45, blue: 1.0))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                }
            }
            .buttonStyle(.borderless)
        }
    }
}
