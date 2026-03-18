// FortressModels.swift — Fortress data models + API state
// 1:1 port of Android FortressModels.kt + SnapshotClient fortress API
import Foundation
import SwiftUI

// MARK: - Data Models (mirrors FortressModels.kt)

struct FortressHex: Codable, Identifiable {
    var id: String { h3Index }
    let h3Index: String
    let role: String

    enum CodingKeys: String, CodingKey {
        case h3Index = "h3_index"
        case role
    }
}

struct Fortress: Codable {
    let id: String
    let ownerId: String
    let ownerName: String?
    let ownerColor: String?
    let tier: Int
    let centerLat: Double
    let centerLon: Double
    let skinId: String
    let status: String
    let hexes: [FortressHex]
    let createdAt: String?
    let breachedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case ownerName = "owner_name"
        case ownerColor = "owner_color"
        case tier
        case centerLat = "center_lat"
        case centerLon = "center_lon"
        case skinId = "skin_id"
        case status, hexes
        case createdAt = "created_at"
        case breachedAt = "breached_at"
    }
}

struct ClusterCenter: Codable {
    let lat: Double
    let lon: Double
}

struct FortressCluster: Codable, Identifiable {
    var id: String { "\(center.lat),\(center.lon)" }
    let hexes: [ClusterHex]
    let center: ClusterCenter
    let tier: Int
}

struct ClusterHex: Codable, Identifiable {
    var id: String { h3Index }
    let h3Index: String
    let role: String
}

// MARK: - FortressState (mirrors SnapshotClient fortress API)

class FortressState: ObservableObject {
    static let shared = FortressState()

    @Published var fortress: Fortress?
    @Published var clusters: [FortressCluster] = []
    @Published var isLoading = false
    @Published var isBuilding = false
    @Published var isDestroying = false

    private init() {}

    // GET /v1/fortress/mine
    func fetchMyFortress() async {
        guard let token = AuthManager.shared.getAccessToken() else { return }
        let base = AppState.shared.backendBaseUrl

        guard let url = URL(string: "\(base)/v1/fortress/mine") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        req.timeoutInterval = 5

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fortressJson = json["fortress"] as? [String: Any] {
                let fortressData = try JSONSerialization.data(withJSONObject: fortressJson)
                let decoded = try JSONDecoder().decode(Fortress.self, from: fortressData)
                await MainActor.run { self.fortress = decoded }
            }
        } catch {
            print("❌ Fetch fortress error: \(error.localizedDescription)")
        }
    }

    // GET /v1/fortress/clusters?tier=N
    func fetchClusters(tier: Int = 1) async {
        guard let token = AuthManager.shared.getAccessToken() else { return }
        let base = AppState.shared.backendBaseUrl

        guard let url = URL(string: "\(base)/v1/fortress/clusters?tier=\(tier)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        req.timeoutInterval = 5

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let clustersArr = json["clusters"] as? [[String: Any]] {
                let clustersData = try JSONSerialization.data(withJSONObject: clustersArr)
                let decoded = try JSONDecoder().decode([FortressCluster].self, from: clustersData)
                await MainActor.run { self.clusters = decoded }
            }
        } catch {
            print("❌ Fetch clusters error: \(error.localizedDescription)")
        }
    }

    // POST /v1/fortress/build
    func buildFortress(hexIndices: [String], tier: Int = 1) async -> Bool {
        guard let token = AuthManager.shared.getAccessToken() else { return false }
        let base = AppState.shared.backendBaseUrl

        guard let url = URL(string: "\(base)/v1/fortress/build") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        req.timeoutInterval = 10

        let payload: [String: Any] = ["hexIndices": hexIndices, "tier": tier]
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fortressJson = json["fortress"] as? [String: Any] {
                let fortressData = try JSONSerialization.data(withJSONObject: fortressJson)
                let decoded = try JSONDecoder().decode(Fortress.self, from: fortressData)
                await MainActor.run {
                    self.fortress = decoded
                    self.clusters = []
                }
                // Tell Unity to refresh fortress 3D model
                UnityBridge.shared.send("RefreshFortress", value: "")
                return true
            }
            return false
        } catch {
            print("❌ Build fortress error: \(error.localizedDescription)")
            return false
        }
    }

    // DELETE /v1/fortress/mine
    func destroyFortress() async -> Bool {
        guard let token = AuthManager.shared.getAccessToken() else { return false }
        let base = AppState.shared.backendBaseUrl

        guard let url = URL(string: "\(base)/v1/fortress/mine") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        req.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
            await MainActor.run { self.fortress = nil }
            // Tell Unity to clear fortress visuals
            UnityBridge.shared.send("ClearFortresses", value: "")
            return true
        } catch {
            print("❌ Destroy fortress error: \(error.localizedDescription)")
            return false
        }
    }

    // Load initial data
    func loadData() async {
        await MainActor.run { isLoading = true }
        await fetchMyFortress()
        if fortress == nil {
            await fetchClusters()
        }
        await MainActor.run { isLoading = false }
    }
}
