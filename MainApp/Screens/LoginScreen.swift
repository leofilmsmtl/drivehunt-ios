import SwiftUI

/// Login screen — equivalent of Android's LoginScreen.kt
/// Connects to the backend's /v1/auth/login endpoint.
struct LoginScreen: View {
    var onLoginSuccess: (String, String, String) -> Void

    @State private var username = "julien@leofilms.ca"
    @State private var password = "monopoly3"
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showRegister = false

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

            VStack(spacing: 30) {
                Spacer()

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

                // Input Fields
                VStack(spacing: 16) {
                    TextField("Nom d'utilisateur", text: $username)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    SecureField("Mot de passe", text: $password)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 32)

                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                // Login Button
                Button(action: login) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text("Se connecter")
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
                .disabled(isLoading || username.isEmpty || password.isEmpty)
                .opacity(username.isEmpty || password.isEmpty ? 0.5 : 1)

                // Register link
                Button("Créer un compte") {
                    showRegister = true
                }
                .foregroundColor(Color(hex: "#00FFAA"))
                .font(.subheadline)

                Spacer()
                Spacer()
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

    // MARK: - Network

    private func login() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let baseUrl = appState.backendBaseUrl
                guard let url = URL(string: "\(baseUrl)/v1/auth/login") else {
                    throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "URL invalide"])
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.timeoutInterval = 10
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")

                let body: [String: String] = ["email": username, "password": password]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Pas de réponse"])
                }

                guard httpResponse.statusCode == 200 else {
                    let errorBody = String(data: data, encoding: .utf8) ?? ""
                    throw NSError(domain: "", code: httpResponse.statusCode,
                                  userInfo: [NSLocalizedDescriptionKey: "Erreur \(httpResponse.statusCode): \(errorBody)"])
                }

                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    let rawBody = String(data: data, encoding: .utf8) ?? "no body"
                    print("❌ Login: Failed to parse JSON: \(rawBody)")
                    throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Réponse invalide"])
                }

                print("✅ Login response keys: \(json.keys.sorted())")

                let accessToken = json["accessToken"] as? String ?? json["access_token"] as? String ?? json["token"] as? String
                let refreshToken = json["refreshToken"] as? String ?? json["refresh_token"] as? String ?? ""

                guard let token = accessToken else {
                    print("❌ Login: No token in response: \(json)")
                    throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Réponse invalide — pas de token"])
                }

                let role = json["role"] as? String ?? "USER"

                await MainActor.run {
                    isLoading = false
                    onLoginSuccess(token, refreshToken ?? "", role)
                }

            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

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
}
