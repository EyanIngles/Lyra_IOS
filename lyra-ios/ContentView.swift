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
    @State private var showCreateSheet = false
    @State private var isLoggedIn = false
    
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
            
            if isLoggedIn {
                TabView {
                    Tab("Home", systemImage: "house") {
                        NavigationStack {
                            Project_view(
                                projectService: ProjectService(),
                                ticketService: service
                            )
                        }
                    }
                    
                    Tab("Settings", systemImage: "gear") {
                        SettingsTabView(isLoggedIn: $isLoggedIn)
                    }
                    
                    Tab("Something else", systemImage: "arrow.2.circlepath.circle") {
                        PlaceholderTabView(title: "Something else")
                    }
                }
                .tint(Color(red: 0.55, green: 0.4, blue: 1.0)) // purple accent for selected tab
            } else {
                LoginView(service: service, isLoggedIn: $isLoggedIn)
            }
        }
    }
}

// MARK: - Settings Tab
private struct SettingsTabView: View {
    @Binding var isLoggedIn: Bool
    
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
            VStack(spacing: 32) {
                Spacer()
                
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
                
                Text("Settings")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button(role: .destructive) {
                    withAnimation {
                        isLoggedIn = false
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.04, green: 0.06, blue: 0.14))
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Placeholder for other tabs
private struct PlaceholderTabView: View {
    let title: String
    
    var body: some View {
        VStack {
            Spacer()
            Text(title)
                .font(.title2.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.04, green: 0.06, blue: 0.14))
    }
}

// MARK: - Ticket List View (Redesigned)
public struct TicketListView: View {
    @ObservedObject var service: TicketService
    @ObservedObject var projectService: ProjectService
    let currentProject: Project?
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
                    let filteredTickets = currentProject == nil
                        ? service.tickets
                        : service.tickets.filter { $0.project_id == currentProject?.id }
                    
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
        .navigationTitle("Tickets")
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
            Text(ticket.name)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            
            Text(ticket.description)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(2)
            
            if !ticket.comments.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left.fill")
                        .font(.caption2)
                    Text("\(ticket.comments.count) comment\(ticket.comments.count == 1 ? "" : "s")")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(Color(red: 0.55, green: 0.45, blue: 1.0))
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
