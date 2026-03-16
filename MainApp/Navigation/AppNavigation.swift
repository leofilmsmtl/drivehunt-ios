import SwiftUI

/// Main navigation controller — 1:1 port of Android's AppNavigation.kt.
/// Uses NavigationStack with programmatic routing.
struct AppNavigation: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var bridge = UnityBridge.shared
    @State private var navigationPath = NavigationPath()
    @State private var showWelcome = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            MapScreen(navigationPath: $navigationPath)
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
        // PERIODIC TOKEN REFRESH — matches Kotlin's UnityEmbedView.kt
        .task {
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10s initial delay
            print("🔄 AppNavigation: Token refresh timer started")

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // Every 30s

                guard let currentToken = AuthManager.shared.getAccessToken() else { continue }

                if AuthManager.shared.isTokenExpired(currentToken) {
                    print("🔄 AppNavigation: Token expired/near-expiry — refreshing...")
                    let refreshed = await AuthManager.shared.refreshAccessToken(baseUrl: appState.backendBaseUrl)

                    if refreshed {
                        if let newToken = AuthManager.shared.getAccessToken() {
                            await MainActor.run {
                                UnityBridge.shared.send("SetAuthToken", value: newToken)
                                UnityHolder.shared.lastSentToken = newToken
                            }
                            print("✅ AppNavigation: Token refreshed & sent to Unity")
                        }
                    } else {
                        print("❌ AppNavigation: Token refresh failed")
                    }
                }
            }
        }
        .onAppear {
            // Auto-login check on launch
            if let token = AuthManager.shared.getAccessToken(),
               !AuthManager.shared.isTokenExpired(token) {
                // Has valid token — go straight to welcome/loading
                handleLoginSuccess(
                    accessToken: token,
                    refreshToken: AuthManager.shared.getRefreshToken(),
                    displayName: AuthManager.shared.getDisplayNameFromToken(token),
                    role: AuthManager.shared.getUserRole() ?? "user"
                )
            }
        }
    }

    // MARK: - Login Handler (matches Kotlin's onLoginSuccess)

    private func handleLoginSuccess(accessToken: String, refreshToken: String?, displayName: String, role: String) {
        // LOGIN GUARD: Clean previous session data (prevents cross-account leaks)
        // Matches Kotlin's login guard in AppNavigation.kt
        UserDefaults.standard.removeObject(forKey: "equipped_skins")
        UserDefaults.standard.removeObject(forKey: "capture_prefs")
        UserDefaults.standard.removeObject(forKey: "DriveHunt_prefs")
        UserDefaults.standard.removeObject(forKey: "app_prefs")
        print("🛡️ AppNavigation: Login guard — previous session data cleared")

        // Save new tokens
        AuthManager.shared.saveTokens(
            access: accessToken,
            refresh: refreshToken ?? "",
            role: role
        )
        appState.isLoggedIn = true

        // Send auth token to Unity immediately (matches Kotlin's onLoginSuccess)
        if UnityHolder.shared.isInitialized {
            UnityBridge.shared.send("SetAuthToken", value: accessToken)

            if let playerId = AuthManager.shared.getPlayerIdFromToken(accessToken) {
                UnityBridge.shared.send("SetPlayerId", value: playerId)
            }

            if let refresh = refreshToken {
                UnityBridge.shared.send("SetRefreshToken", value: refresh)
            }

            UnityHolder.shared.lastSentToken = accessToken
        }

        // Send backend URL
        UnityBridge.shared.send("SetBackendUrl", value: appState.backendBaseUrl)

        // WelcomeScreen is now natively shown by NativeCallProxyDelegate upon login
        print("🔑 AppNavigation: Login success — tokens saved, auth sent to Unity")
    }

    // MARK: - Skin Sync (matches Kotlin's LaunchedEffect(isBootComplete))

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

            // Send to Unity in the correct order (same as Kotlin):
            await MainActor.run {
                // 1. TEXTURE FIRST
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

// MARK: - Logout (matches Kotlin's performLogout())

/// Shared logout handler — matches Kotlin's performLogout() exactly:
/// 1. Server-side refresh token invalidation (fire-and-forget)
/// 2. Clear Keychain tokens
/// 3. Clear ALL UserDefaults (prevents cross-account leaks)
/// 4. Send ResetSession to Unity
/// 5. Reset UnityBridge + CaptureState
/// 6. Navigate to login
func performLogout(appState: AppState, navigationPath: inout NavigationPath) {
    print("🔒 LOGOUT: performLogout — clearing session")

    // 1. Server-side refresh token invalidation (fire-and-forget)
    AuthManager.shared.serverLogout(baseUrl: appState.backendBaseUrl)

    // 2. Clear Keychain tokens
    AuthManager.shared.logout()

    // 3. Clear ALL player-specific UserDefaults (matches Kotlin's SharedPreferences clear)
    let prefsToClean = ["equipped_skins", "capture_prefs", "DriveHunt_prefs", "app_prefs"]
    for prefKey in prefsToClean {
        UserDefaults.standard.removeObject(forKey: prefKey)
    }
    print("🧹 All player UserDefaults cleared")

    // 4. Tell Unity to reset session state
    UnityBridge.shared.send("ResetSession", value: "")

    // 5. Reset Swift-side bridge signals + capture state
    UnityBridge.shared.reset()
    CaptureState.shared.reset()

    // 6. Navigate to login, clearing the entire back stack
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
