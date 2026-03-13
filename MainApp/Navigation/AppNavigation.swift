import SwiftUI

/// Main navigation controller — equivalent of Android's AppNavigation.kt.
/// Uses NavigationStack with programmatic routing.
struct AppNavigation: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var bridge = UnityBridge.shared
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if appState.isLoggedIn {
                    MapScreen(navigationPath: $navigationPath)
                } else {
                    LoginScreen(onLoginSuccess: handleLoginSuccess)
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .map:
                    MapScreen(navigationPath: $navigationPath)
                case .profile:
                    ProfileScreen(onBack: { navigationPath.removeLast() })
                        .background(Color(hex: "#121212"))
                case .admin:
                    AdminScreen(onBack: { navigationPath.removeLast() })
                        .background(Color(hex: "#121212"))
                case .skinPicker:
                    SkinPickerScreen(onBack: { navigationPath.removeLast() })
                        .background(Color(hex: "#0F0F23"))
                }
            }
        }
        .onChange(of: bridge.isBootComplete) { isComplete in
            if isComplete {
                sendSkinDataToUnity()
            }
        }
        // PERIODIC TOKEN REFRESH — matches Kotlin's UnityEmbedView.kt (lines 119-147)
        // Kotlin: LaunchedEffect { delay(10s); while(true) { delay(30s); check+refresh } }
        // Without this, iOS sessions fail silently after ~50min (token TTL = 1h, buffer = 10min)
        .task {
            // Initial delay — let boot finish
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10s
            print("🔄 AppNavigation: Token refresh timer started")

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // Check every 30s

                guard let currentToken = AuthManager.shared.getAccessToken() else { continue }

                if AuthManager.shared.isTokenExpired(currentToken) {
                    print("🔄 AppNavigation: Token expired/near-expiry — refreshing...")
                    let refreshed = await AuthManager.shared.refreshAccessToken(baseUrl: appState.backendBaseUrl)

                    if refreshed {
                        if let newToken = AuthManager.shared.getAccessToken() {
                            // Send refreshed token to Unity (matches Kotlin's UnitySendMessage("SetAuthToken"))
                            await MainActor.run {
                                UnityBridge.shared.send("SetAuthToken", value: newToken)
                                UnityHolder.shared.lastSentToken = newToken
                            }
                            print("✅ AppNavigation: Token refreshed & sent to Unity (length: \(newToken.count))")
                        }
                    } else {
                        print("❌ AppNavigation: Token refresh failed — backend unreachable?")
                    }
                }
            }
        }
    }

    // MARK: - Login Handler

    private func handleLoginSuccess(accessToken: String, refreshToken: String, role: String) {
        // Save tokens to Keychain
        AuthManager.shared.saveTokens(access: accessToken, refresh: refreshToken, role: role)
        appState.isLoggedIn = true

        // Send auth token to Unity immediately (matches Android's onLoginSuccess)
        if UnityHolder.shared.isInitialized {
            UnityBridge.shared.send("SetAuthToken", value: accessToken)

            // Extract and send player ID from JWT
            if let playerId = AuthManager.shared.getPlayerIdFromToken(accessToken) {
                UnityBridge.shared.send("SetPlayerId", value: playerId)
            }

            // Send refresh token
            UnityBridge.shared.send("SetRefreshToken", value: refreshToken)
            UnityHolder.shared.lastSentToken = accessToken
        }

        // Send backend URL
        UnityBridge.shared.send("SetBackendUrl", value: appState.backendBaseUrl)

        print("🔑 AppNavigation: Login success — tokens saved, auth sent to Unity")
    }

    // MARK: - Skin Sync (matches Android's LaunchedEffect(isBootComplete))

    private func sendSkinDataToUnity() {
        guard let token = AuthManager.shared.getAccessToken() else { return }

        Task {
            await fetchAndApplySkins(token: token, baseUrl: appState.backendBaseUrl)
        }
    }

    private func fetchAndApplySkins(token: String, baseUrl: String) async {
        guard let url = URL(string: "\(baseUrl)/v1/skins/inventory") else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 3

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let equipped = json["equipped"] as? [String: Any],
                  let skins = json["skins"] as? [[String: Any]] else { return }

            let equippedT1 = equipped["t1"] as? String ?? "default_green"
            let equippedT2 = equipped["t2"] as? String
            let equippedT3 = equipped["t3"] as? String

            var t1Color = "#00FF88"
            var t2Texture = ""
            var t3Animation = ""

            for skin in skins {
                let skinId = skin["id"] as? String ?? ""
                if skinId == equippedT1 {
                    t1Color = skin["color"] as? String ?? "#00FF88"
                }
                if let t2 = equippedT2, skinId == t2 {
                    t2Texture = skin["texture"] as? String ?? ""
                }
                if let t3 = equippedT3, skinId == t3 {
                    t3Animation = skin["animation"] as? String ?? ""
                }
            }

            // Send to Unity in the correct order (same as Android):
            // 1. TEXTURE FIRST
            await MainActor.run {
                UnityBridge.shared.send("SetPlayerSkinTexture", value: t2Texture.isEmpty ? "none" : t2Texture)
                // 2. COLOR SECOND (triggers repaint WITH texture already set)
                UnityBridge.shared.send("SetPlayerHexColor", value: t1Color)
                // 3. ANIMATION
                UnityBridge.shared.send("SetPlayerSkinAnimation", value: t3Animation.isEmpty ? "none" : t3Animation)
            }

            print("🎨 AppNavigation: Skins loaded — T1=\(t1Color) T2=\(t2Texture) T3=\(t3Animation)")
        } catch {
            print("⚠️ AppNavigation: Failed to fetch skins — \(error.localizedDescription)")
        }
    }
}

// MARK: - Logout

func performLogout(appState: AppState, navigationPath: inout NavigationPath) {
    print("🔒 LOGOUT: performLogout — clearing session")
    AuthManager.shared.logout()
    UnityBridge.shared.reset()
    UnityBridge.shared.send("OnLogout", value: "")
    navigationPath = NavigationPath()
    appState.isLoggedIn = false
}

// MARK: - Routes

enum AppRoute: Hashable {
    case map
    case profile
    case admin
    case skinPicker
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
