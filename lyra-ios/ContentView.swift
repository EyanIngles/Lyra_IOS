//
//  ContentView.swift
//  lyra-ios
//
//  Created by Lyrindra Labs on 10/5/2026.
//

import SwiftUI

// MARK: - Main App View
struct ContentView: View {
    @StateObject private var service = TicketService()
    @StateObject private var projectService = ProjectService()
    @StateObject private var permissionService = PermissionService()
    @ObservedObject private var auth = AuthSession.shared
    @State private var showCreateSheet = false
    
    // Shared gradient (same as LoginView)
    private let lyraGradient = LinearGradient(
        colors: [
            Color(red: 0.65, green: 0.25, blue: 0.95),
            Color(red: 0.25, green: 0.55, blue: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        ZStack {
            // Consistent deep background
            Color(red: 0.04, green: 0.06, blue: 0.14)
                .ignoresSafeArea()
            
            if auth.isLoggedIn {
                TabView {
                    Tab("Home", systemImage: "house") {
                        NavigationStack {
                            Project_view(
                                projectService: projectService,
                                ticketService: service
                            )
                        }
                    }

                    Tab("Needs you", systemImage: "hand.raised") {
                        PermissionsTabView(
                            service: permissionService,
                            ticketService: service
                        )
                    }
                    .badge(permissionService.permissions.count)
                    
                    Tab("Settings", systemImage: "gear") {
                        SettingsTabView()
                    }
                }
                .tint(Color(red: 0.55, green: 0.4, blue: 1.0)) // purple accent for selected tab
            } else {
                LoginView()
            }
        }
        .task {
            await auth.restore()
        }
    }
}

// MARK: - Settings Tab
private struct SettingsTabView: View {
    @ObservedObject private var settings = LyraSettings.shared
    
    @State private var usePi = true
    @State private var customBaseURL = ""
    @State private var saveMessage: String?
    
    private let lyraGradient = LinearGradient(
        colors: [
            Color(red: 0.65, green: 0.25, blue: 0.95),
            Color(red: 0.25, green: 0.55, blue: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Small logo glow
                    ZStack {
                        Circle()
                            .fill(lyraGradient.opacity(0.2))
                            .frame(width: 90, height: 90)
                            .blur(radius: 20)
                        
                        Text("L")
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundStyle(lyraGradient)
                            .shadow(color: Color(red: 0.4, green: 0.3, blue: 1.0).opacity(0.6), radius: 10)
                    }
                    .padding(.top, 24)
                    
                    Text("Settings")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Server")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                        
                        Picker("Server", selection: $usePi) {
                            Text("Pi").tag(true)
                            Text("Custom").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .colorScheme(.dark)
                        
                        if usePi {
                            Text(Constants.piBaseURL)
                                .font(.footnote.monospaced())
                                .foregroundStyle(.white.opacity(0.55))
                        } else {
                            TextField("https://host:3000", text: $customBaseURL)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                                .foregroundStyle(.white)
                                .tint(Color(red: 0.5, green: 0.4, blue: 1.0))
                        }
                         
                         VStack(alignment: .leading, spacing: 6) {
                            Text("Current base URL")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.45))
                            Text(settings.baseURL.isEmpty ? "—" : settings.baseURL)
                                .font(.footnote.monospaced())
                                .foregroundStyle(.white.opacity(0.85))
                                .textSelection(.enabled)
                        }
                        .padding(.top, 4)
                        
                        Button {
                            settings.save(
                                usePi: usePi,
                                customBaseURL: customBaseURL
                            )
                            saveMessage = "Saved"
                        } label: {
                            Text("Save")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(lyraGradient)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: Color(red: 0.4, green: 0.3, blue: 1.0).opacity(0.45), radius: 16, y: 8)
                        }
                        
                        if let saveMessage {
                            Text(saveMessage)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.green.opacity(0.85))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(22)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)
                    
                    Button(role: .destructive) {
                        withAnimation {
                            AuthSession.shared.logout()
                        }
                    } label: {
                        Text("Sign Out")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red.opacity(0.85))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.04, green: 0.06, blue: 0.14))
            .navigationBarHidden(true)
            .onAppear {
                usePi = settings.usePi
                customBaseURL = settings.customBaseURL
                saveMessage = nil
            }
        }
    }
}

// MARK: - Ticket List View (Redesigned)
public struct TicketListView: View {
    @ObservedObject var service: TicketService
    @ObservedObject var projectService: ProjectService
    let currentProject: Project
    @Binding var showCreateSheet: Bool
    
    private let lyraGradient = LinearGradient(
        colors: [
            Color(red: 0.65, green: 0.25, blue: 0.95),
            Color(red: 0.25, green: 0.55, blue: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public var body: some View {
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
                
                if service.isLoading && service.tickets.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(Color(red: 0.55, green: 0.4, blue: 1.0))
                            .scaleEffect(1.2)
                        
                        Text("Loading tickets...")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    let filteredTickets = service.tickets.filter { $0.project_id == currentProject.id }
                    
                    if filteredTickets.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "ticket")
                                .font(.system(size: 40))
                                .foregroundStyle(.white.opacity(0.25))
                            
                            Text("No tickets yet")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.6))
                            
                            Text("Tap + to create your first ticket")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(filteredTickets) { ticket in
                                NavigationLink {
                                    TicketDetailView(ticket: ticket, service: service)
                                } label: {
                                    TicketRow(ticket: ticket)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .refreshable {
                            await service.fetchTickets()
                        }
                    }
                }
            }
        }
        .navigationTitle(currentProject.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(
                            Circle()
                                .fill(lyraGradient)
                                .shadow(color: Color(red: 0.4, green: 0.3, blue: 1.0).opacity(0.45), radius: 8, y: 4)
                        )
                }
            }
        }
        .toolbarBackground(Color(red: 0.04, green: 0.06, blue: 0.14), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showCreateSheet) {
            CreateTicketView(
                project: currentProject,
                service: service,
                projectService: projectService
            )
        }
        .task {
            await service.fetchTickets()
        }
    }
}

// MARK: - Ticket Row Component
private struct TicketRow: View {
    let ticket: Ticket
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text(ticket.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Spacer(minLength: 8)
                
                StatusChip(status: ticket.status)
            }

            if !ticket.last_model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(ticket.last_model)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
            }
            
            Text(ticket.description)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(2)
            
            let hasPR = GitHubPRLink.url(from: ticket.github_pr_url) != nil
            if !ticket.comments.isEmpty || hasPR {
                HStack(spacing: 8) {
                    if !ticket.comments.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left.fill")
                                .font(.caption2)
                            Text("\(ticket.comments.count) comment\(ticket.comments.count == 1 ? "" : "s")")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(Color(red: 0.55, green: 0.45, blue: 1.0))
                    }
                    
                    Spacer(minLength: 0)
                    
                    GitHubPRLink(urlString: ticket.github_pr_url, compact: true)
                }
            }
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

#Preview {
    ContentView()
}
