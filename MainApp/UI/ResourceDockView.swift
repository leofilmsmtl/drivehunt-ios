import SwiftUI

// MARK: - v5.1 Gem Tier Model
// 5 linear tiers — gem type IS the rarity. No common/rare/epic.
// Matches backend game.defaults.js v5.1

/// Gem tier info (name, color, emoji, cap)
struct GemTier {
    let key: String
    let label: String
    let emoji: String
    let color: Color
    let cap: Int  // 0 = Infinity
}

let gemTiers: [GemTier] = [
    GemTier(key: "quartz",  label: "Quartz",  emoji: "⬜", color: Color(hex: "#D9D2C0"), cap: 30),
    GemTier(key: "jade",    label: "Jade",    emoji: "💚", color: Color(hex: "#2DBF73"), cap: 12),
    GemTier(key: "saphir",  label: "Saphir",  emoji: "💙", color: Color(hex: "#2659F2"), cap: 5),
    GemTier(key: "ruby",    label: "Ruby",    emoji: "❤️‍🔥", color: Color(hex: "#E61A26"), cap: 3),
    GemTier(key: "arcane",  label: "Arcane",  emoji: "💜", color: Color(hex: "#B333F2"), cap: 0),  // 0 = ∞
]

// MARK: - Gem Inventory State

/// v5.1 inventory: 5 gem tiers, flat counts.
/// API response: { "quartz": 10, "jade": 5, "saphir": 2, "ruby": 1, "arcane": 0 }
class GemInventoryState: ObservableObject {
    static let shared = GemInventoryState()

    @Published var quartz: Int = 0
    @Published var jade: Int = 0
    @Published var saphir: Int = 0
    @Published var ruby: Int = 0
    @Published var arcane: Int = 0

    /// Get count by tier key
    func count(for key: String) -> Int {
        switch key {
        case "quartz": return quartz
        case "jade": return jade
        case "saphir": return saphir
        case "ruby": return ruby
        case "arcane": return arcane
        default: return 0
        }
    }

    /// Update from API JSON response
    /// API format: { "success": true, "data": { "quartz": N, "jade": N, ... } }
    /// OR flat: { "quartz": N, "jade": N, ... }
    func update(from json: [String: Any]) {
        let data: [String: Any]
        if let d = json["data"] as? [String: Any] {
            data = d
        } else {
            data = json
        }

        quartz  = data["quartz"] as? Int ?? 0
        jade    = data["jade"]   as? Int ?? 0
        saphir  = data["saphir"] as? Int ?? 0
        ruby    = data["ruby"]   as? Int ?? 0
        arcane  = data["arcane"] as? Int ?? 0
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
                print("💎 ResourceDock: Inventory loaded — quartz=\(self.quartz) jade=\(self.jade) saphir=\(self.saphir) ruby=\(self.ruby) arcane=\(self.arcane)")
            }
        }.resume()
    }

    /// Reset all inventory — called on logout
    func reset() {
        quartz = 0; jade = 0; saphir = 0; ruby = 0; arcane = 0
        print("💎 GemInventoryState: Reset")
    }
}

// MARK: - Resource Dock View

/// v5.1 Resource dock — shows 5 gem tiers with counts + caps.
/// Tapping toggles the expanded detail panel.
struct ResourceDockView: View {
    @ObservedObject var inventory = GemInventoryState.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var expanded = false

    private let glassBg = Color(hex: "#0A0A0A").opacity(0.85) // Unused soon
    private var accentColor: Color { ThemeManager.shared.colors.primary }

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            // === COMPACT DOCK (always visible) ===
            Button {
                withAnimation(.spring(response: 0.3)) { expanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    ForEach(gemTiers, id: \.key) { tier in
                        gemChip(tier: tier, count: inventory.count(for: tier.key))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [ThemeManager.shared.colors.surfaceVariant.opacity(0.85), ThemeManager.shared.colors.surface.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(ThemeManager.shared.colors.primary.opacity(0.3), lineWidth: 1)
                        )
                )
                .shadow(color: ThemeManager.shared.colors.primary.opacity(0.2), radius: 8)
            }

            // === EXPANDED DETAIL PANEL ===
            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    // Header
                    Text("INVENTAIRE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)

                    // Column headers
                    HStack {
                        Text("Gemme")
                            .frame(width: 80, alignment: .leading)
                            .font(.system(size: 10))
                            .foregroundColor(ThemeManager.shared.colors.textSecondary)
                        Spacer()
                        Text("Qté")
                            .frame(width: 36)
                            .font(.system(size: 10))
                            .foregroundColor(ThemeManager.shared.colors.textSecondary)
                        Text("Max")
                            .frame(width: 36)
                            .font(.system(size: 10))
                            .foregroundColor(ThemeManager.shared.colors.textSecondary)
                    }

                    // Rows per gem tier
                    ForEach(gemTiers, id: \.key) { tier in
                        let count = inventory.count(for: tier.key)
                        let capText = tier.cap == 0 ? "∞" : "\(tier.cap)"
                        let atCap = tier.cap > 0 && count >= tier.cap

                        HStack {
                            Text("\(tier.emoji) \(tier.label)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(ThemeManager.shared.colors.textPrimary)
                                .frame(width: 80, alignment: .leading)
                            Spacer()
                            Text("\(count)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(atCap ? Color(hex: "#FF6B6B") : ThemeManager.shared.colors.textPrimary)
                                .frame(width: 36)
                            Text(capText)
                                .font(.system(size: 12))
                                .foregroundColor(ThemeManager.shared.colors.textSecondary.opacity(0.6))
                                .frame(width: 36)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(tier.color.opacity(0.1))
                        )
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [ThemeManager.shared.colors.surface.opacity(0.95), ThemeManager.shared.colors.surfaceVariant.opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(ThemeManager.shared.colors.primary.opacity(0.2), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.5), radius: 12)
                .padding(.top, 32)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .allowsHitTesting(false)  // Panel is read-only, let touches pass to Unity
            }
        }
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        // When ANY touch passes through to Unity, dismiss the expanded panel
        .onReceive(NotificationCenter.default.publisher(for: PassthroughView.touchPassedThrough)) { _ in
            if expanded {
                withAnimation(.spring(response: 0.3)) { expanded = false }
            }
        }
    }

    // MARK: - Components

    private func gemChip(tier: GemTier, count: Int) -> some View {
        HStack(spacing: 2) {
            Circle()
                .fill(tier.color)
                .frame(width: 14, height: 14)
            Text("\(count)")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(ThemeManager.shared.colors.textPrimary)
        }
    }
}
