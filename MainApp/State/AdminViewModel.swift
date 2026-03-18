import SwiftUI
import Combine

// MARK: - Model (mirrors Android's Player data class)

private let SUPERADMIN_EMAIL = "julien@leofilms.ca"

struct AdminPlayer: Identifiable, Equatable {
    let id: String
    var name: String
    var email: String
    var score: Int
    var createdAt: String
    var banned: Bool
    var role: String
    var postalCode: String?
    var homeCity: String?
    var hexColor: String?

    var isSuperAdmin: Bool { email == SUPERADMIN_EMAIL }
}

// MARK: - Admin State

class AdminState: ObservableObject {
    static let shared = AdminState()

    @Published var players: [AdminPlayer] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var discoveryGeoJson: String? = nil

    private init() {}

    // MARK: - Fetch Player Discovery (GET /v1/admin/players/:id/discovery)

    func fetchDiscovery(playerId: String) {
        discoveryGeoJson = nil
        let base = AppState.shared.backendBaseUrl
        guard let url = URL(string: "\(base)/v1/admin/players/\(playerId)/discovery"),
              let token = AuthManager.shared.getAccessToken() else { return }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")

        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let data = data, let json = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self?.discoveryGeoJson = json }
        }.resume()
    }

    // MARK: - Load Players (GET /v1/admin/users)

    func loadPlayers() {
        isLoading = true
        error = nil

        let base = AppState.shared.backendBaseUrl
        guard let url = URL(string: "\(base)/v1/admin/users"),
              let token = AuthManager.shared.getAccessToken() else {
            isLoading = false
            error = "Non authentifié"
            return
        }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")

        URLSession.shared.dataTask(with: req) { [weak self] data, response, err in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let err = err {
                    self?.error = err.localizedDescription
                    return
                }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    self?.error = "Réponse invalide"
                    return
                }
                self?.players = json.map { obj in
                    AdminPlayer(
                        id: obj["id"] as? String ?? "",
                        name: obj["display_name"] as? String ?? "Unknown",
                        email: obj["email"] as? String ?? "",
                        score: obj["score"] as? Int ?? 0,
                        createdAt: obj["created_at"] as? String ?? "",
                        banned: obj["banned"] as? Bool ?? false,
                        role: obj["role"] as? String ?? "USER",
                        postalCode: obj["postal_code"] as? String,
                        homeCity: obj["home_city"] as? String,
                        hexColor: obj["hex_color"] as? String
                    )
                }
            }
        }.resume()
    }

    // MARK: - Create Player (POST /v1/admin/users)

    func createPlayer(email: String, password: String, displayName: String, completion: @escaping (Bool) -> Void) {
        let base = AppState.shared.backendBaseUrl
        guard let url = URL(string: "\(base)/v1/admin/users"),
              let token = AuthManager.shared.getAccessToken() else {
            completion(false)
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")

        let body: [String: Any] = ["email": email, "password": password, "displayName": displayName, "role": "USER"]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] _, response, _ in
            let ok = (response as? HTTPURLResponse)?.statusCode == 201
            DispatchQueue.main.async {
                if ok { self?.loadPlayers() }
                completion(ok)
            }
        }.resume()
    }

    // MARK: - Update Player (PATCH /v1/admin/users/:id)

    func updatePlayer(_ playerId: String, updates: [String: Any], completion: @escaping (Bool) -> Void = { _ in }) {
        let base = AppState.shared.backendBaseUrl
        guard let url = URL(string: "\(base)/v1/admin/users/\(playerId)"),
              let token = AuthManager.shared.getAccessToken() else {
            completion(false)
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        req.httpBody = try? JSONSerialization.data(withJSONObject: updates)

        URLSession.shared.dataTask(with: req) { [weak self] _, response, _ in
            let ok = (response as? HTTPURLResponse)?.statusCode ?? 0 < 300
            DispatchQueue.main.async {
                if ok { self?.loadPlayers() }
                completion(ok)
            }
        }.resume()
    }

    // MARK: - Delete Player (DELETE /v1/admin/users/:id)

    func deletePlayer(_ playerId: String, completion: @escaping (Bool) -> Void = { _ in }) {
        let base = AppState.shared.backendBaseUrl
        guard let url = URL(string: "\(base)/v1/admin/users/\(playerId)"),
              let token = AuthManager.shared.getAccessToken() else {
            completion(false)
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")

        URLSession.shared.dataTask(with: req) { [weak self] _, response, _ in
            let ok = (response as? HTTPURLResponse)?.statusCode ?? 0 < 300
            DispatchQueue.main.async {
                if ok { self?.loadPlayers() }
                completion(ok)
            }
        }.resume()
    }

    // MARK: - Update Password (PATCH /v1/admin/users/:id/password)

    func updatePassword(_ playerId: String, newPassword: String, completion: @escaping (Bool) -> Void = { _ in }) {
        let base = AppState.shared.backendBaseUrl
        guard let url = URL(string: "\(base)/v1/admin/users/\(playerId)/password"),
              let token = AuthManager.shared.getAccessToken() else {
            completion(false)
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["password": newPassword])

        URLSession.shared.dataTask(with: req) { _, response, _ in
            let ok = (response as? HTTPURLResponse)?.statusCode ?? 0 < 300
            DispatchQueue.main.async { completion(ok) }
        }.resume()
    }

    // MARK: - Reset Player (POST /v1/admin/users/:id/reset)

    func resetPlayer(_ playerId: String, options: [String: Bool], completion: @escaping (Bool) -> Void = { _ in }) {
        let base = AppState.shared.backendBaseUrl
        guard let url = URL(string: "\(base)/v1/admin/users/\(playerId)/reset"),
              let token = AuthManager.shared.getAccessToken() else {
            completion(false)
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        req.httpBody = try? JSONSerialization.data(withJSONObject: options)

        URLSession.shared.dataTask(with: req) { [weak self] _, response, _ in
            let ok = (response as? HTTPURLResponse)?.statusCode ?? 0 < 300
            DispatchQueue.main.async {
                if ok { self?.loadPlayers() }
                completion(ok)
            }
        }.resume()
    }
}
