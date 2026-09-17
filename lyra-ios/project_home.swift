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

    func create_project(name: String, description: String) async {
        do {
            try await client.createProject(CreateProject(name: name, description: description))
            errorMessage = nil
            await load_project()
        } catch {
            if let apiError = error as? APIError {
                errorMessage = apiError.error
            } else {
                errorMessage = "Failed to create project. Please try again."
            }
        }
    }
}

// MARK: - Project View
public struct Project_view: View {
    @ObservedObject var projectService: ProjectService
    @ObservedObject var ticketService: TicketService
    @State private var showCreateSheet = false
    @State private var showCreateProject = false

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateProject = true
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
        .sheet(isPresented: $showCreateProject) {
            NewProjectView(projectService: projectService)
        }
        .task {
            await projectService.load_project()
        }
        .refreshable {
            await projectService.load_project()
        }
    }
}

// MARK: - New Project Sheet
struct NewProjectView: View {
    @ObservedObject var projectService: ProjectService
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var isCreating = false

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
            ZStack {
                Color(red: 0.04, green: 0.06, blue: 0.14)
                    .ignoresSafeArea()

                VStack(spacing: 28) {
                    VStack(spacing: 8) {
                        Text("New Project")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Give your project a name and description")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(.top, 12)

                    VStack(spacing: 18) {
                        modernTextField(placeholder: "Project Name", text: $name)

                        ZStack(alignment: .topLeading) {
                            if description.isEmpty {
                                Text("Description")
                                    .foregroundStyle(.white.opacity(0.35))
                                    .padding(.horizontal, 16)
                                    .padding(.top, 14)
                            }

                            TextEditor(text: $description)
                                .scrollContentBackground(.hidden)
                                .foregroundStyle(.white)
                                .tint(Color(red: 0.5, green: 0.4, blue: 1.0))
                                .frame(minHeight: 120)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
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

                    Button {
                        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        isCreating = true

                        Task {
                            await projectService.create_project(name: name, description: description)
                            isCreating = false
                            dismiss()
                        }
                    } label: {
                        HStack {
                            if isCreating {
                                ProgressView().tint(.white)
                            }
                            Text(isCreating ? "Creating..." : "Create Project")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(lyraGradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color(red: 0.4, green: 0.3, blue: 1.0).opacity(0.45), radius: 16, y: 8)
                    }
                    .disabled(isCreating || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(10)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                }
            }
            .toolbarBackground(Color(red: 0.04, green: 0.06, blue: 0.14), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func modernTextField(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textInputAutocapitalization(.sentences)
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
}

#Preview {
    NavigationStack {
        Project_view(
            projectService: ProjectService(),
            ticketService: TicketService()
        )
    }
}
