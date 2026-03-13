import SwiftUI

/// Login screen — equivalent of Android's LoginScreen.kt
/// Connects to the backend's /v1/auth/login endpoint.
/// Supports: login, register (with displayName + postalCode), and guest mode.
struct LoginScreen: View {
    var onLoginSuccess: (String, String, String) -> Void

    @State private var username = "julien@leofilms.ca"
    @State private var password = "monopoly3"
    @State private var displayName = ""
    @State private var postalCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isRegisterMode = false

    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(hex: "#0A0A1A"), Color(hex: "#1A1A3E")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 60)

                    // Logo / Title
                    VStack(spacing: 8) {
                        Image(systemName: "hexagon.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#00FFAA"), Color(hex: "#00AAFF")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("P. HEXAGON")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("GPS Territory Capture Game")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }

                    // Title toggle
                    Text(isRegisterMode ? "Créer un compte" : "Connexion")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "#00FFAA"))

                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Input Fields
                    VStack(spacing: 14) {
                        TextField("Courriel", text: $username)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)

                        SecureField("Mot de passe", text: $password)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .foregroundColor(.white)

                        if isRegisterMode {
                            TextField("Nom d'affichage (public)", text: $displayName)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                                .autocorrectionDisabled()

                            TextField("Code postal (optionnel)", text: $postalCode)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                                .autocapitalization(.allCharacters)
                                .autocorrectionDisabled()
                        }
                    }
                    .padding(.horizontal, 32)

                    // Login / Register Button
                    Button(action: isRegisterMode ? register : login) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Text(isRegisterMode ? "S'inscrire" : "Se connecter")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#00FFAA"), Color(hex: "#00CCFF")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.black)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                    .disabled(isLoading || username.isEmpty || password.isEmpty || (isRegisterMode && displayName.isEmpty))
                    .opacity(username.isEmpty || password.isEmpty ? 0.5 : 1)

                    // Toggle register / login
                    Button(isRegisterMode ? "Déjà un compte? Se connecter" : "Créer un compte") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isRegisterMode.toggle()
                            errorMessage = nil
                        }
                    }
                    .foregroundColor(Color(hex: "#00FFAA"))
                    .font(.subheadline)

                    // Divider
                    HStack {
                        Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)
                        Text("OU").font(.caption).foregroundColor(.gray)
                        Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)
                    }
                    .padding(.horizontal, 48)

                    // Guest Login Button
                    Button(action: guestLogin) {
                        HStack {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "person.badge.clock")
                                    .font(.system(size: 16))
                                Text("Mode Invité")
                                    .fontWeight(.medium)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "#00FFAA").opacity(0.4), lineWidth: 1)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                    .disabled(isLoading)

                    Spacer().frame(height: 40)
                }
            }
        }
        .onAppear {
            // Auto-login if token exists and valid
            if let token = AuthManager.shared.getAccessToken(),
               !AuthManager.shared.isTokenExpired(token) {
                Task { await autoLogin() }
            }
        }
    }

    // MARK: - Login

    private func login() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await performAuthRequest(
                    endpoint: "/v1/auth/login",
                    body: ["email": username, "password": password]
                )
                await MainActor.run {
                    isLoading = false
                    onLoginSuccess(result.token, result.refresh, result.role)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Register

    private func register() {
        guard password.count >= 6 else {
            errorMessage = "Le mot de passe doit contenir au moins 6 caractères."
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                var body: [String: String] = [
                    "email": username,
                    "password": password,
                    "displayName": displayName
                ]
                if !postalCode.isEmpty {
                    body["postalCode"] = postalCode
                }

                let baseUrl = appState.backendBaseUrl
                guard let url = URL(string: "\(baseUrl)/v1/auth/register") else {
                    throw AuthError.message("URL invalide")
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.timeoutInterval = 10
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AuthError.message("Pas de réponse")
                }

                if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                    await MainActor.run {
                        isLoading = false
                        isRegisterMode = false
                        errorMessage = nil
                        // Try to auto-login with the same credentials
                        login()
                    }
                } else {
                    let msg = parseErrorResponse(data: data, code: httpResponse.statusCode)
                    throw AuthError.message(msg)
                }
            } catch let error as AuthError {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.message
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Guest Login

    private func guestLogin() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await performAuthRequest(
                    endpoint: "/v1/auth/guest",
                    body: ["displayName": "Explorateur"]
                )
                await MainActor.run {
                    isLoading = false
                    onLoginSuccess(result.token, result.refresh, result.role)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Auto Login

    private func autoLogin() async {
        guard let token = AuthManager.shared.getAccessToken(),
              let refreshToken = AuthManager.shared.getRefreshToken(),
              let role = AuthManager.shared.getUserRole() else { return }

        if AuthManager.shared.isTokenExpired(token) {
            let refreshed = await AuthManager.shared.refreshAccessToken(
                baseUrl: appState.backendBaseUrl
            )
            if refreshed, let newToken = AuthManager.shared.getAccessToken() {
                await MainActor.run {
                    onLoginSuccess(newToken, refreshToken, role)
                }
            }
        } else {
            await MainActor.run {
                onLoginSuccess(token, refreshToken, role)
            }
        }
    }

    // MARK: - Network Helpers

    struct AuthResult {
        let token: String
        let refresh: String
        let role: String
    }

    enum AuthError: LocalizedError {
        case message(String)
        var errorDescription: String? {
            switch self { case .message(let msg): return msg }
        }
        var message: String {
            switch self { case .message(let msg): return msg }
        }
    }

    private func performAuthRequest(endpoint: String, body: [String: String]) async throws -> AuthResult {
        let baseUrl = appState.backendBaseUrl
        guard let url = URL(string: "\(baseUrl)\(endpoint)") else {
            throw AuthError.message("URL invalide")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.message("Pas de réponse")
        }

        guard httpResponse.statusCode == 200 else {
            let msg = parseErrorResponse(data: data, code: httpResponse.statusCode)
            throw AuthError.message(msg)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AuthError.message("Réponse invalide")
        }

        let accessToken = json["accessToken"] as? String ?? json["access_token"] as? String ?? json["token"] as? String
        let refreshToken = json["refreshToken"] as? String ?? json["refresh_token"] as? String ?? ""

        guard let token = accessToken else {
            throw AuthError.message("Réponse invalide — pas de token")
        }

        let role = json["role"] as? String
            ?? (json["user"] as? [String: Any])?["role"] as? String
            ?? "USER"

        return AuthResult(token: token, refresh: refreshToken, role: role)
    }

    private func parseErrorResponse(data: Data, code: Int) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawMsg = json["message"] as? String ?? json["error"] as? String else {
            return "Erreur serveur (\(code))"
        }

        switch true {
        case rawMsg.localizedCaseInsensitiveContains("Email already in use"):
            return "Cet email est déjà utilisé."
        case rawMsg.localizedCaseInsensitiveContains("Invalid email"):
            return "Format d'email invalide."
        case rawMsg.localizedCaseInsensitiveContains("Password"):
            return "Mot de passe trop court (min 6 caractères)."
        case code == 401:
            return "Identifiants incorrects."
        case code == 409:
            return "Cet utilisateur existe déjà."
        case code == 404:
            return "Serveur introuvable."
        case code == 500:
            return "Erreur interne du serveur."
        default:
            return rawMsg.isEmpty ? "Erreur \(code)" : rawMsg
        }
    }
}
