//
//  project_home.swift
//  lyra-ios
//
//  Created by Lyrindra Labs on 5/7/2026.
//

import SwiftUI
internal import Combine

// MARK: - Service
@MainActor
class ProjectService: ObservableObject {
    @Published var projects: [Project] = []
    @Published var tickets: [Ticket] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    private let client = LyraAPIClient.shared
    
    func load_project() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            projects = try await client.getProjects()
            errorMessage = nil
            print("✅ Successfully decoded \(projects.count) projects")
        } catch {
            print("❌ Load Projects Error: \(error)")
            
            if let apiError = error as? APIError {
                errorMessage = apiError.error
            } else if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    errorMessage = "No internet connection"
                case .timedOut:
                    errorMessage = "Request timed out"
                default:
                    errorMessage = "Could not connect to the server"
                }
            } else {
                errorMessage = "Failed to load projects. Please try again."
            }
        }
    }
}

// MARK: - Project View
public struct Project_view: View {
    @ObservedObject var projectService: ProjectService
    @ObservedObject var ticketService: TicketService
    @State private var showCreateSheet = false
    
    public var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.06, blue: 0.14)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if let error = projectService.errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.12))
                }
                
                if projectService.isLoading && projectService.projects.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(Color(red: 0.55, green: 0.4, blue: 1.0))
                            .scaleEffect(1.2)
                        
                        Text("Loading projects...")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(projectService.projects) { project in
                            NavigationLink {
                                TicketListView(
                                    service: ticketService,
                                    projectService: projectService,
                                    currentProject: project,
                                    showCreateSheet: $showCreateSheet
                                )
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(project.name)
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    
                                    Text(project.description)
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.55))
                                        .lineLimit(2)
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
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Projects")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Color(red: 0.04, green: 0.06, blue: 0.14), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await projectService.load_project()
        }
        .refreshable {
            await projectService.load_project()
        }
    }
}

#Preview {
    NavigationStack {
        Project_view(
            projectService: ProjectService(),
            ticketService: TicketService()
        )
    }
}
