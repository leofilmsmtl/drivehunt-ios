import SwiftUI

/// Login screen — 1:1 port of Android's LoginScreen.kt
/// Connects to /v1/auth/login, /v1/auth/register, /v1/auth/guest
/// Supports: login, register, guest mode, auto-login, backend URL toggle
struct LoginScreen: View {
    var autoLogin: Bool = false
    var onLoginSuccess: (String, String?, String, String) -> Void  // accessToken, refreshToken, displayName, role

    @State private var email = "julien@leofilms.ca"
    @State private var password = "monopoly3"
    @State private var displayName = ""
    @State private var postalCode = ""
    @State private var rememberMe = true
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isRegisterMode = false
    @State private var passwordVisible = false

    @EnvironmentObject var appState: AppState

    // DriveHunt brand colors
    private let accentGreen = Color(hex: "#00FFAA")
    private let accentBlue = Color(hex: "#00CCFF")

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#0A0A1A"), Color(hex: "#1A1A3E")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    Spacer().frame(height: 40)

                    // ── Logo (iOS-native hexagon — kept from original) ──
                    VStack(spacing: 8) {
                        Image(systemName: "hexagon.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [accentGreen, Color(hex: "#00AAFF")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("P. HEXAGON")
                            .font(.system(size: 28, weight: .bold))
                            .tracking(1)
                            .foregroundColor(.white)

                        Text("GPS Territory Capture Game")
                            .font(.caption)
                            .foregroundColor(Color(hex: "#888888"))
                    }

                    Spacer().frame(height: 8)

                    // Error message
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // ── Glassmorphism Email Input ──
                    glassField(placeholder: "Nom d'utilisateur", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    // ── Glassmorphism Password Input ──
                    HStack {
                        Group {
                            if passwordVisible {
                                TextField("Mot de passe", text: $password)
                            } else {
                                SecureField("Mot de passe", text: $password)
                            }
                        }
                        .foregroundColor(.white)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                        Button(action: { passwordVisible.toggle() }) {
                            Image(systemName: passwordVisible ? "eye" : "eye.slash")
                                .foregroundColor(Color(hex: "#666666"))
                                .frame(width: 20, height: 20)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                    .padding(.horizontal, 32)

                    // ── Backend URL Configuration Card (login mode only) ──
                    if !isRegisterMode {
                        backendConfigCard
                    }

                    // ── Register-only fields ──
                    if isRegisterMode {
                        glassField(placeholder: "Nom d'affichage (Public)", text: $displayName)
                            .autocorrectionDisabled()

                        glassField(placeholder: "Code Postal (optionnel)", text: Binding(
                            get: { postalCode },
                            set: { postalCode = String($0.uppercased().prefix(7)) }
                        ))
                        .autocapitalization(.allCharacters)
                        .autocorrectionDisabled()
                    } else {
                        // Remember me
                        HStack {
                            Button(action: { rememberMe.toggle() }) {
                                Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                                    .foregroundColor(accentGreen)
                            }
                            Text("Se souvenir de moi")
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 32)
                    }

                    // ── Gradient CTA Button ──
                    Button(action: isRegisterMode ? register : login) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView().tint(.black)
                                if autoLogin { Text("Connexion...").foregroundColor(.black).fontWeight(.semibold) }
                            } else {
                                Text(isRegisterMode ? "S'inscrire" : "Se connecter")
                                    .fontWeight(.semibold)
                                    .font(.system(size: 16))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [accentGreen, accentBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.black)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                    .disabled(isLoading)

                    // Toggle register / login
                    Button(isRegisterMode ? "Déjà un compte? Se connecter" : "Créer un compte") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isRegisterMode.toggle()
                            errorMessage = nil
                        }
                    }
                    .foregroundColor(accentGreen)
                    .font(.subheadline)

                    // Divider
                    HStack {
                        Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                        Text("Ou").font(.caption).foregroundColor(Color(hex: "#666666"))
                        Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                    }
                    .padding(.horizontal, 48)
                    .padding(.vertical, 4)

                    // ── Guest Login ──
                    Button(action: guestLogin) {
                        HStack {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Mode Invité")
                                    .fontWeight(.medium)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
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
            // Pre-fill debug credentials (matches Kotlin's BuildConfig.DEBUG)
            #if DEBUG
            if email.isEmpty { email = "julien@leofilms.ca" }
            if password.isEmpty { password = "monopoly3" }
            #endif

            // Auto-login with saved token
            if autoLogin {
                Task { await performAutoLogin() }
            }
        }
    }

    // MARK: - Backend Config Card (matches Kotlin's network config)

    private var backendConfigCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CONFIGURATION RÉSEAU")
                .font(.system(size: 10, weight: .regular))
                .tracking(0.5)
                .foregroundColor(Color(hex: "#888888"))

            HStack {
                Text("Local").foregroundColor(Color(hex: "#CCCCCC")).font(.caption)
                Spacer()
                Toggle("", isOn: $appState.useNgrok)
                    .toggleStyle(SwitchToggleStyle(tint: accentGreen))
                    .labelsHidden()
                Spacer()
                Text("Distant").foregroundColor(Color(hex: "#CCCCCC")).font(.caption)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal, 32)
    }

    // MARK: - Glass Field Helper

    private func glassField(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .foregroundColor(.white)
            .padding()
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
            .padding(.horizontal, 32)
    }

    // MARK: - Auto Login (matches Kotlin's LaunchedEffect(autoLogin))

    private func performAutoLogin() async {
        await MainActor.run { isLoading = true }

        guard let token = AuthManager.shared.getAccessToken() else {
            await MainActor.run {
                isLoading = false
                errorMessage = "Session expirée, veuillez vous reconnecter"
            }
            return
        }

        // Check expiry and refresh if needed
        if AuthManager.shared.isTokenExpired(token) {
            let refreshed = await AuthManager.shared.refreshAccessToken(baseUrl: appState.backendBaseUrl)
            guard refreshed, let newToken = AuthManager.shared.getAccessToken() else {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Session expirée, veuillez vous reconnecter"
                }
                return
            }
            let refresh = AuthManager.shared.getRefreshToken()
            let displayName = AuthManager.shared.getDisplayNameFromToken(newToken)
            let role = AuthManager.shared.getUserRole() ?? "user"
            await MainActor.run { onLoginSuccess(newToken, refresh, displayName, role) }
        } else {
            let refresh = AuthManager.shared.getRefreshToken()
            let displayName = AuthManager.shared.getDisplayNameFromToken(token)
            let role = AuthManager.shared.getUserRole() ?? "user"
            await MainActor.run { onLoginSuccess(token, refresh, displayName, role) }
        }
    }

    // MARK: - Login

    private func login() {
        guard !email.isEmpty else {
            errorMessage = "Veuillez entrer une adresse email valide."
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Le mot de passe doit contenir au moins 6 caractères."
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await performAuthRequest(
                    endpoint: "/v1/auth/login",
                    body: ["email": email, "password": password, "rememberMe": rememberMe]
                )
                await MainActor.run {
                    isLoading = false
                    onLoginSuccess(result.token, result.refresh, result.displayName ?? email.split(separator: "@").first.map(String.init) ?? "Joueur", result.role)
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
                    "email": email,
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
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 {
                    await MainActor.run {
                        isLoading = false
                        isRegisterMode = false
                        errorMessage = "Compte créé! Vérifiez vos courriels (simulé)."
                    }
                } else {
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw AuthError.message("Pas de réponse")
                    }
                    let msg = parseErrorResponse(data: data, code: httpResponse.statusCode)
                    throw AuthError.message(msg)
                }
            } catch let error as AuthError {
                await MainActor.run { isLoading = false; errorMessage = error.message }
            } catch {
                await MainActor.run { isLoading = false; errorMessage = error.localizedDescription }
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
                    onLoginSuccess(result.token, result.refresh, result.displayName ?? "Invité", result.role)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Network Helpers

    struct AuthResult {
        let token: String
        let refresh: String?
        let displayName: String?
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

    private func performAuthRequest(endpoint: String, body: [String: Any]) async throws -> AuthResult {
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
        let refreshToken = json["refreshToken"] as? String ?? json["refresh_token"] as? String

        guard let token = accessToken else {
            throw AuthError.message("Réponse invalide — pas de token")
        }

        let user = json["user"] as? [String: Any]
        let name = user?["displayName"] as? String
        let role = user?["role"] as? String ?? json["role"] as? String ?? "user"

        return AuthResult(token: token, refresh: refreshToken, displayName: name, role: role)
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
