//
//  project_home.swift
//  lyra-ios
//
//  Created by Lyrindra Labs on 5/7/2026.
//

import SwiftUI
internal import Combine

// MARK: - Models
struct Project: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String
    let tickets: [Ticket]
}

struct CreateProject: Codable {
    let name: String
    let description: String
}

// MARK: - Service (logic unchanged)
class ProjectService: ObservableObject {
    @Published var projects: [Project] = []
    @Published var tickets: [Ticket] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    init() {
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }
    
    func load_project() async {
        isLoading = true
        defer { isLoading = false }
        
        let baseURL = load_base_url()
        guard let url = URL(string: "\(baseURL)/projects") else {
            errorMessage = "Invalid URL"
            return
        }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            let project = try decoder.decode([Project].self, from: data)
            projects = project
            
            if let https_response = response as? HTTPURLResponse {
                print("Status Code: \(https_response.statusCode)")
            }
        } catch {
            print("❌ Load Projects Error: \(error)")
            
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    self.errorMessage = "No internet connection"
                case .timedOut:
                    self.errorMessage = "Request timed out"
                default:
                    self.errorMessage = "Could not connect to the server"
                }
            } else {
                self.errorMessage = "Failed to load projects. Please try again."
            }
        }
    }
    
    func create_project(name: String, description: String) async {
        isLoading = true
        defer { isLoading = false }
        
        let baseURL = load_base_url()
        guard let url = URL(string: "\(baseURL)/projects") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = CreateProject(name: name, description: description)
        
        do {
            request.httpBody = try encoder.encode(body)
            let (data, _) = try await URLSession.shared.data(for: request)
            
            _ = try? decoder.decode(Ticket.self, from: data)
            await load_project()
        } catch {
            errorMessage = "Failed to create project: \(error.localizedDescription)"
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
                        // View All Tickets
                        NavigationLink {
                            TicketListView(
                                service: ticketService,
                                projectService: projectService,
                                currentProject: nil,
                                showCreateSheet: $showCreateSheet
                            )
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .fill(lyraGradient)
                                    )
                                
                                Text("View All Tickets")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.white)
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
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        
                        // Projects
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
            NewProjectView(
                projectService: projectService,
                isPresented: $showCreateProject
            )
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
    @Binding var isPresented: Bool
    
    @State private var projectName = ""
    @State private var projectDescription = ""
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
                    // Header
                    VStack(spacing: 8) {
                        Text("New Project")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text("Give your project a name and description")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(.top, 20)
                    
                    // Form Card
                    VStack(spacing: 18) {
                        modernTextField(
                            placeholder: "Project Name",
                            text: $projectName
                        )
                        
                        modernTextField(
                            placeholder: "Project Description",
                            text: $projectDescription,
                            axis: .vertical
                        )
                        .frame(minHeight: 90, alignment: .top)
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
                    
                    // Create Button
                    Button {
                        guard !projectName.isEmpty else { return }
                        isCreating = true
                        
                        Task {
                            await projectService.create_project(
                                name: projectName,
                                description: projectDescription
                            )
                            isCreating = false
                            isPresented = false
                        }
                    } label: {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .tint(.white)
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
                    .disabled(isCreating || projectName.isEmpty)
                    .opacity(projectName.isEmpty ? 0.5 : 1)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isPresented = false
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
    
    // MARK: - Reusable Field
    private func modernTextField(
        placeholder: String,
        text: Binding<String>,
        axis: Axis = .horizontal
    ) -> some View {
        TextField(placeholder, text: text, axis: axis)
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
