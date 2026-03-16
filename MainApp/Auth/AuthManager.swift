import Foundation
import Security

/// Secure JWT token storage using iOS Keychain.
/// Equivalent of Android's EncryptedSharedPreferences in AppNavigation.kt.
///
/// The Keychain persists across app updates and is hardware-encrypted,
/// making it the iOS equivalent of Android's EncryptedSharedPreferences.
final class AuthManager {
    static let shared = AuthManager()

    private let service = "com.geocachecar.drivehunt"
    private let accessTokenKey = "access_token"
    private let refreshTokenKey = "refresh_token"
    private let userRoleKey = "user_role"

    private init() {
        // CRITICAL: iOS Keychain survives app reinstalls!
        // UserDefaults is cleared on reinstall, so we use it to detect first launch.
        let hasLaunchedKey = "hasLaunchedBefore"
        if !UserDefaults.standard.bool(forKey: hasLaunchedKey) {
            // First launch (or reinstall) — clear any stale tokens
            logout()
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
            print("🔒 AuthManager: First launch — cleared stale Keychain tokens")
        }
    }

    // MARK: - Token Storage

    func saveTokens(access: String, refresh: String, role: String) {
        save(key: accessTokenKey, value: access)
        save(key: refreshTokenKey, value: refresh)
        save(key: userRoleKey, value: role)
        print("🔐 AuthManager: Tokens saved to Keychain")
    }

    func getAccessToken() -> String? {
        return load(key: accessTokenKey)
    }

    func getRefreshToken() -> String? {
        return load(key: refreshTokenKey)
    }

    func getUserRole() -> String? {
        return load(key: userRoleKey)
    }

    func logout() {
        delete(key: accessTokenKey)
        delete(key: refreshTokenKey)
        delete(key: userRoleKey)
        print("🔒 AuthManager: All tokens cleared from Keychain")
    }

    /// Server-side logout — invalidate refresh token (fire-and-forget)
    /// Matches Kotlin performLogout() server call
    func serverLogout(baseUrl: String) {
        guard let refreshToken = getRefreshToken(),
              let url = URL(string: "\(baseUrl)/v1/auth/logout") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 3
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["refreshToken": refreshToken])

        URLSession.shared.dataTask(with: request) { _, response, error in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 200 {
                print("🔒 AuthManager: Server-side refresh token invalidated")
            } else {
                print("⚠️ AuthManager: Server logout failed (HTTP \(code)) — \(error?.localizedDescription ?? "offline?")")
            }
        }.resume()
    }

    // MARK: - JWT Helpers

    /// Check if a JWT token is expired (with 10-minute buffer, like Android)
    func isTokenExpired(_ token: String) -> Bool {
        guard let payload = decodeJWTPayload(token),
              let exp = payload["exp"] as? TimeInterval else {
            return true
        }
        // Refresh 10 minutes BEFORE expiry (matches Android: exp - 600)
        return Date().timeIntervalSince1970 > (exp - 600)
    }

    /// Extract player_id (sub) from JWT token
    func getPlayerIdFromToken(_ token: String) -> String? {
        guard let payload = decodeJWTPayload(token),
              let sub = payload["sub"] as? String, !sub.isEmpty else {
            return nil
        }
        return sub
    }

    /// Extract display name from JWT (email prefix) — matches Kotlin's JWT decode in LoginScreen
    func getDisplayNameFromToken(_ token: String) -> String {
        guard let payload = decodeJWTPayload(token),
              let email = payload["email"] as? String else {
            return "Joueur"
        }
        return email.split(separator: "@").first.map(String.init) ?? "Joueur"
    }

    /// Refresh the access token using the stored refresh token
    func refreshAccessToken(baseUrl: String) async -> Bool {
        guard let refreshToken = getRefreshToken() else {
            print("❌ AuthManager: No refresh token available")
            return false
        }

        let urlString = "\(baseUrl)/v1/auth/refresh"
        guard let url = URL(string: urlString) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")

        let body = ["refreshToken": refreshToken]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ AuthManager: Refresh failed — HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                return false
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let newAccess = json["accessToken"] as? String, !newAccess.isEmpty else {
                return false
            }

            let newRefresh = json["refreshToken"] as? String ?? refreshToken
            let role = json["role"] as? String ?? "USER"

            saveTokens(access: newAccess, refresh: newRefresh, role: role)
            print("✅ AuthManager: Token refreshed successfully")
            return true
        } catch {
            print("❌ AuthManager: Refresh exception — \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - JWT Decode

    private func decodeJWTPayload(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        var base64 = String(parts[1])
        // Pad Base64 string
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }

    // MARK: - Keychain Helpers

    private func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        delete(key: key) // Remove existing value first

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
