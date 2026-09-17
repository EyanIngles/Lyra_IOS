//
//  ticket_home.swift
//  lyra-ios
//
//  Created by Lyrindra Labs on 10/5/2026.
//

import SwiftUI
internal import Combine

// MARK: - Network Service
@MainActor
class TicketService: ObservableObject {
    
    @Published var tickets: [Ticket] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    private let client = LyraAPIClient.shared
    
    func fetchTickets() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedTickets = try await client.getTickets()
            self.tickets = fetchedTickets
            print("✅ Successfully decoded \(fetchedTickets.count) tickets")
        } catch {
            print("❌ Fetch tickets error: \(error)")
            errorMessage = Self.message(for: error, fallback: "Failed to load tickets")
        }
        
        isLoading = false
    }
    
    func createTicket(name: String, description: String, project: Project) async {
        do {
            let created = try await client.createTicket(
                TicketCreate(name: name, description: description, project_id: project.id)
            )
            await fetchTickets()
            await refreshTicket(id: created.id)
        } catch {
            errorMessage = Self.message(for: error, fallback: "Failed to create ticket")
        }
    }
    
    func addComment(to ticketId: Int, text: String) async {
        do {
            _ = try await client.addComment(ticketId: ticketId, CommentCreate(text: text))
            await refreshTicket(id: ticketId)
        } catch {
            errorMessage = Self.message(for: error, fallback: "Failed to add comment")
        }
    }
    
    /// GET /tickets/:id and replace (or append) that ticket in `tickets`.
    func refreshTicket(id: Int) async {
        do {
            let ticket = try await client.getTicket(id: id)
            if let index = tickets.firstIndex(where: { $0.id == id }) {
                tickets[index] = ticket
            } else {
                tickets.append(ticket)
            }
        } catch {
            print("❌ Refresh ticket \(id) error: \(error)")
        }
    }
    
    func deleteComment(ticketId: Int, commentId: Int) async {
        let baseURL = load_base_url()
        guard let url = URL(string: "\(baseURL)/tickets/\(ticketId)/comments/\(commentId)") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 204 || httpResponse.statusCode == 200 {
                    await fetchTickets()
                } else {
                    errorMessage = "Comment Delete failed: Server returned \(httpResponse.statusCode)"
                }
            }
        } catch {
            errorMessage = "Failed to delete comment from ticket: \(error.localizedDescription)"
        }
    }
    
    func deleteTicket(ticketId: Int) async {
        let baseURL = load_base_url()
        guard let url = URL(string: "\(baseURL)/tickets/\(ticketId)") else {
            errorMessage = "Invalid URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 204 || httpResponse.statusCode == 200 {
                    await fetchTickets()
                } else {
                    errorMessage = "Delete failed: Server returned \(httpResponse.statusCode)"
                }
            }
        } catch {
            errorMessage = "Failed to delete ticket: \(error.localizedDescription)"
        }
    }
    
    func editComment(to ticketId: Int, text: String) async {
        let baseURL = load_base_url()
        guard let url = URL(string: "\(baseURL)/tickets/\(ticketId)/comments") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = CommentCreate(text: text)
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (_, _) = try await URLSession.shared.data(for: request)
            await fetchTickets()
        } catch {
            errorMessage = "Failed to add comment: \(error.localizedDescription)"
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

// MARK: - Create Ticket View
struct CreateTicketView: View {
    let project: Project
    @ObservedObject var service: TicketService
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
                        Text("New Ticket")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text("Adding to \(project.name)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(.top, 12)
                    
                    // Form Card
                    VStack(spacing: 18) {
                        modernTextField(placeholder: "Ticket Name", text: $name)
                        
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
                    
                    // Create Button
                    Button {
                        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        isCreating = true
                        
                        Task {
                            await service.createTicket(name: name, description: description, project: project)
                            isCreating = false
                            dismiss()
                        }
                    } label: {
                        HStack {
                            if isCreating {
                                ProgressView().tint(.white)
                            }
                            Text(isCreating ? "Creating..." : "Create Ticket")
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

// MARK: - Ticket Detail View
struct TicketDetailView: View {
    let ticket: Ticket
    @ObservedObject var service: TicketService
    @Environment(\.dismiss) private var dismiss
    
    @State private var newCommentText = ""
    @State private var isLoading = false
    
    @State private var showWarningDeleteAlert = false
    @State private var showNotCompleteWarningAlert = false
    @State private var showCommentCantDeleteWarningAlert = false
    
    private let lyraGradient = LinearGradient(
        colors: [
            Color(red: 0.65, green: 0.25, blue: 0.95),
            Color(red: 0.25, green: 0.55, blue: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    private var currentTicket: Ticket {
        service.tickets.first(where: { $0.id == ticket.id }) ?? ticket
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.06, blue: 0.14)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Header Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            Text(currentTicket.name)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            
                            Spacer(minLength: 8)
                            
                            StatusChip(status: currentTicket.status)
                        }

                        if !currentTicket.last_model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            HStack(spacing: 6) {
                                Text("Agent")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.45))
                                Text(currentTicket.last_model)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .lineLimit(1)
                            }
                        }
                        
                        Text(currentTicket.description)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    if GitHubPRLink.url(from: currentTicket.github_pr_url) != nil {
                        GitHubPRLink(urlString: currentTicket.github_pr_url)
                            .padding(.horizontal, 16)
                    }
                    
                    // Comments Section
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Comments (\(currentTicket.comments.count))")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                        
                        if currentTicket.comments.isEmpty {
                            Text("No comments yet. Add one below!")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.45))
                                .italic()
                                .padding(.horizontal, 20)
                        } else {
                            ForEach(currentTicket.comments) { comment in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(commentAuthorLabel(comment))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white.opacity(0.55))
                                    
                                    CommentMarkdownText(text: comment.text)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.white.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(Color.white.opacity(0.07), lineWidth: 1)
                                        )
                                )
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
            }
            
            // Bottom comment bar
            VStack {
                Spacer()
                
                HStack(spacing: 12) {
                    TextField("Add a comment...", text: $newCommentText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(.white)
                        .tint(Color(red: 0.5, green: 0.4, blue: 1.0))
                    
                    Button {
                        Task {
                            if !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                await service.addComment(to: ticket.id, text: newCommentText)
                                newCommentText = ""
                            }
                        }
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(
                                Circle()
                                    .fill(lyraGradient)
                            )
                    }
                    .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Color(red: 0.04, green: 0.06, blue: 0.14)
                        .opacity(0.95)
                        .shadow(color: .black.opacity(0.3), radius: 12, y: -4)
                )
            }
        }
        .navigationTitle("Ticket #\(currentTicket.id)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(red: 0.04, green: 0.06, blue: 0.14), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let url = GitHubPRLink.url(from: currentTicket.github_pr_url) {
                        Link(destination: url) {
                            Label("Open Pull Request", systemImage: "arrow.up.right.square")
                        }
                    }

                    Button {
                        showNotCompleteWarningAlert = true
                    } label: {
                        Label("Edit Ticket Name", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        if currentTicket.comments.count > 0 {
                            showCommentCantDeleteWarningAlert = true
                        } else {
                            showWarningDeleteAlert = true
                        }
                    } label: {
                        Label("Delete Ticket", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .alert("Function Not Available", isPresented: $showNotCompleteWarningAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This function is not yet available.")
        }
        .alert("Comments Exist", isPresented: $showCommentCantDeleteWarningAlert) {
            Button("I Understand", role: .cancel) { }
        } message: {
            Text("Cannot delete a ticket that still has comments. Please delete all comments first.")
        }
        .alert("Delete Ticket?", isPresented: $showWarningDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                isLoading = true
                Task {
                    await service.deleteTicket(ticketId: currentTicket.id)
                    isLoading = false
                    dismiss()
                }
            }
        } message: {
            Text("This ticket will be permanently deleted.")
        }
        .overlay {
            if isLoading {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView()
                    .tint(Color(red: 0.55, green: 0.4, blue: 1.0))
                    .scaleEffect(1.3)
            }
        }
        .task {
            while !Task.isCancelled {
                await service.refreshTicket(id: ticket.id)
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }
    
    private func commentAuthorLabel(_ comment: Comment) -> String {
        let trimmed = comment.display.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? comment.author_name : trimmed
    }
}

// MARK: - Markdown comment body
private struct CommentMarkdownText: View {
    let text: String
    
    var body: some View {
        Text(attributed)
            .font(.subheadline)
            .tint(Color(red: 0.72, green: 0.78, blue: 1.0))
            .fixedSize(horizontal: false, vertical: true)
    }
    
    private var attributed: AttributedString {
        var parsed: AttributedString
        do {
            parsed = try AttributedString(
                markdown: text,
                options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
            )
        } catch {
            parsed = AttributedString(text)
        }
        parsed.foregroundColor = Color.white.opacity(0.9)
        return parsed
    }
}

// MARK: - App Entry Point
@main
struct TicketingApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
