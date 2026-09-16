//
//  login_home.swift
//  lyra-ios
//
//  Created by Lyrindra Labs on 12/6/2026.
//
import SwiftUI
internal import Combine

// MARK: - Models (unchanged)
struct User: Codable {
    let id: Int
    let email: String
    let password: String
}

struct LoginResponse: Codable {
    let success: Bool
    let token: String?
    let message: String?
    let user: User?
}

// MARK: - ViewModel (light cleanup only)
@Observable
final class loginViewModel {
    var email = ""
    var loginPassword = ""
    var createPassword = ""
    var errorMessage: String? = nil
    var loginResponse: LoginResponse? = nil
    var isLoading = false
    
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    var onLoginSuccess: (() -> Void)? = nil
    
    private let service: TicketService
    
    init(service: TicketService) {
        self.service = service
    }
    
    var showErrorAlert = false
    var showErrorAlertUserDoesntExist = false
    
    func fetchUserExistsViaEmail(email: String, password: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        let baseURL = load_base_url()
        guard let url = URL(string: "\(baseURL)/login") else {
            errorMessage = "Invalid URL."
            return false
        }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body = ["email": email, "password": password]
            request.httpBody = try JSONEncoder().encode(body)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Status Code: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 302 {
                    return true
                }
            }
        } catch {
            print("Err: \(error)")
            errorMessage = error.localizedDescription
        }
        return false
    }
    
    func login() async {
        isLoading = true
        defer { isLoading = false }
        
        let userExists = await fetchUserExistsViaEmail(email: email, password: loginPassword)
        
        if userExists {
            onLoginSuccess?()
        } else {
            showErrorAlertUserDoesntExist = true
        }
    }
}

// MARK: - Redesigned LoginView
struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @State private var viewModel: loginViewModel
    @State private var isCreatingNewAccount = false
    @State private var showLoginPassword = false
    @State private var showCreatePassword = false
    
    // Gradient matching the logo
    private let lyraGradient = LinearGradient(
        colors: [
            Color(red: 0.65, green: 0.25, blue: 0.95),   // purple
            Color(red: 0.25, green: 0.55, blue: 1.0)     // cyan-blue
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    init(service: TicketService, isLoggedIn: Binding<Bool>) {
        self._viewModel = State(wrappedValue: loginViewModel(service: service))
        self._isLoggedIn = isLoggedIn
        
        viewModel.onLoginSuccess = {
            isLoggedIn.wrappedValue = true
        }
    }
    
    var body: some View {
        ZStack {
            // Deep space background
            Color(red: 0.04, green: 0.06, blue: 0.14)
                .ignoresSafeArea()
            
            // Subtle network dots (very light)
            NetworkBackground()
                .opacity(0.35)
                .ignoresSafeArea()
            
            if !isCreatingNewAccount {
                loginContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            } else {
                createAccountContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: isCreatingNewAccount)
        .alert("Login Error", isPresented: $viewModel.showErrorAlert) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
        .alert("User Doesn't Exist", isPresented: $viewModel.showErrorAlertUserDoesntExist) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "You don't seem to have an account. Consider creating one below.")
        }
    }
    
    // MARK: - Login Content
    private var loginContent: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Logo + Title
            VStack(spacing: 16) {
                // Placeholder for your actual logo image
                // Replace with: Image("lyra-logo") or the asset name
                ZStack {
                    // Soft glow behind logo
                    Circle()
                        .fill(lyraGradient.opacity(0.25))
                        .frame(width: 110, height: 110)
                        .blur(radius: 24)
                    
                    // If you have the logo asset, use:
                    // Image("lyra-logo")
                    //     .resizable()
                    //     .scaledToFit()
                    //     .frame(width: 90, height: 90)
                    
                    // Temporary stylized L until you drop the asset in
                    Text("L")
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .foregroundStyle(lyraGradient)
                        .shadow(color: Color(red: 0.4, green: 0.3, blue: 1.0).opacity(0.7), radius: 12)
                }
                
                Text("Welcome to Lyra")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("Secure. Connected. Seamless.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.bottom, 48)
            
            // Form Card
            VStack(spacing: 20) {
                // Email
                modernTextField(
                    placeholder: "Email",
                    text: $viewModel.email,
                    isSecure: false,
                    contentType: .emailAddress
                )
                
                // Password
                modernPasswordField(
                    placeholder: "Password",
                    text: $viewModel.loginPassword,
                    isVisible: $showLoginPassword
                )
                
                // Login Button
                Button {
                    Task { await viewModel.login() }
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(viewModel.isLoading ? "Signing in..." : "Sign In")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(lyraGradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color(red: 0.4, green: 0.3, blue: 1.0).opacity(0.45), radius: 16, y: 8)
                }
                .disabled(viewModel.isLoading)
                .padding(.top, 8)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 24)
            
            // Create Account link
            Button {
                withAnimation { isCreatingNewAccount = true }
            } label: {
                Text("Create New Account")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(lyraGradient)
            }
            .padding(.top, 28)
            
            Spacer()
            Spacer()
        }
    }
    
    // MARK: - Create Account Content
    private var createAccountContent: some View {
        VStack(spacing: 0) {
            // Back button
            HStack {
                Button {
                    withAnimation { isCreatingNewAccount = false }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(12)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            Spacer()
            
            VStack(spacing: 16) {
                Text("Create Account")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("Join the network")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.bottom, 40)
            
            VStack(spacing: 20) {
                modernTextField(
                    placeholder: "Email",
                    text: $viewModel.email,
                    isSecure: false,
                    contentType: .emailAddress
                )
                
                modernPasswordField(
                    placeholder: "Password",
                    text: $viewModel.createPassword,
                    isVisible: $showCreatePassword
                )
                
                Button {
                    // TODO: call create account function
                } label: {
                    Text("Create Account")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(lyraGradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color(red: 0.4, green: 0.3, blue: 1.0).opacity(0.45), radius: 16, y: 8)
                }
                .padding(.top, 8)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 24)
            
            Spacer()
            Spacer()
        }
    }
    
    // MARK: - Reusable Components
    private func modernTextField(
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool,
        contentType: UITextContentType
    ) -> some View {
        TextField(placeholder, text: text)
            .textContentType(contentType)
            .autocapitalization(.none)
            .keyboardType(contentType == .emailAddress ? .emailAddress : .default)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .foregroundStyle(.white)
            .tint(Color(red: 0.5, green: 0.4, blue: 1.0))
    }
    
    private func modernPasswordField(
        placeholder: String,
        text: Binding<String>,
        isVisible: Binding<Bool>
    ) -> some View {
        HStack {
            Group {
                if isVisible.wrappedValue {
                    TextField(placeholder, text: text)
                } else {
                    SecureField(placeholder, text: text)
                }
            }
            .textContentType(.password)
            .autocapitalization(.none)
            .foregroundStyle(.white)
            .tint(Color(red: 0.5, green: 0.4, blue: 1.0))
            
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isVisible.wrappedValue.toggle()
                }
            } label: {
                Image(systemName: isVisible.wrappedValue ? "eye.slash.fill" : "eye.fill")
                    .foregroundStyle(.white.opacity(0.45))
                    .font(.system(size: 16))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Subtle Network Background
private struct NetworkBackground: View {
    var body: some View {
        Canvas { context, size in
            let dots: [(CGFloat, CGFloat)] = [
                (0.1, 0.15), (0.25, 0.08), (0.4, 0.22), (0.7, 0.12),
                (0.85, 0.3), (0.15, 0.45), (0.55, 0.4), (0.9, 0.55),
                (0.3, 0.7), (0.65, 0.75), (0.1, 0.85), (0.8, 0.9)
            ]
            
            for (x, y) in dots {
                let point = CGPoint(x: x * size.width, y: y * size.height)
                context.fill(
                    Path(ellipseIn: CGRect(x: point.x - 1.5, y: point.y - 1.5, width: 3, height: 3)),
                    with: .color(.white.opacity(0.25))
                )
            }
        }
    }
}

#Preview {
    LoginView(service: TicketService(), isLoggedIn: .constant(false))
}
