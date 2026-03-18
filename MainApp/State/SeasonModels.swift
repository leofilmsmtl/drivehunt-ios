import Foundation

// ═══════════════════════════════════════════════════════════════
// Season Quest Data Models — 1:1 copy of Android SeasonModels.kt
// Backend API: GET /v1/season/current
// ═══════════════════════════════════════════════════════════════

struct Season: Codable {
    let id: String
    let name: String
    let startsAt: String
    let endsAt: String
}

struct SeasonQuest: Codable, Identifiable {
    let id: String
    let level: Int
    let type: String           // "free" or "paid"
    let questKey: String
    let title: String
    let description: String?
    let conditionType: String
    let conditionTarget: Int
    let progress: Int
    let isCompleted: Bool
    let completedAt: String?

    init(id: String, level: Int, type: String, questKey: String, title: String,
         description: String?, conditionType: String, conditionTarget: Int,
         progress: Int = 0, isCompleted: Bool = false, completedAt: String? = nil) {
        self.id = id
        self.level = level
        self.type = type
        self.questKey = questKey
        self.title = title
        self.description = description
        self.conditionType = conditionType
        self.conditionTarget = conditionTarget
        self.progress = progress
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }
}

struct SeasonProgress {
    let season: Season?
    let quests: [SeasonQuest]
    let currentLevel: Int
    let hasPremium: Bool
}

// ═══════════════════════════════════════════════════════════════
// SeasonState — ObservableObject singleton
// Mirrors Android SnapshotClient season API calls (L651-785)
// ═══════════════════════════════════════════════════════════════

final class SeasonState: ObservableObject {
    static let shared = SeasonState()

    @Published var progress: SeasonProgress?
    @Published var isLoading = false
    @Published var isEvaluating = false

    private init() {}

    /// GET /v1/season/current — mirrors SnapshotClient.fetchSeasonProgress()
    func fetchProgress() {
        guard let token = AuthManager.shared.getAccessToken() else { return }
        let baseUrl = AppState.shared.backendBaseUrl
        guard let url = URL(string: "\(baseUrl)/v1/season/current") else { return }

        isLoading = true

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        request.timeoutInterval = 8

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                guard let data = data,
                      let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    print("❌ SeasonState: fetch failed — \(error?.localizedDescription ?? "HTTP error")")
                    return
                }

                self?.progress = Self.parseSeasonProgress(data: data)
            }
        }.resume()
    }

    /// POST /v1/season/evaluate — mirrors SnapshotClient.evaluateQuests()
    func evaluateQuests() {
        guard let token = AuthManager.shared.getAccessToken() else { return }
        let baseUrl = AppState.shared.backendBaseUrl
        guard let url = URL(string: "\(baseUrl)/v1/season/evaluate") else { return }

        isEvaluating = true

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isEvaluating = false

                guard let data = data,
                      let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    print("❌ SeasonState: evaluate failed — \(error?.localizedDescription ?? "HTTP error")")
                    return
                }

                self?.progress = Self.parseSeasonProgress(data: data)
                print("✅ SeasonState: quests evaluated")
            }
        }.resume()
    }

    /// POST /v1/season/event — mirrors SnapshotClient.sendSeasonEvent()
    func sendEvent(eventType: String) {
        guard let token = AuthManager.shared.getAccessToken() else { return }
        let baseUrl = AppState.shared.backendBaseUrl
        guard let url = URL(string: "\(baseUrl)/v1/season/event") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5
        request.httpBody = "{\"eventType\":\"\(eventType)\"}".data(using: .utf8)

        URLSession.shared.dataTask(with: request) { _, response, error in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 200 {
                print("✅ SeasonState: event sent: \(eventType)")
            } else {
                print("❌ SeasonState: event failed: \(code)")
            }
        }.resume()
    }

    func reset() {
        progress = nil
        isLoading = false
        isEvaluating = false
    }

    // MARK: - JSON Parsing — mirrors SnapshotClient.parseSeasonProgress()

    private static func parseSeasonProgress(data: Data) -> SeasonProgress? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        // Parse season
        var season: Season? = nil
        if let s = json["season"] as? [String: Any] {
            season = Season(
                id: s["id"] as? String ?? "",
                name: s["name"] as? String ?? "",
                startsAt: s["startsAt"] as? String ?? "",
                endsAt: s["endsAt"] as? String ?? ""
            )
        }

        // Parse quests
        var quests: [SeasonQuest] = []
        if let arr = json["quests"] as? [[String: Any]] {
            for q in arr {
                quests.append(SeasonQuest(
                    id: q["id"] as? String ?? "",
                    level: q["level"] as? Int ?? 0,
                    type: q["type"] as? String ?? "free",
                    questKey: q["questKey"] as? String ?? "",
                    title: q["title"] as? String ?? "",
                    description: q["description"] as? String,
                    conditionType: q["conditionType"] as? String ?? "",
                    conditionTarget: q["conditionTarget"] as? Int ?? 0,
                    progress: q["progress"] as? Int ?? 0,
                    isCompleted: q["isCompleted"] as? Bool ?? false,
                    completedAt: q["completedAt"] as? String
                ))
            }
        }

        return SeasonProgress(
            season: season,
            quests: quests,
            currentLevel: json["currentLevel"] as? Int ?? 0,
            hasPremium: json["hasPremium"] as? Bool ?? false
        )
    }
}
