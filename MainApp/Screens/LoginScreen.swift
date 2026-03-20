import SwiftUI
import AuthenticationServices

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
    @State private var showVerification = false
    @State private var showRestoreDialog = false
    @State private var restoreDaysRemaining = 0

    @EnvironmentObject var appState: AppState

    // DriveHunt brand colors — from ThemeManager tokens
    private var theme: ThemeManager { ThemeManager.shared }
    private var accentGreen: Color { theme.colors.accent }
    private var accentBlue: Color { theme.colors.secondary }

    var body: some View {
        ZStack {
            theme.colors.backgroundGradient
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
                            .foregroundColor(theme.colors.textPrimary)

                        Text("GPS Territory Capture Game")
                            .font(.caption)
                            .foregroundColor(theme.colors.textMuted)
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
                        .foregroundColor(theme.colors.textPrimary)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                        Button(action: { passwordVisible.toggle() }) {
                            Image(systemName: passwordVisible ? "eye" : "eye.slash")
                                .foregroundColor(theme.colors.textMuted)
                                .frame(width: 20, height: 20)
                        }
                    }
                    .padding()
                    .background(theme.colors.textPrimary.opacity(0.08))
                    .cornerRadius(12)
                    .padding(.horizontal, 32)


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
                                    .foregroundColor(theme.colors.textPrimary.opacity(0.9))
                            }
                            Text("Se souvenir de moi")
                                .foregroundColor(theme.colors.textPrimary.opacity(0.8))
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
                                Text(isRegisterMode ? "S'INSCRIRE" : "SE CONNECTER")
                                    .fontWeight(.bold)
                                    .font(.system(size: 15))
                                    .tracking(1)
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
                    .disabled(isLoading)

                    // Toggle register / login
                    Button(isRegisterMode ? "Déjà un compte? Se connecter" : "Créer un compte") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isRegisterMode.toggle()
                            errorMessage = nil
                        }
                    }
                    .foregroundColor(theme.colors.textPrimary.opacity(0.7))
                    .font(.subheadline)

                    // ── Separator ──
                    HStack {
                        Rectangle().fill(theme.colors.textPrimary.opacity(0.1)).frame(height: 1)
                        Text("Ou").font(.caption).foregroundColor(theme.colors.textMuted)
                        Rectangle().fill(theme.colors.textPrimary.opacity(0.1)).frame(height: 1)
                    }
                    .padding(.horizontal, 48)
                    .padding(.vertical, 4)

                    // ══════════════════════════════════════════════
                    // SOCIAL SIGN-IN (Apple + Google)
                    // ══════════════════════════════════════════════

                    // Sign in with Apple (native button)
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleAppleSignIn(result: result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .cornerRadius(12)
                    .padding(.horizontal, 32)

                    // Sign in with Google (styled button — SDK pending)
                    Button(action: signInWithGoogle) {
                        HStack(spacing: 10) {
                            // Google "G" logo
                            ZStack {
                                Circle().fill(Color.white).frame(width: 22, height: 22)
                                Text("G")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.red, .yellow, .green, .blue],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            Text("Se connecter avec Google")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)

                    // ── Guest Login (DEBUG only) ──
                    #if DEBUG
                    Button(action: guestLogin) {
                        HStack {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "person.fill.questionmark")
                                Text("Mode Invité (Dev)")
                                    .fontWeight(.medium)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(theme.colors.textPrimary.opacity(0.1))
                        .foregroundColor(theme.colors.textMuted)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                    .disabled(isLoading)
                    #endif

                    Spacer().frame(height: 40)
                }
            }
        }
        // Email verification overlay
        .fullScreenCover(isPresented: $showVerification) {
            EmailVerificationScreen(
                email: email,
                onVerified: { token, refresh, name, role in
                    showVerification = false
                    onLoginSuccess(token, refresh, name, role)
                },
                onBack: { showVerification = false }
            )
        }
        .alert("Compte en cours de suppression", isPresented: $showRestoreDialog) {
            Button("Restaurer le compte", role: .cancel) {
                restoreAccount()
            }
            Button("Laisser supprimé", role: .destructive) {}
        } message: {
            Text("Votre compte est programmé pour être définitivement supprimé dans \(restoreDaysRemaining) jours. Voulez-vous annuler l'opération et récupérer votre compte ?")
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

    // MARK: - Glass Field Helper

    private func glassField(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .foregroundColor(theme.colors.textPrimary)
            .padding()
            .background(theme.colors.textPrimary.opacity(0.08))
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
            let result = await AuthManager.shared.refreshAccessToken(baseUrl: appState.backendBaseUrl)
            guard case .success = result, let newToken = AuthManager.shared.getAccessToken() else {
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
            } catch AuthError.emailNotVerified {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Email non vérifié. Entrez le code."
                    showVerification = true
                }
            } catch AuthError.pendingDeletion(let days) {
                await MainActor.run {
                    isLoading = false
                    restoreDaysRemaining = days
                    showRestoreDialog = true
                }
            } catch let error as AuthError {
                await MainActor.run { isLoading = false; errorMessage = error.message }
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
                        // Navigate to email verification screen
                        showVerification = true
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

    // MARK: - Sign in with Apple

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8) else {
                errorMessage = "Impossible de récupérer le token Apple"
                return
            }

            var fullName: String?
            if let nameComponents = credential.fullName {
                let parts = [nameComponents.givenName, nameComponents.familyName].compactMap { $0 }
                if !parts.isEmpty { fullName = parts.joined(separator: " ") }
            }

            isLoading = true
            errorMessage = nil

            Task {
                do {
                    var body: [String: Any] = [
                        "identityToken": identityToken,
                        "appleUserId": credential.user
                    ]
                    if let name = fullName { body["displayName"] = name }
                    if let email = credential.email { body["email"] = email }

                    let result = try await performAuthRequest(
                        endpoint: "/v1/auth/apple",
                        body: body
                    )
                    await MainActor.run {
                        isLoading = false
                        onLoginSuccess(result.token, result.refresh, result.displayName ?? "Joueur", result.role)
                    }
                } catch {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = error.localizedDescription
                    }
                }
            }

        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = "Connexion Apple échouée"
            }
        }
    }

    // MARK: - Sign in with Google

    private func signInWithGoogle() {
        let baseUrl = appState.backendBaseUrl
        guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow }) else { return }
        
        let manager = GoogleSignInManager.shared
        manager.signIn(baseUrl: baseUrl, from: window) { token, refresh, name, role in
            onLoginSuccess(token, refresh, name, role)
        }
        // Observe errors from GoogleSignInManager
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if let err = manager.errorMessage {
                self.errorMessage = err
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
        case emailNotVerified
        case pendingDeletion(days: Int)
        
        var errorDescription: String? {
            switch self { 
            case .message(let msg): return msg 
            case .emailNotVerified: return "Email non vérifié"
            case .pendingDeletion(let days): return "Ce compte sera supprimé dans \(days) jour(s)."
            }
        }
        var message: String {
            switch self { 
            case .message(let msg): return msg 
            case .emailNotVerified: return "Email non vérifié"
            case .pendingDeletion(let days): return "Suppression en cours (\(days) j restants)"
            }
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
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let codeStr = json["code"] as? String, codeStr == "PENDING_DELETION" {
                let days = json["daysRemaining"] as? Int ?? 30
                throw AuthError.pendingDeletion(days: days)
            }
            let msg = parseErrorResponse(data: data, code: httpResponse.statusCode)
            if httpResponse.statusCode == 403 && (msg.localizedCaseInsensitiveContains("vérifié") || msg.localizedCaseInsensitiveContains("verifi")) {
                throw AuthError.emailNotVerified
            }
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

    // MARK: - Restore Account

    private func restoreAccount() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let baseUrl = appState.backendBaseUrl
                guard let url = URL(string: "\(baseUrl)/v1/auth/restore") else { return }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
                request.httpBody = try? JSONSerialization.data(withJSONObject: ["email": email, "password": password])
                
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    await MainActor.run { login() }
                } else {
                    await MainActor.run {
                        isLoading = false
                        errorMessage = "Échec de la restauration de votre compte."
                    }
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
}
