import SwiftUI

// MARK: - Gem Inventory Model

/// Matches Kotlin GemInventory — holds inventory counts per color and rarity
class GemInventoryState: ObservableObject {
    static let shared = GemInventoryState()

    @Published var pierre: Int = 0
    @Published var metal: Int = 0
    @Published var energie: Int = 0
    @Published var cristal: Int = 0
    @Published var artefact: Int = 0

    // Detail breakdown (common/rare/epic per color)
    @Published var pierreCommon: Int = 0
    @Published var pierreRare: Int = 0
    @Published var pierreEpic: Int = 0
    @Published var metalCommon: Int = 0
    @Published var metalRare: Int = 0
    @Published var metalEpic: Int = 0
    @Published var energieCommon: Int = 0
    @Published var energieRare: Int = 0
    @Published var energieEpic: Int = 0
    @Published var cristalCommon: Int = 0
    @Published var cristalRare: Int = 0
    @Published var cristalEpic: Int = 0
    @Published var artefactCommon: Int = 0
    @Published var artefactRare: Int = 0
    @Published var artefactEpic: Int = 0

    /// Update from API JSON response
    /// API format: { "success": true, "data": { "pierre": { "common": N, "rare": N, "epic": N }, ... } }
    func update(from json: [String: Any]) {
        // Handle nested "data" wrapper
        let data: [String: Any]
        if let d = json["data"] as? [String: Any] {
            data = d
        } else {
            data = json  // Fallback: direct format
        }

        func get(_ color: String, _ rarity: String) -> Int {
            return (data[color] as? [String: Any])?[rarity] as? Int ?? 0
        }

        pierre = get("pierre", "common") + get("pierre", "rare") + get("pierre", "epic")
        metal = get("metal", "common") + get("metal", "rare") + get("metal", "epic")
        energie = get("energie", "common") + get("energie", "rare") + get("energie", "epic")
        cristal = get("cristal", "common") + get("cristal", "rare") + get("cristal", "epic")
        artefact = get("artefact", "common") + get("artefact", "rare") + get("artefact", "epic")

        pierreCommon = get("pierre", "common"); pierreRare = get("pierre", "rare"); pierreEpic = get("pierre", "epic")
        metalCommon = get("metal", "common"); metalRare = get("metal", "rare"); metalEpic = get("metal", "epic")
        energieCommon = get("energie", "common"); energieRare = get("energie", "rare"); energieEpic = get("energie", "epic")
        cristalCommon = get("cristal", "common"); cristalRare = get("cristal", "rare"); cristalEpic = get("cristal", "epic")
        artefactCommon = get("artefact", "common"); artefactRare = get("artefact", "rare"); artefactEpic = get("artefact", "epic")
    }

    /// Fetch inventory from backend
    func fetchFromBackend() {
        guard let token = AuthManager.shared.getAccessToken() else {
            print("⚠️ ResourceDock: No auth token")
            return
        }
        let baseUrl = AppState.shared.backendBaseUrl
        guard let url = URL(string: "\(baseUrl)/v2/game/inventory") else { return }

        print("💎 ResourceDock: Fetching \(url)")

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 8

        URLSession.shared.dataTask(with: request) { data, response, error in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"
            print("💎 ResourceDock: HTTP \(code) — \(body.prefix(500))")

            if let error = error {
                print("❌ ResourceDock: \(error.localizedDescription)")
                return
            }

            guard let data = data,
                  code == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("⚠️ ResourceDock: Failed (HTTP \(code))")
                return
            }
            DispatchQueue.main.async {
                self.update(from: json)
                print("💎 ResourceDock: Inventory loaded — pierre=\(self.pierre) metal=\(self.metal) energie=\(self.energie) cristal=\(self.cristal) artefact=\(self.artefact)")
            }
        }.resume()
    }

    /// Reset all inventory — called on logout
    func reset() {
        pierre = 0; metal = 0; energie = 0; cristal = 0; artefact = 0
        pierreCommon = 0; pierreRare = 0; pierreEpic = 0
        metalCommon = 0; metalRare = 0; metalEpic = 0
        energieCommon = 0; energieRare = 0; energieEpic = 0
        cristalCommon = 0; cristalRare = 0; cristalEpic = 0
        artefactCommon = 0; artefactRare = 0; artefactEpic = 0
        print("💎 GemInventoryState: Reset")
    }
}

// MARK: - Gem Color Definitions (matching Unity GemColorMap)

struct GemColorDef {
    let emoji: String
    let color: Color
    let key: String
}

private let gemColors: [GemColorDef] = [
    GemColorDef(emoji: "🟤", color: Color(hex: "#8B5E3C"), key: "pierre"),
    GemColorDef(emoji: "⚪", color: Color(hex: "#C0C5D0"), key: "metal"),
    GemColorDef(emoji: "🔵", color: Color(hex: "#1AC0F2"), key: "energie"),
    GemColorDef(emoji: "🟣", color: Color(hex: "#A633E6"), key: "cristal"),
    GemColorDef(emoji: "🟡", color: Color(hex: "#FFCC1A"), key: "artefact")
]

// MARK: - Resource Dock View

/// Compact resource dock — shows 5 gem colors with total counts.
/// Tapping toggles the expanded detail panel.
/// Matches Kotlin ResourceDock composable.
struct ResourceDockView: View {
    @ObservedObject var inventory = GemInventoryState.shared
    @State private var expanded = false

    private let glassBg = Color(hex: "#0A0A0A").opacity(0.85)
    private let accentColor = Color(hex: "#00FF88")

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            // === COMPACT DOCK (always visible) ===
            Button {
                withAnimation(.spring(response: 0.3)) { expanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    gemChip(color: Color(hex: "#8B5E3C"), count: inventory.pierre)
                    gemChip(color: Color(hex: "#C0C5D0"), count: inventory.metal)
                    gemChip(color: Color(hex: "#1AC0F2"), count: inventory.energie)
                    gemChip(color: Color(hex: "#A633E6"), count: inventory.cristal)
                    gemChip(color: Color(hex: "#FFCC1A"), count: inventory.artefact)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(glassBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(accentColor.opacity(0.3), lineWidth: 1)
                        )
                )
                .shadow(color: accentColor.opacity(0.2), radius: 8)
            }

            // === EXPANDED DETAIL PANEL ===
            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    // Header
                    Text("INVENTAIRE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundColor(.white)

                    // Column headers
                    HStack {
                        Text("").frame(width: 80, alignment: .leading)
                        Text("⚪").font(.system(size: 10)).frame(width: 36)
                        Text("⭐").font(.system(size: 10)).frame(width: 36)
                        Text("💎").font(.system(size: 10)).frame(width: 36)
                    }

                    // Rows per color
                    detailRow("🟤 Pierre", common: inventory.pierreCommon, rare: inventory.pierreRare, epic: inventory.pierreEpic, color: Color(hex: "#8B5E3C"))
                    detailRow("⚪ Métal", common: inventory.metalCommon, rare: inventory.metalRare, epic: inventory.metalEpic, color: Color(hex: "#C0C5D0"))
                    detailRow("🔵 Énergie", common: inventory.energieCommon, rare: inventory.energieRare, epic: inventory.energieEpic, color: Color(hex: "#1AC0F2"))
                    detailRow("🟣 Cristal", common: inventory.cristalCommon, rare: inventory.cristalRare, epic: inventory.cristalEpic, color: Color(hex: "#A633E6"))
                    detailRow("🟡 Artefact", common: inventory.artefactCommon, rare: inventory.artefactRare, epic: inventory.artefactEpic, color: Color(hex: "#FFCC1A"))

                    // Caps reminder
                    Text("Max: 15⚪ / 8⭐ / 3💎 par couleur")
                        .font(.system(size: 8))
                        .foregroundColor(.gray.opacity(0.6))
                        .padding(.top, 4)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "#0A0A0A").opacity(0.95))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(accentColor.opacity(0.2), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.5), radius: 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Components

    private func gemChip(color: Color, count: Int) -> some View {
        HStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 14, height: 14)
            Text("\(count)")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private func detailRow(_ label: String, common: Int, rare: Int, epic: Int, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 80, alignment: .leading)
            Text("\(common)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.gray)
                .frame(width: 36)
            Text("\(rare)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#FFD700"))
                .frame(width: 36)
            Text("\(epic)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "#FF6B6B"))
                .frame(width: 36)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}
