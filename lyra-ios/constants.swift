//
//  constants.swift
//  lyra-ios
//
//  Created by Lyrindra Labs on 13/6/2026.
//

import SwiftUI

struct Constants {
    /// Production Lyra on the Pi (Tailscale HTTPS). No trailing slash.
    static let piBaseURL = "https://pi.tailcb4684.ts.net:3000"

    /// OAuth public client id (matches server seed / tests).
    static let client_id = "lyra-ios"

    /// App-wide status colors. Chips are step 4; this map is the source of truth.
    static func color(for status: TicketStatus) -> Color {
        switch status {
        case .open:
            return .mint
        case .queued:
            return .yellow
        case .running:
            return .orange
        case .awaiting_you:
            return .blue
        case .pr_opening:
            return .teal
        case .pending_review:
            return .purple
        case .closed:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .gray
        case .unknown:
            return .gray
        }
    }
}
