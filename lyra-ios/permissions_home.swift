//
//  permissions_home.swift
//  lyra-ios
//
//  Created by Lyrindra Labs on 17/9/2026.
//

import SwiftUI
internal import Combine

// MARK: - Service
@MainActor
class PermissionService: ObservableObject {
    @Published var permissions: [PermissionRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var actingId: Int? = nil

    private let client = LyraAPIClient.shared

    func fetchPending() async {
        let showSpinner = permissions.isEmpty
        if showSpinner { isLoading = true }

        do {
            permissions = try await client.getPendingPermissions()
            errorMessage = nil
        } catch {
            errorMessage = Self.message(for: error, fallback: "Failed to load permissions")
        }

        isLoading = false
    }

    func approve(id: Int) async {
        actingId = id
        defer { actingId = nil }

        do {
            _ = try await client.approvePermission(id: id)
            permissions.removeAll { $0.id == id }
            errorMessage = nil
        } catch {
            errorMessage = Self.message(for: error, fallback: "Failed to approve")
            await fetchPending()
        }
    }

    func deny(id: Int) async {
        actingId = id
        defer { actingId = nil }

        do {
            _ = try await client.denyPermission(id: id)
            permissions.removeAll { $0.id == id }
            errorMessage = nil
        } catch {
            errorMessage = Self.message(for: error, fallback: "Failed to deny")
            await fetchPending()
        }
    }

    private static func message(for error: Error, fallback: String) -> String {
        if let apiError = error as? APIError {
            return apiError.error
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "No internet connection"
            case .timedOut:
                return "Request timed out"
            default:
                return "Could not connect to the server"
            }
        }
        return "\(fallback): \(error.localizedDescription)"
    }
}

// MARK: - Needs you tab
struct PermissionsTabView: View {
    @ObservedObject var service: PermissionService
    @ObservedObject var ticketService: TicketService

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.06, blue: 0.14)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if let error = service.errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.12))
                    }

                    if service.isLoading && service.permissions.isEmpty {
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(Color(red: 0.55, green: 0.4, blue: 1.0))
                                .scaleEffect(1.2)

                            Text("Loading…")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if service.permissions.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "hand.raised")
                                .font(.system(size: 40))
                                .foregroundStyle(.white.opacity(0.25))

                            Text("Nothing waiting")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(service.permissions) { permission in
                                PermissionRow(
                                    permission: permission,
                                    ticket: ticketService.tickets.first(where: { $0.id == permission.ticket_id }),
                                    ticketService: ticketService,
                                    isActing: service.actingId == permission.id,
                                    onApprove: {
                                        Task { await service.approve(id: permission.id) }
                                    },
                                    onDeny: {
                                        Task { await service.deny(id: permission.id) }
                                    }
                                )
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .refreshable {
                            await service.fetchPending()
                        }
                    }
                }
            }
            .navigationTitle("Needs you")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color(red: 0.04, green: 0.06, blue: 0.14), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                while !Task.isCancelled {
                    await service.fetchPending()
                    try? await Task.sleep(for: .seconds(5))
                }
            }
        }
    }
}

// MARK: - Row
private struct PermissionRow: View {
    let permission: PermissionRequest
    let ticket: Ticket?
    let ticketService: TicketService
    let isActing: Bool
    let onApprove: () -> Void
    let onDeny: () -> Void

    private var title: String {
        let trimmed = permission.display.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? permission.author_name : trimmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title.isEmpty ? "Permission" : title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let ticket {
                    NavigationLink {
                        TicketDetailView(ticket: ticket, service: ticketService)
                    } label: {
                        Text("Ticket #\(permission.ticket_id)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color(red: 0.55, green: 0.45, blue: 1.0))
                    }
                } else {
                    Text("Ticket #\(permission.ticket_id)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            if !permission.tool.isEmpty {
                Text(permission.tool)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }

            if !permission.payload.isEmpty {
                Text(permission.payload)
                    .font(.caption.monospaced())
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(4)
            }

            HStack(spacing: 10) {
                Button(action: onApprove) {
                    Text("Approve")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.green.opacity(0.85))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isActing)

                Button(action: onDeny) {
                    Text("Deny")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.85))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isActing)
            }
            .opacity(isActing ? 0.55 : 1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}
