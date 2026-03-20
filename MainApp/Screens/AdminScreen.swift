import SwiftUI
import MapKit

// MARK: - DriveHunt Brand Tokens (from ThemeManager)
private var accentGreen: Color { ThemeManager.shared.colors.accent }
private var accentBlue: Color { ThemeManager.shared.colors.secondary }
private var bgGradient: LinearGradient { ThemeManager.shared.colors.backgroundGradient }
private var glassBg: Color { ThemeManager.shared.colors.textPrimary.opacity(0.08) }
private var glassStroke: Color { ThemeManager.shared.colors.textPrimary.opacity(0.12) }

// MARK: - Admin Screen (Premium Redesign)

struct AdminScreen: View {
    var onBack: () -> Void

    @StateObject private var state = AdminState.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var selectedTab: AdminTab = .home

    var body: some View {
        ZStack {
            bgGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ──
                adminHeader

                // ── Tab Content ──
                TabView(selection: $selectedTab) {
                    AdminHomeTab(state: state)
                        .tag(AdminTab.home)
                    AdminSimulatorTab()
                        .tag(AdminTab.simulator)
                    AdminLootTab()
                        .tag(AdminTab.loot)
                    AdminPlayersTab(state: state)
                        .tag(AdminTab.players)
                    AdminSettingsTab()
                        .tag(AdminTab.settings)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // ── Bottom Bar ──
                AdminBottomBar(selectedTab: $selectedTab)
            }
        }
        .navigationBarHidden(true)
        .onAppear { state.loadPlayers() }
    }

    private var adminHeader: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(accentGreen)
            }
            Spacer()
            Text("CONSOLE ADMIN")
                .font(.system(size: 18, weight: .bold, design: .serif))
                .tracking(1)
                .foregroundColor(ThemeManager.shared.colors.textPrimary)
            Spacer()
            if state.isLoading {
                ProgressView().tint(accentGreen).scaleEffect(0.8)
            } else {
                Button { state.loadPlayers() } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(accentGreen.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

// MARK: - Tab Enum

enum AdminTab: CaseIterable {
    case home, simulator, loot, players, settings

    var label: String {
        switch self {
        case .home: return "Accueil"
        case .simulator: return "Sim"
        case .loot: return "Loot"
        case .players: return "Joueurs"
        case .settings: return "Options"
        }
    }

    var icon: String {
        switch self {
        case .home: return "square.grid.2x2.fill"
        case .simulator: return "gamecontroller.fill"
        case .loot: return "diamond.fill"
        case .players: return "person.2.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Bottom Bar

struct AdminBottomBar: View {
    @Binding var selectedTab: AdminTab

    var body: some View {
        HStack {
            ForEach(AdminTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18))
                        Text(tab.label)
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(selectedTab == tab ? accentGreen : ThemeManager.shared.colors.textPrimary.opacity(0.35))
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 10)
        .background(ThemeManager.shared.colors.surface.opacity(0.95))
    }
}

// ════════════════════════════════════════
// MARK: - HOME TAB (Dashboard)
// ════════════════════════════════════════

struct AdminHomeTab: View {
    @ObservedObject var state: AdminState
    @State private var onlinePlayers = 0
    @State private var totalPlayers = 0
    @State private var totalDiscoveredHexes = 0
    @State private var totalOwnedHexes = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Tableau de Bord")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(icon: "wifi", label: "Joueurs en ligne", value: "\(onlinePlayers)", color: accentGreen)
                    StatCard(icon: "person.crop.circle.badge.checkmark", label: "Joueurs Uniques", value: "\(totalPlayers)", color: accentBlue)
                    StatCard(icon: "hexagon.fill", label: "Hex Découverts", value: "\(totalDiscoveredHexes)", color: Color(hex: "#FF9800"))
                    StatCard(icon: "flag.fill", label: "Hex Owned", value: "\(totalOwnedHexes)", color: Color(hex: "#E040FB"))
                }
                .padding(.horizontal, 16)

                // Quick Player List
                if !state.players.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("JOUEURS RÉCENTS")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.5)
                            .foregroundColor(ThemeManager.shared.colors.textPrimary.opacity(0.4))

                        ForEach(state.players.prefix(5)) { player in
                            HStack {
                                Circle()
                                    .fill(Color(hex: player.hexColor ?? "#00FFAA"))
                                    .frame(width: 10, height: 10)
                                Text(player.name)
                                    .foregroundColor(ThemeManager.shared.colors.textPrimary)
                                    .font(.system(size: 14))
                                Spacer()
                                Text("\(player.score) pts")
                                    .foregroundColor(accentGreen)
                                    .font(.system(size: 13, weight: .bold))
                                    .monospacedDigit()
                                if player.banned {
                                    Text("🚫")
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .padding(16)
                    .background(glassBg)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(glassStroke, lineWidth: 1))
                    .padding(.horizontal, 16)
                }

                Spacer().frame(height: 20)
            }
        }
        .onAppear { loadStats() }
    }

    private func loadStats() {
        let base = AppState.shared.backendBaseUrl
        guard let url = URL(string: "\(base)/v1/admin/stats"),
              let token = AuthManager.shared.getAccessToken() else { return }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")

        URLSession.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async {
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

                // Parse int from string or int (PostgreSQL COUNT returns string)
                func parseInt(_ val: Any?) -> Int {
                    if let n = val as? Int { return n }
                    if let s = val as? String { return Int(s) ?? 0 }
                    return 0
                }

                onlinePlayers = parseInt(json["online_players"])
                totalPlayers = parseInt(json["total_players"])
                totalDiscoveredHexes = parseInt(json["total_discovered_hexes"])
                totalOwnedHexes = parseInt(json["total_owned_hexes"])
            }
        }.resume()
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Spacer()
            }
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(ThemeManager.shared.colors.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(ThemeManager.shared.colors.textPrimary.opacity(0.5))
        }
        .padding(16)
        .background(glassBg)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(glassStroke, lineWidth: 1))
    }
}

// ════════════════════════════════════════
// MARK: - SIMULATOR TAB
// ════════════════════════════════════════

struct AdminSimulatorTab: View {
    @State private var region: MKCoordinateRegion = {
        if let loc = LocationService.shared.currentLocation {
            return MKCoordinateRegion(
                center: loc.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
            )
        }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 45.5019, longitude: -73.5674),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    }()
    @State private var startPoint: CLLocationCoordinate2D? = nil
    @State private var endPoint: CLLocationCoordinate2D? = nil
    @State private var pickingMode: PickingMode = .none
    @State private var isRunning = false
    @State private var isLoading = false
    @State private var statusMessage = ""
    @State private var speedKmh: Double = 50
    @State private var annotations: [SimAnnotation] = []

    enum PickingMode { case none, start, end }

    var body: some View {
        ZStack {
            SimulatorMapView(region: $region, annotations: $annotations, onTap: handleMapTap)
                .ignoresSafeArea(edges: .bottom)

            VStack {
                // Control Panel
                VStack(spacing: 10) {
                    Text("SIMULATION")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(accentGreen.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        GlassButton(text: "Départ", isActive: pickingMode == .start, color: Color(hex: "#FFB74D")) {
                            pickingMode = pickingMode == .start ? .none : .start
                        }
                        GlassButton(text: "Arrivée", isActive: pickingMode == .end, color: accentBlue) {
                            pickingMode = pickingMode == .end ? .none : .end
                        }
                        GlassButton(
                            text: isRunning ? "Stop" : "Go",
                            isActive: isRunning,
                            color: isRunning ? Color(hex: "#E53935") : Color(hex: "#4CAF50")
                        ) {
                            if isRunning { stopSimulation() }
                            else if startPoint != nil && endPoint != nil { startSimulation() }
                        }
                        .opacity(startPoint != nil && endPoint != nil || isRunning ? 1.0 : 0.4)
                    }

                    // Speed
                    HStack {
                        Image(systemName: "speedometer").foregroundColor(accentGreen).font(.system(size: 14))
                        Text("Vitesse").foregroundColor(ThemeManager.shared.colors.textPrimary).font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text("\(Int(speedKmh)) km/h")
                            .foregroundColor(accentGreen)
                            .font(.system(size: 13, weight: .bold))
                            .monospacedDigit()
                    }
                    Slider(value: $speedKmh, in: 10...120, step: 5).tint(accentGreen)

                    // Use GPS
                    Button { useCurrentLocation() } label: {
                        HStack {
                            Text("📍")
                            Text("Ma position → Départ").font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(hex: "#4CAF50").opacity(0.3))
                        .cornerRadius(8)
                    }

                    if !statusMessage.isEmpty {
                        Text(statusMessage).font(.system(size: 12)).foregroundColor(accentGreen)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if isLoading { ProgressView().tint(accentGreen) }
                }
                .padding(12)
                .background(ThemeManager.shared.colors.background.opacity(0.92))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(glassStroke, lineWidth: 1))
                .padding(12)

                Spacer()

                if pickingMode != .none {
                    Text(pickingMode == .start ? "Touchez la carte : DÉPART" : "Touchez la carte : ARRIVÉE")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(pickingMode == .start ? Color(hex: "#FFB74D") : accentBlue)
                        .cornerRadius(20)
                        .shadow(radius: 4)
                        .padding(.bottom, 20)
                }
            }
        }
    }

    private func handleMapTap(_ coordinate: CLLocationCoordinate2D) {
        switch pickingMode {
        case .start:
            startPoint = coordinate; pickingMode = .none; updateAnnotations(); statusMessage = "Départ placé"
        case .end:
            endPoint = coordinate; pickingMode = .none; updateAnnotations(); statusMessage = "Arrivée placée"
        case .none: break
        }
    }

    private func useCurrentLocation() {
        let locManager = CLLocationManager()
        if let loc = locManager.location {
            startPoint = loc.coordinate
            region = MKCoordinateRegion(center: loc.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
            updateAnnotations(); statusMessage = "Départ = position actuelle"
        } else { statusMessage = "⚠️ Position GPS indisponible" }
    }

    private func updateAnnotations() {
        var a: [SimAnnotation] = []
        if let s = startPoint { a.append(SimAnnotation(coordinate: s, type: .start)) }
        if let e = endPoint { a.append(SimAnnotation(coordinate: e, type: .end)) }
        annotations = a
    }

    private func startSimulation() {
        guard let start = startPoint, let end = endPoint else { return }
        isLoading = true; statusMessage = "⏳ Calcul de la route..."

        let baseUrl = AppState.shared.backendBaseUrl
        guard let token = AuthManager.shared.getAccessToken() else {
            statusMessage = "❌ Non authentifié"; isLoading = false; return
        }

        let routeUrlStr = "\(baseUrl)/v1/admin/route?start=\(start.latitude),\(start.longitude)&end=\(end.latitude),\(end.longitude)"
        guard let routeUrl = URL(string: routeUrlStr) else { return }

        var routeReq = URLRequest(url: routeUrl)
        routeReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        routeReq.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")

        URLSession.shared.dataTask(with: routeReq) { data, _, error in
            if let error = error {
                DispatchQueue.main.async { statusMessage = "❌ \(error.localizedDescription)"; isLoading = false }
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let coordinates = json["coordinates"] as? [[Double]] else {
                DispatchQueue.main.async { statusMessage = "❌ Route invalide"; isLoading = false }
                return
            }
            let path = coordinates.map { (lat: $0[1], lon: $0[0]) }
            DispatchQueue.main.async {
                isLoading = false; isRunning = true
                statusMessage = "✅ Simulation (\(path.count) pts, \(Int(speedKmh)) km/h)"
                LocationService.shared.startRouteSimulation(path: path, speedKmh: speedKmh)
            }
        }.resume()
    }

    private func stopSimulation() {
        LocationService.shared.stopRouteSimulation()
        isRunning = false; statusMessage = "⏹️ Simulation arrêtée"
    }
}

// ════════════════════════════════════════
// MARK: - LOOT TAB (Dashboard + Reset)
// ════════════════════════════════════════

struct AdminLootTab: View {
    @State private var isResetting = false
    @State private var status = ""
    @State private var lootData: [LootStat] = []
    @State private var totalLoot = 0
    @State private var isLoadingLoot = false
    @State private var lootPoints: [LootPoint] = []
    @State private var activeFilters: Set<String> = ["quartz", "jade", "saphir", "ruby", "arcane"]
    @State private var showInventoryManager = false

    struct LootStat: Identifiable {
        let id = UUID()
        let gem: String
        let count: Int
        let color: Color
        let emoji: String
    }

    struct LootPoint: Identifiable {
        let id: String
        let lat: Double
        let lon: Double
        let gem: String
    }

    private let gemInfo: [String: (Color, String)] = [
        "quartz": (Color(hex: "#B0BEC5"), "🤍"),
        "jade":   (Color(hex: "#66BB6A"), "💚"),
        "saphir": (Color(hex: "#42A5F5"), "💙"),
        "ruby":   (Color(hex: "#EF5350"), "❤️"),
        "arcane": (Color(hex: "#AB47BC"), "💜"),
    ]

    private var filteredLoot: [LootPoint] {
        lootPoints.filter { activeFilters.contains($0.gem) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Map with GPS recenter button
            ZStack(alignment: .topTrailing) {
                LootMapContainer(lootPoints: filteredLoot)
                    .frame(height: 260)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(glassStroke, lineWidth: 1))

                // GPS recenter button
                Button {
                    NotificationCenter.default.post(name: NSNotification.Name("LootMapRecenter"), object: nil)
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                        .frame(width: 34, height: 34)
                        .background(Color(hex: "#1A73E8").opacity(0.9))
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                }
                .padding(10)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            // Filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(["quartz", "jade", "saphir", "ruby", "arcane"], id: \.self) { gem in
                        let info = gemInfo[gem] ?? (Color.gray, "⬜")
                        let isOn = activeFilters.contains(gem)
                        Button {
                            if isOn { activeFilters.remove(gem) } else { activeFilters.insert(gem) }
                        } label: {
                            HStack(spacing: 4) {
                                Text(info.1)
                                Text(gem.capitalized).font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(isOn ? .white : info.0)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isOn ? info.0.opacity(0.7) : info.0.opacity(0.12))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            // Stats + actions
            ScrollView {
                VStack(spacing: 12) {
                    if !lootData.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("RÉPARTITION DES RESSOURCES")
                                .font(.system(size: 11, weight: .bold)).tracking(0.5)
                                .foregroundColor(ThemeManager.shared.colors.textPrimary.opacity(0.4))

                            ForEach(lootData) { stat in
                                HStack {
                                    Text(stat.emoji)
                                    Text(stat.gem.capitalized)
                                        .font(.system(size: 14, weight: .medium)).foregroundColor(ThemeManager.shared.colors.textPrimary)
                                    Spacer()
                                    GeometryReader { geo in
                                        let pct = totalLoot > 0 ? CGFloat(stat.count) / CGFloat(totalLoot) : 0
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.05))
                                            RoundedRectangle(cornerRadius: 4).fill(stat.color)
                                                .frame(width: geo.size.width * pct)
                                        }
                                    }
                                    .frame(width: 90, height: 8)
                                    Text("\(stat.count)")
                                        .font(.system(size: 13, weight: .bold)).foregroundColor(stat.color)
                                        .monospacedDigit().frame(width: 40, alignment: .trailing)
                                    Text(totalLoot > 0 ? "\(Int(Double(stat.count) / Double(totalLoot) * 100))%" : "—")
                                        .font(.system(size: 12)).foregroundColor(ThemeManager.shared.colors.textPrimary.opacity(0.5))
                                        .frame(width: 35, alignment: .trailing)
                                }
                            }
                        }
                        .padding(14).background(glassBg).cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(glassStroke, lineWidth: 1))
                        .padding(.horizontal, 12)
                    }

                    // Reset
                    Button { resetLoot() } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("🔄 Reset & Repopulate").fontWeight(.medium)
                        }
                        .foregroundColor(ThemeManager.shared.colors.textPrimary).frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#FF9800").opacity(0.8)).cornerRadius(10)
                    }
                    .disabled(isResetting)
                    .padding(.horizontal, 12)

                    // Inventory Manager
                    Button { showInventoryManager = true } label: {
                        HStack {
                            Image(systemName: "cube.fill")
                            Text("💎 Gérer Inventaire (Joueur actif)").fontWeight(.medium)
                        }
                        .foregroundColor(ThemeManager.shared.colors.textPrimary).frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#7C4DFF").opacity(0.8)).cornerRadius(10)
                    }
                    .padding(.horizontal, 12)

                    if !status.isEmpty {
                        Text(status).font(.system(size: 12)).foregroundColor(accentGreen)
                            .padding(.horizontal, 12)
                    }
                    Spacer().frame(height: 20)
                }
            }

            if isLoadingLoot { ProgressView().tint(accentGreen).padding(8) }
        }
        .onAppear { loadLootStats() }
        .sheet(isPresented: $showInventoryManager) {
            InventoryManagerSheet()
        }
    }

    private func loadLootStats() {
        isLoadingLoot = true
        let base = AppState.shared.backendBaseUrl
        guard let url = URL(string: "\(base)/v1/admin/loot"),
              let token = AuthManager.shared.getAccessToken() else { isLoadingLoot = false; return }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")

        URLSession.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async {
                isLoadingLoot = false
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    if let data = data, let raw = String(data: data, encoding: .utf8) {
                        print("⚠️ AdminLoot: raw response (first 500): \(String(raw.prefix(500)))")
                    }
                    return
                }

                // Debug: show gem distribution from API
                if let first = json.first {
                    print("📊 AdminLoot: first item keys=\(first.keys.sorted()), gem=\(first["gem"] ?? "nil")")
                }
                let gemSample = json.prefix(5).map { ($0["gem"] as? String) ?? "nil" }
                print("📊 AdminLoot: \(json.count) items, first 5 gems=\(gemSample)")

                // Parse loot points for map
                lootPoints = json.compactMap { loot in
                    guard let lat = loot["lat"] as? Double,
                          let lon = loot["lon"] as? Double else { return nil }
                    let gem = (loot["gem"] as? String) ?? "quartz"
                    let id = "\(loot["id"] ?? UUID().uuidString)"
                    return LootPoint(id: id, lat: lat, lon: lon, gem: gem)
                }
                totalLoot = lootPoints.count

                // Count by gem
                var counts: [String: Int] = [:]
                for lp in lootPoints { counts[lp.gem, default: 0] += 1 }

                let order = ["quartz", "jade", "saphir", "ruby", "arcane"]
                lootData = order.compactMap { gem in
                    let count = counts[gem] ?? 0
                    let info = gemInfo[gem] ?? (Color.gray, "⬜")
                    return LootStat(gem: gem, count: count, color: info.0, emoji: info.1)
                }
            }
        }.resume()
    }

    private func resetLoot() {
        isResetting = true; status = "⏳ Reset en cours..."
        let base = AppState.shared.backendBaseUrl
        guard let url = URL(string: "\(base)/v1/admin/loot/respawn") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        req.httpBody = "{}".data(using: .utf8)
        URLSession.shared.dataTask(with: req) { _, response, error in
            DispatchQueue.main.async {
                isResetting = false
                if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                    status = "✅ Loot reset!"; loadLootStats()
                } else {
                    status = "❌ Erreur: \(error?.localizedDescription ?? "HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")"
                }
            }
        }.resume()
    }
}

// MARK: - Repeat Button (long-press auto-repeat with acceleration)

struct RepeatButton<Label: View>: View {
    let action: () -> Void
    let label: () -> Label
    
    @State private var timer: Timer?
    @State private var tickCount = 0
    
    init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
    }
    
    var body: some View {
        label()
            .contentShape(Rectangle())
            .onTapGesture { action() }
            .onLongPressGesture(minimumDuration: 0.3, pressing: { pressing in
                if pressing {
                    tickCount = 0
                    action() // fire once immediately
                    timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
                        tickCount += 1
                        action()
                        // Accelerate: replace timer with faster interval
                        let newInterval: TimeInterval
                        if tickCount > 20 { newInterval = 0.03 }
                        else if tickCount > 10 { newInterval = 0.06 }
                        else if tickCount > 5 { newInterval = 0.1 }
                        else { return } // keep 0.2
                        timer?.invalidate()
                        timer = Timer.scheduledTimer(withTimeInterval: newInterval, repeats: true) { _ in
                            tickCount += 1
                            action()
                        }
                    }
                } else {
                    timer?.invalidate()
                    timer = nil
                }
            }, perform: {})
    }
}

// MARK: - Inventory Manager Sheet

struct InventoryManagerSheet: View {
    @Environment(\.dismiss) var dismiss
    var playerId: String? = nil    // nil = current player
    var playerName: String? = nil  // display name for header
    @State private var gems: [(name: String, emoji: String, color: Color, quantity: Int, cap: Int?)] = [
        ("quartz", "🤍", Color(hex: "#B0BEC5"), 0, 30),
        ("jade",   "💚", Color(hex: "#66BB6A"), 0, 12),
        ("saphir", "💙", Color(hex: "#42A5F5"), 0, 5),
        ("ruby",   "❤️", Color(hex: "#EF5350"), 0, 3),
        ("arcane", "💜", Color(hex: "#AB47BC"), 0, nil),
    ]
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var statusMessage = ""

    private var resolvedPlayerId: String? {
        if let pid = playerId { return pid }
        guard let token = AuthManager.shared.getAccessToken() else { return nil }
        return AuthManager.shared.getPlayerIdFromToken(token)
    }

    var body: some View {
        NavigationView {
            ZStack {
                ThemeManager.shared.colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        // Header
                        Text(playerName != nil ? "INVENTAIRE DE \(playerName!.uppercased())" : "INVENTAIRE DU JOUEUR")
                            .font(.system(size: 11, weight: .bold)).tracking(1)
                            .foregroundColor(ThemeManager.shared.colors.textPrimary.opacity(0.4))
                            .padding(.top, 12)

                        // Gem rows
                        ForEach(0..<gems.count, id: \.self) { i in
                            gemRow(index: i)
                        }

                        // Quick actions
                        HStack(spacing: 10) {
                            Button { resetAll() } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash").font(.system(size: 12))
                                    Text("Reset All").font(.system(size: 13, weight: .bold))
                                }
                                .foregroundColor(ThemeManager.shared.colors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(Color(hex: "#FF5252").opacity(0.7))
                                .cornerRadius(10)
                            }

                            Button { maxAll() } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.to.line").font(.system(size: 12))
                                    Text("Max All").font(.system(size: 13, weight: .bold))
                                }
                                .foregroundColor(ThemeManager.shared.colors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(Color(hex: "#4CAF50").opacity(0.7))
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal, 16)

                        // Save button
                        Button { saveInventory() } label: {
                            HStack {
                                if isSaving {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                                Text("Appliquer").fontWeight(.bold)
                            }
                            .foregroundColor(ThemeManager.shared.colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "#7C4DFF"))
                            .cornerRadius(12)
                        }
                        .disabled(isSaving)
                        .padding(.horizontal, 16)

                        if !statusMessage.isEmpty {
                            Text(statusMessage)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(statusMessage.contains("✅") ? Color(hex: "#4CAF50") : Color(hex: "#FF5252"))
                                .padding(.horizontal, 16)
                        }

                        Spacer().frame(height: 30)
                    }
                }
            }
            .navigationTitle("💎 Inventaire")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }.foregroundColor(Color(hex: "#4CAF50"))
                }
            }
            .onAppear { loadInventory() }
        }
    }

    @ViewBuilder
    private func gemRow(index i: Int) -> some View {
        let gem = gems[i]
        HStack(spacing: 12) {
            // Emoji + name
            Text(gem.emoji).font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text(gem.name.capitalized)
                    .font(.system(size: 15, weight: .bold)).foregroundColor(ThemeManager.shared.colors.textPrimary)
                if let cap = gem.cap {
                    Text("max: \(cap)")
                        .font(.system(size: 10)).foregroundColor(ThemeManager.shared.colors.textPrimary.opacity(0.35))
                } else {
                    Text("∞ illimité")
                        .font(.system(size: 10)).foregroundColor(ThemeManager.shared.colors.textPrimary.opacity(0.35))
                }
            }

            Spacer()

            // Stepper controls
            HStack(spacing: 0) {
                RepeatButton {
                    if gems[i].quantity > 0 { gems[i].quantity -= 1 }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                }

                Text("\(gem.quantity)")
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(gem.color)
                    .monospacedDigit()
                    .frame(width: 50)

                RepeatButton {
                    let max = gem.cap ?? 9999
                    if gems[i].quantity < max { gems[i].quantity += 1 }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(gem.color.opacity(0.4))
                        .cornerRadius(8)
                }
            }

            // Fixed-width trailing indicator (always present for alignment)
            if let cap = gem.cap, cap > 0 {
                GeometryReader { geo in
                    let pct = CGFloat(gem.quantity) / CGFloat(cap)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.06))
                        RoundedRectangle(cornerRadius: 3).fill(gem.color.opacity(0.7))
                            .frame(width: geo.size.width * min(pct, 1))
                    }
                }
                .frame(width: 40, height: 6)
            } else {
                Text("∞")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(gem.color.opacity(0.5))
                    .frame(width: 40)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(gem.color.opacity(0.2), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private func resetAll() {
        for i in 0..<gems.count { gems[i].quantity = 0 }
        statusMessage = ""
    }

    private func maxAll() {
        for i in 0..<gems.count {
            gems[i].quantity = gems[i].cap ?? 999
        }
        statusMessage = ""
    }

    private func loadInventory() {
        isLoading = true
        let base = AppState.shared.backendBaseUrl
        guard let token = AuthManager.shared.getAccessToken(),
              let userId = resolvedPlayerId,
              let url = URL(string: "\(base)/v1/admin/players/\(userId)/inventory") else {
            isLoading = false; return
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        URLSession.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async {
                isLoading = false
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let gemsJson = json["gems"] as? [String: Any] else { return }

                for i in 0..<gems.count {
                    let name = gems[i].name
                    if let gemData = gemsJson[name] as? [String: Any] {
                        gems[i].quantity = gemData["quantity"] as? Int ?? 0
                        if let cap = gemData["cap"] as? Int {
                            gems[i].cap = cap
                        }
                    }
                }
            }
        }.resume()
    }

    private func saveInventory() {
        isSaving = true; statusMessage = ""
        let base = AppState.shared.backendBaseUrl
        guard let token = AuthManager.shared.getAccessToken(),
              let userId = resolvedPlayerId,
              let url = URL(string: "\(base)/v1/admin/players/\(userId)/inventory") else {
            isSaving = false; statusMessage = "❌ Pas de joueur"; return
        }
        var body: [String: Int] = [:]
        for gem in gems { body[gem.name] = gem.quantity }

        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req) { _, response, error in
            DispatchQueue.main.async {
                isSaving = false
                if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                    statusMessage = "✅ Inventaire mis à jour!"
                    GemInventoryState.shared.fetchFromBackend()
                } else {
                    statusMessage = "❌ Erreur: \(error?.localizedDescription ?? "HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")"
                }
            }
        }.resume()
    }
}

// MARK: - Loot Map (MapKit)

struct LootMapContainer: UIViewRepresentable {
    let lootPoints: [AdminLootTab.LootPoint]

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.mapType = .satellite
        map.showsUserLocation = true
        if let loc = LocationService.shared.currentLocation {
            map.region = MKCoordinateRegion(center: loc.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03))
        } else {
            map.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 45.5019, longitude: -73.5674), span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
        }

        // Listen for recenter notification
        context.coordinator.mapRef = map
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.recenterToGPS), name: NSNotification.Name("LootMapRecenter"), object: nil)

        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeAnnotations(map.annotations.filter { !($0 is MKUserLocation) })
        for loot in lootPoints {
            let ann = MKPointAnnotation()
            ann.coordinate = CLLocationCoordinate2D(latitude: loot.lat, longitude: loot.lon)
            ann.title = loot.gem.capitalized
            ann.subtitle = loot.gem
            map.addAnnotation(ann)
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        weak var mapRef: MKMapView?

        @objc func recenterToGPS() {
            guard let map = mapRef,
                  let loc = LocationService.shared.currentLocation else { return }
            map.setRegion(
                MKCoordinateRegion(center: loc.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)),
                animated: true
            )
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            let gem = (annotation.subtitle ?? "quartz") ?? "quartz"
            let reuseId = "loot_\(gem)"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) ?? MKAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            view.annotation = annotation
            let size: CGFloat = 10
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
            let uiColor = Self.gemUIColor(for: gem)
            view.image = renderer.image { ctx in
                uiColor.setFill()
                ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
            }
            view.canShowCallout = false
            return view
        }

        static func gemUIColor(for gem: String) -> UIColor {
            switch gem {
            case "quartz": return UIColor(red: 0.69, green: 0.75, blue: 0.77, alpha: 1)
            case "jade":   return UIColor(red: 0.40, green: 0.73, blue: 0.42, alpha: 1)
            case "saphir": return UIColor(red: 0.26, green: 0.65, blue: 0.96, alpha: 1)
            case "ruby":   return UIColor(red: 0.94, green: 0.33, blue: 0.31, alpha: 1)
            case "arcane": return UIColor(red: 0.67, green: 0.28, blue: 0.74, alpha: 1)
            default:       return UIColor.gray
            }
        }
    }
}

// ════════════════════════════════════════
// MARK: - PLAYERS TAB
// ════════════════════════════════════════

struct AdminPlayersTab: View {
    @ObservedObject var state: AdminState
    @State private var showCreateSheet = false
    @State private var selectedPlayer: AdminPlayer? = nil
    @State private var showDeleteConfirm: AdminPlayer? = nil
    @State private var mapPlayer: AdminPlayer? = nil
    @State private var inventoryPlayer: AdminPlayer? = nil

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 8) {
                    HStack {
                        Text("Joueurs")
                            .font(.system(size: 24, weight: .bold, design: .serif))
                            .foregroundColor(ThemeManager.shared.colors.textPrimary)
                        Spacer()
                        Button { showCreateSheet = true } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(accentGreen)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    ForEach(state.players) { player in
                        PlayerRow(player: player) {
                            selectedPlayer = player
                        } onMap: {
                            mapPlayer = player
                        } onInventory: {
                            inventoryPlayer = player
                        } onDelete: {
                            showDeleteConfirm = player
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer().frame(height: 20)
                }
            }

            if let error = state.error {
                VStack {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(12)
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(8)
                    Spacer()
                }
                .padding(.top, 8)
            }
        }
        .sheet(item: $selectedPlayer) { player in
            EditPlayerSheet(player: player, state: state)
        }
        .sheet(isPresented: $showCreateSheet) {
            CreatePlayerSheet(state: state, isPresented: $showCreateSheet)
        }
        .alert("Supprimer ce joueur?", isPresented: Binding(
            get: { showDeleteConfirm != nil },
            set: { if !$0 { showDeleteConfirm = nil } }
        )) {
            Button("Annuler", role: .cancel) { showDeleteConfirm = nil }
            Button("Supprimer", role: .destructive) {
                if let p = showDeleteConfirm { state.deletePlayer(p.id) }
                showDeleteConfirm = nil
            }
        } message: {
            if let p = showDeleteConfirm {
                Text("\(p.name) — \(p.email)\n⚠️ Action irréversible!")
            }
        }
        .sheet(item: $mapPlayer) { player in
            PlayerDiscoveryMapView(player: player, state: state)
        }
        .sheet(item: $inventoryPlayer) { player in
            InventoryManagerSheet(playerId: player.id, playerName: player.name)
        }
    }
}

struct PlayerRow: View {
    let player: AdminPlayer
    let onEdit: () -> Void
    let onMap: () -> Void
    let onInventory: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Color dot
            Circle()
                .fill(Color(hex: player.hexColor ?? "#00FFAA"))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(player.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    if player.role == "ADMIN" {
                        Text("👑").font(.system(size: 11))
                    }
                    if player.banned {
                        Text("🚫").font(.system(size: 11))
                    }
                }
                Text(player.email)
                    .font(.system(size: 12))
                    .foregroundColor(ThemeManager.shared.colors.textPrimary.opacity(0.4))
            }

            Spacer()

            Text("\(player.score)")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(accentGreen)
                .monospacedDigit()

            // Actions — colored circles behind emojis (matches Android PlayerRow)
            HStack(spacing: 4) {
                Button { onMap() } label: {
                    Text("🗺️").font(.system(size: 13))
                        .frame(width: 30, height: 30)
                        .background(Color(hex: "#4CAF50").opacity(0.2))
                        .clipShape(Circle())
                }
                Button { onInventory() } label: {
                    Text("💎").font(.system(size: 13))
                        .frame(width: 30, height: 30)
                        .background(Color(hex: "#AB47BC").opacity(0.2))
                        .clipShape(Circle())
                }
                Button { onEdit() } label: {
                    Text("✏️").font(.system(size: 13))
                        .frame(width: 30, height: 30)
                        .background(Color(hex: "#42A5F5").opacity(0.2))
                        .clipShape(Circle())
                }
                Button { onDelete() } label: {
                    Text("🗑️").font(.system(size: 13))
                        .frame(width: 30, height: 30)
                        .background(Color(hex: "#EF5350").opacity(0.2))
                        .clipShape(Circle())
                }
            }
        }
        .padding(12)
        .background(glassBg)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(glassStroke, lineWidth: 1))
    }
}

// MARK: - Create Player Sheet

struct CreatePlayerSheet: View {
    @ObservedObject var state: AdminState
    @Binding var isPresented: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var error: String?

    var body: some View {
        NavigationView {
            ZStack {
                bgGradient.ignoresSafeArea()
                VStack(spacing: 16) {
                    glassInput(placeholder: "Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    glassInput(placeholder: "Nom d'affichage", text: $displayName)
                    glassInput(placeholder: "Mot de passe (min 6 car.)", text: $password)

                    if let error = error {
                        Text(error).font(.caption).foregroundColor(.red)
                    }

                    Button {
                        guard email.contains("@"), password.count >= 6 else {
                            error = "Email invalide ou mot de passe trop court"
                            return
                        }
                        state.createPlayer(
                            email: email,
                            password: password,
                            displayName: displayName.isEmpty ? email.split(separator: "@").first.map(String.init) ?? "Joueur" : displayName
                        ) { ok in
                            if ok { isPresented = false }
                            else { error = "Erreur lors de la création" }
                        }
                    } label: {
                        Text("Créer")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(LinearGradient(colors: [accentGreen, accentBlue], startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.black)
                            .cornerRadius(12)
                    }
                    .disabled(email.isEmpty || password.count < 6)

                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Créer un Joueur")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { isPresented = false }
                        .foregroundColor(accentGreen)
                }
            }
        }
    }

    private func glassInput(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .foregroundColor(ThemeManager.shared.colors.textPrimary)
            .padding()
            .background(glassBg)
            .cornerRadius(12)
    }
}

// MARK: - Edit Player Sheet

struct EditPlayerSheet: View {
    let player: AdminPlayer
    @ObservedObject var state: AdminState
    @Environment(\.dismiss) var dismiss
    @State private var displayName: String = ""
    @State private var newPassword = ""
    @State private var selectedColor: String = ""
    @State private var statusMsg: String?
    @State private var showAdminPassword = false
    @State private var adminPasswordInput = ""

    private let hexColors = [
        "#FF6B35", "#FF1744", "#D50000", "#C51162", "#AA00FF",
        "#6200EA", "#304FFE", "#2962FF", "#0091EA", "#00B8D4",
        "#00BFA5", "#00C853", "#64DD17", "#AEEA00", "#FFD600",
        "#FFAB00", "#FF6D00", "#DD2C00", "#F50057", "#D500F9",
        "#651FFF", "#3D5AFE", "#2979FF", "#00B0FF", "#00E5FF",
        "#1DE9B6", "#00E676", "#76FF03", "#C6FF00", "#FFC400",
        "#FF9100", "#FF3D00", "#E91E63", "#9C27B0", "#673AB7",
        "#3F51B5", "#2196F3", "#03A9F4", "#00BCD4", "#009688",
        "#4CAF50", "#8BC34A", "#CDDC39", "#FFC107", "#FF9800",
        "#FF5722", "#795548", "#607D8B", "#F06292", "#CE93D8"
    ]

    var body: some View {
        NavigationView {
            ZStack {
                bgGradient.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        // Player Info
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ID: \(player.id)").font(.system(size: 11)).foregroundColor(ThemeManager.shared.colors.textPrimary.opacity(0.3))
                            Text(player.email).font(.system(size: 14)).foregroundColor(ThemeManager.shared.colors.textPrimary.opacity(0.6))
                            Text("Score: \(player.score)").font(.system(size: 16, weight: .bold)).foregroundColor(accentGreen)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(glassBg)
                        .cornerRadius(14)

                        // SuperAdmin badge
                        if player.isSuperAdmin {
                            HStack {
                                Text("👑").font(.system(size: 20))
                                VStack(alignment: .leading) {
                                    Text("SUPER ADMIN").font(.system(size: 13, weight: .bold)).foregroundColor(Color(hex: "#FF9800"))
                                    Text("Ce compte ne peut pas être modifié.").font(.system(size: 11)).foregroundColor(ThemeManager.shared.colors.textPrimary.opacity(0.5))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(hex: "#FF9800").opacity(0.1))
                            .cornerRadius(12)
                        }

                        // Name
                        section(title: "NOM D'AFFICHAGE") {
                            TextField("Nom", text: $displayName)
                                .foregroundColor(ThemeManager.shared.colors.textPrimary)
                                .padding()
                                .background(glassBg)
                                .cornerRadius(10)

                            GlassButton(text: "SAUVEGARDER", isActive: displayName != player.name, color: accentGreen) {
                                state.updatePlayer(player.id, updates: ["displayName": displayName]) { _ in
                                    statusMsg = "✅ Nom sauvegardé"
                                }
                            }
                        }

                        // Hex Color
                        section(title: "COULEUR DE CLAIM") {
                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(32), spacing: 6), count: 8), spacing: 6) {
                                ForEach(hexColors, id: \.self) { color in
                                    Circle()
                                        .fill(Color(hex: color))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle().stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                        )
                                        .onTapGesture {
                                            selectedColor = color
                                            state.updatePlayer(player.id, updates: ["hexColor": color])
                                        }
                                }
                            }
                        }

                        // Password
                        section(title: "CHANGER MOT DE PASSE") {
                            TextField("Nouveau mot de passe", text: $newPassword)
                                .foregroundColor(ThemeManager.shared.colors.textPrimary)
                                .padding()
                                .background(glassBg)
                                .cornerRadius(10)

                            GlassButton(text: "CHANGER", isActive: newPassword.count >= 6, color: Color(hex: "#FFB74D")) {
                                state.updatePassword(player.id, newPassword: newPassword) { ok in
                                    statusMsg = ok ? "✅ Mot de passe changé" : "❌ Erreur"
                                    newPassword = ""
                                }
                            }
                        }

                        // Admin Controls
                        if !player.isSuperAdmin {
                            section(title: "ADMINISTRATION") {
                                if let pc = player.postalCode { Text("📮 \(pc)").foregroundColor(ThemeManager.shared.colors.textPrimary.opacity(0.5)).font(.system(size: 13)) }
                                if let city = player.homeCity { Text("🏙️ \(city)").foregroundColor(ThemeManager.shared.colors.textPrimary.opacity(0.5)).font(.system(size: 13)) }

                                HStack(spacing: 8) {
                                    GlassButton(
                                        text: player.banned ? "🚫 DÉBANNIR" : "🚫 BANNIR",
                                        isActive: player.banned,
                                        color: player.banned ? Color(hex: "#4CAF50") : Color(hex: "#E53935")
                                    ) {
                                        state.updatePlayer(player.id, updates: ["banned": !player.banned]) { _ in dismiss() }
                                    }

                                    GlassButton(
                                        text: player.role == "ADMIN" ? "👑 RETIRER" : "👑 ADMIN",
                                        isActive: player.role == "ADMIN",
                                        color: Color(hex: "#FF9800")
                                    ) {
                                        if player.role == "ADMIN" {
                                            state.updatePlayer(player.id, updates: ["role": "USER"]) { _ in dismiss() }
                                        } else {
                                            showAdminPassword = true
                                        }
                                    }
                                }
                            }

                            // Reset
                            section(title: "OPTIONS DE RESET") {
                                HStack(spacing: 8) {
                                    GlassButton(text: "Score", isActive: false, color: Color(hex: "#FFB74D")) {
                                        state.resetPlayer(player.id, options: ["score": true]) { _ in statusMsg = "✅ Score reset" }
                                    }
                                    GlassButton(text: "Fog", isActive: false, color: Color(hex: "#64B5F6")) {
                                        state.resetPlayer(player.id, options: ["fog": true]) { _ in statusMsg = "✅ Fog reset" }
                                    }
                                }
                                GlassButton(text: "⚠️ RESET COMPLET", isActive: false, color: Color(hex: "#E53935")) {
                                    state.resetPlayer(player.id, options: ["all": true]) { _ in
                                        statusMsg = "✅ Reset complet"
                                        dismiss()
                                    }
                                }
                            }
                        }

                        if let msg = statusMsg {
                            Text(msg).font(.system(size: 13)).foregroundColor(accentGreen)
                        }

                        Spacer().frame(height: 40)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Modifier Joueur")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }.foregroundColor(accentGreen)
                }
            }
            .onAppear {
                displayName = player.name
                selectedColor = player.hexColor ?? "#00FFAA"
            }
            .alert("Mot de passe Admin", isPresented: $showAdminPassword) {
                SecureField("Mot de passe", text: $adminPasswordInput)
                Button("Annuler", role: .cancel) { adminPasswordInput = "" }
                Button("Confirmer") {
                    if adminPasswordInput == "2124" {
                        state.updatePlayer(player.id, updates: ["role": "ADMIN", "adminPassword": adminPasswordInput]) { _ in dismiss() }
                    }
                    adminPasswordInput = ""
                }
            } message: {
                Text("Entrez le mot de passe pour promouvoir \(player.name)")
            }
        }
    }

    @ViewBuilder
    private func section(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
                .foregroundColor(ThemeManager.shared.colors.textPrimary.opacity(0.4))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// ════════════════════════════════════════
// MARK: - SETTINGS TAB
// ════════════════════════════════════════

struct AdminSettingsTab: View {
    @State private var fogOpacity: Double = 100
    @State private var showMetrics = false
    @State private var benchmarkRunning = false
    @State private var benchmarkStatus = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Options")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // Fog
                VStack(alignment: .leading, spacing: 10) {
                    Text("BROUILLARD")
                        .font(.system(size: 11, weight: .bold)).tracking(0.5)
                        .foregroundColor(ThemeManager.shared.colors.textPrimary.opacity(0.4))

                    Button {
                        let newVal: Double = fogOpacity > 0 ? 0 : 100
                        fogOpacity = newVal
                        UnityBridge.shared.send("SetFogOpacity", value: newVal == 100 ? "1" : "0")
                    } label: {
                        HStack {
                            Image(systemName: fogOpacity > 0 ? "cloud.fog.fill" : "cloud.fog")
                            Text(fogOpacity > 0 ? "🌫️ Désactiver Brouillard" : "🌫️ Activer Brouillard")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(fogOpacity > 0 ? Color(hex: "#4CAF50").opacity(0.8) : Color.gray.opacity(0.4))
                        .cornerRadius(10)
                    }

                    // Slider
                    HStack {
                        Image(systemName: "cloud.fog.fill").foregroundColor(accentGreen).font(.system(size: 14))
                        Text("Opacité").foregroundColor(ThemeManager.shared.colors.textPrimary).font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text("\(Int(fogOpacity))%")
                            .foregroundColor(accentGreen)
                            .font(.system(size: 13, weight: .bold))
                            .monospacedDigit()
                    }
                    Slider(value: $fogOpacity, in: 0...100, step: 1).tint(accentGreen)
                        .onChange(of: fogOpacity) { newValue in
                            let v = newValue == 100 ? "1" : newValue == 0 ? "0" : String(format: "%.2f", newValue / 100.0)
                            UnityBridge.shared.send("SetFogOpacity", value: v)
                        }
                }
                .padding(16)
                .background(glassBg)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(glassStroke, lineWidth: 1))
                .padding(.horizontal, 16)

                // Metrics Toggle
                HStack {
                    Label("Show Debug Metrics", systemImage: "chart.bar.fill").foregroundColor(ThemeManager.shared.colors.textPrimary)
                    Spacer()
                    Toggle("", isOn: $showMetrics).toggleStyle(SwitchToggleStyle(tint: accentGreen)).labelsHidden()
                }
                .padding(16)
                .background(glassBg)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(glassStroke, lineWidth: 1))
                .padding(.horizontal, 16)
                .onChange(of: showMetrics) { newValue in
                    UnityBridge.shared.send("SetShowMetrics", value: newValue ? "1" : "0")
                }

                // Debug Tools
                VStack(alignment: .leading, spacing: 10) {
                    Text("OUTILS DEBUG")
                        .font(.system(size: 11, weight: .bold)).tracking(0.5)
                        .foregroundColor(ThemeManager.shared.colors.textPrimary.opacity(0.4))

                    debugButton(icon: "gauge", text: benchmarkRunning ? "🔴 Benchmark en cours..." : "📊 Start Benchmark", color: benchmarkRunning ? Color(hex: "#E53935") : Color(hex: "#4CAF50")) {
                        UnityBridge.shared.send("StartBenchmark", value: "")
                        benchmarkRunning = true
                        benchmarkStatus = "✅ Benchmark démarré — quitte l'admin pour voir le banner"
                    }

                    if !benchmarkStatus.isEmpty {
                        Text(benchmarkStatus)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(accentGreen)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
                .background(glassBg)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(glassStroke, lineWidth: 1))
                .padding(.horizontal, 16)

                Spacer().frame(height: 20)
            }
        }
    }

    private func debugButton(icon: String, text: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(text).fontWeight(.medium)
            }
            .foregroundColor(ThemeManager.shared.colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.6))
            .cornerRadius(10)
        }
    }
}

// ════════════════════════════════════════
// MARK: - Shared Components
// ════════════════════════════════════════

struct GlassButton: View {
    let text: String
    var isActive: Bool = false
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isActive ? .white : color)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(isActive ? color : color.opacity(0.15))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.3), lineWidth: 1))
        }
    }
}

// MARK: - MapView (unchanged logic, matches original)

struct SimAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let type: AnnotationType
    enum AnnotationType { case start, end }
}

struct SimulatorMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var annotations: [SimAnnotation]
    var onTap: (CLLocationCoordinate2D) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)
        mapView.mapType = .satellite
        mapView.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:))))
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeAnnotations(mapView.annotations)
        for ann in annotations {
            let mkAnn = MKPointAnnotation()
            mkAnn.coordinate = ann.coordinate
            mkAnn.title = ann.type == .start ? "🟢 Départ" : "🔴 Arrivée"
            mapView.addAnnotation(mkAnn)
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: SimulatorMapView
        init(_ parent: SimulatorMapView) { self.parent = parent }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            parent.onTap(mapView.convert(point, toCoordinateFrom: mapView))
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: "sim_pin") ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "sim_pin")
            view.annotation = annotation
            if let marker = view as? MKMarkerAnnotationView {
                marker.markerTintColor = annotation.title == "🟢 Départ" ? .systemGreen : .systemRed
                marker.glyphText = annotation.title == "🟢 Départ" ? "A" : "B"
            }
            return view
        }
    }
}

// ════════════════════════════════════════
// MARK: - PLAYER DISCOVERY MAP VIEW
// ════════════════════════════════════════

struct PlayerDiscoveryMapView: View {
    let player: AdminPlayer
    @ObservedObject var state: AdminState
    @Environment(\.dismiss) var dismiss
    @State private var showDiscovered = true
    @State private var showOwned = true
    @State private var mapDarkness: Double = 0.3
    @State private var isLoading = true
    @State private var totalDiscovered = 0
    @State private var totalOwned = 0
    @State private var areaKm2 = "0"
    @State private var discoveredIslands: [DiscoveryIsland] = []
    @State private var ownedIslands: [DiscoveryIsland] = []

    struct DiscoveryIsland {
        let outer: [CLLocationCoordinate2D]
        let holes: [[CLLocationCoordinate2D]]
        let hexColor: String
    }

    var body: some View {
        NavigationView {
            ZStack {
                DiscoveryMapContainer(
                    discoveredIslands: discoveredIslands,
                    ownedIslands: ownedIslands,
                    playerColor: player.hexColor ?? "#00FFAA",
                    showDiscovered: showDiscovered,
                    showOwned: showOwned,
                    mapDarkness: mapDarkness
                )
                .ignoresSafeArea(edges: .bottom)

                VStack {
                    HStack(spacing: 16) {
                        StatPill(icon: "hexagon.fill", value: "\(totalDiscovered)", label: "Découverts", color: Color(hex: "#4CAF50"))
                        StatPill(icon: "flag.fill", value: "\(totalOwned)", label: "Owned", color: Color(hex: player.hexColor ?? "#651FFF"))
                        StatPill(icon: "map.fill", value: "\(areaKm2)", label: "km²", color: accentBlue)
                    }
                    .padding(12)
                    .background(ThemeManager.shared.colors.background.opacity(0.92))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(glassStroke, lineWidth: 1))
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                    Spacer()

                    HStack(spacing: 8) {
                        TogglePill(label: "Découverts", icon: "hexagon", isOn: $showDiscovered, color: Color(hex: "#4CAF50"))
                        TogglePill(label: "Owned", icon: "flag.fill", isOn: $showOwned, color: Color(hex: player.hexColor ?? "#651FFF"))
                    }
                    .padding(10)
                    .background(ThemeManager.shared.colors.background.opacity(0.92))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(glassStroke, lineWidth: 1))
                    .padding(.horizontal, 12)

                    // Opacity slider
                    HStack(spacing: 8) {
                        Image(systemName: "sun.max.fill").font(.system(size: 12)).foregroundColor(ThemeManager.shared.colors.textPrimary.opacity(0.5))
                        Slider(value: $mapDarkness, in: 0...0.85)
                            .tint(Color(hex: "#4CAF50"))
                        Image(systemName: "moon.fill").font(.system(size: 12)).foregroundColor(ThemeManager.shared.colors.textPrimary.opacity(0.5))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(ThemeManager.shared.colors.background.opacity(0.92))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(glassStroke, lineWidth: 1))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 20)
                }

                if isLoading {
                    ProgressView().tint(accentGreen).scaleEffect(1.5)
                        .padding(20).background(ThemeManager.shared.colors.background.opacity(0.8)).cornerRadius(12)
                }
            }
            .navigationTitle("🗺️ \(player.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }.foregroundColor(accentGreen)
                }
            }
            .onAppear { loadDiscovery() }
        }
    }

    private func loadDiscovery() {
        isLoading = true
        let base = AppState.shared.backendBaseUrl
        guard let url = URL(string: "\(base)/v1/admin/players/\(player.id)/discovery"),
              let token = AuthManager.shared.getAccessToken() else {
            isLoading = false; return
        }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")

        URLSession.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async {
                isLoading = false
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

                if let stats = json["stats"] as? [String: Any] {
                    totalDiscovered = stats["totalDiscovered"] as? Int ?? 0
                    totalOwned = stats["totalOwned"] as? Int ?? 0
                    areaKm2 = stats["estimatedAreaKm2"] as? String ?? "0"
                }

                if let hexData = json["hexData"] as? [String: Any],
                   let discoveredArr = hexData["discovered"] as? [[String: Any]] {
                    discoveredIslands = discoveredArr.compactMap { island in
                        guard let outerPts = island["outer"] as? [[String: Any]] else { return nil }
                        let outer = outerPts.compactMap { pt -> CLLocationCoordinate2D? in
                            guard let lat = pt["lat"] as? Double, let lng = pt["lng"] as? Double else { return nil }
                            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
                        }
                        let holes: [[CLLocationCoordinate2D]] = (island["holes"] as? [[[String: Any]]] ?? []).compactMap { holePts in
                            let ring = holePts.compactMap { pt -> CLLocationCoordinate2D? in
                                guard let lat = pt["lat"] as? Double, let lng = pt["lng"] as? Double else { return nil }
                                return CLLocationCoordinate2D(latitude: lat, longitude: lng)
                            }
                            return ring.count >= 3 ? ring : nil
                        }
                        return outer.count >= 3 ? DiscoveryIsland(outer: outer, holes: holes, hexColor: "#4CAF50") : nil
                    }
                    print("🗺️ Discovery: \(discoveredIslands.count) discovered islands loaded")
                }

                if let hexData = json["hexData"] as? [String: Any],
                   let ownedArr = hexData["owned"] as? [[String: Any]] {
                    ownedIslands = ownedArr.compactMap { island in
                        guard let outerPts = island["outer"] as? [[String: Any]] else { return nil }
                        let outer = outerPts.compactMap { pt -> CLLocationCoordinate2D? in
                            guard let lat = pt["lat"] as? Double, let lng = pt["lng"] as? Double else { return nil }
                            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
                        }
                        let holes: [[CLLocationCoordinate2D]] = (island["holes"] as? [[[String: Any]]] ?? []).compactMap { holePts in
                            let ring = holePts.compactMap { pt -> CLLocationCoordinate2D? in
                                guard let lat = pt["lat"] as? Double, let lng = pt["lng"] as? Double else { return nil }
                                return CLLocationCoordinate2D(latitude: lat, longitude: lng)
                            }
                            return ring.count >= 3 ? ring : nil
                        }
                        let color = island["hex_color"] as? String ?? "#651FFF"
                        return outer.count >= 3 ? DiscoveryIsland(outer: outer, holes: holes, hexColor: color) : nil
                    }
                    print("🗺️ Discovery: \(ownedIslands.count) owned islands loaded")
                }
            }
        }.resume()
    }
}

struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10)).foregroundColor(color)
                Text(value).font(.system(size: 16, weight: .bold)).foregroundColor(ThemeManager.shared.colors.textPrimary).monospacedDigit()
            }
            Text(label).font(.system(size: 9)).foregroundColor(ThemeManager.shared.colors.textPrimary.opacity(0.5))
        }
    }
}

struct TogglePill: View {
    let label: String
    let icon: String
    @Binding var isOn: Bool
    let color: Color

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { isOn.toggle() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(isOn ? .white : color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isOn ? color : color.opacity(0.15))
            .cornerRadius(8)
        }
    }
}

// MARK: - Discovery Map (MapKit)

struct DiscoveryMapContainer: UIViewRepresentable {
    let discoveredIslands: [PlayerDiscoveryMapView.DiscoveryIsland]
    let ownedIslands: [PlayerDiscoveryMapView.DiscoveryIsland]
    let playerColor: String
    let showDiscovered: Bool
    let showOwned: Bool
    let mapDarkness: Double

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.mapType = .satellite
        map.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 45.5019, longitude: -73.5674),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeOverlays(map.overlays)
        context.coordinator.parent = self

        // Dark overlay — controlled by slider
        if mapDarkness > 0.01 {
            let worldCoords: [CLLocationCoordinate2D] = [
                CLLocationCoordinate2D(latitude: -85, longitude: -180),
                CLLocationCoordinate2D(latitude: -85, longitude: 180),
                CLLocationCoordinate2D(latitude: 85, longitude: 180),
                CLLocationCoordinate2D(latitude: 85, longitude: -180)
            ]
            let darkPoly = MKPolygon(coordinates: worldCoords, count: worldCoords.count)
            darkPoly.title = "dark_\(mapDarkness)"
            map.addOverlay(darkPoly)
        }

        // Discovered islands — green
        if showDiscovered {
            for island in discoveredIslands {
                let holePoly = island.holes.map {
                    MKPolygon(coordinates: $0, count: $0.count)
                }
                let poly = MKPolygon(coordinates: island.outer, count: island.outer.count, interiorPolygons: holePoly)
                poly.title = "discovered"
                map.addOverlay(poly)
            }
        }

        // Owned islands — player color (on top)
        if showOwned {
            for island in ownedIslands {
                let holePoly = island.holes.map {
                    MKPolygon(coordinates: $0, count: $0.count)
                }
                let poly = MKPolygon(coordinates: island.outer, count: island.outer.count, interiorPolygons: holePoly)
                poly.title = "owned_\(island.hexColor)"
                map.addOverlay(poly)
            }
        }

        // Smart zoom — ONLY on first data load
        let allIslands = discoveredIslands + ownedIslands
        if !context.coordinator.hasZoomed && !allIslands.isEmpty {
            context.coordinator.hasZoomed = true
            let allCoords = allIslands.flatMap { $0.outer }
            let lats = allCoords.map { $0.latitude }
            let lngs = allCoords.map { $0.longitude }
            if let minLat = lats.min(), let maxLat = lats.max(),
               let minLng = lngs.min(), let maxLng = lngs.max() {
                let center = CLLocationCoordinate2D(
                    latitude: (minLat + maxLat) / 2,
                    longitude: (minLng + maxLng) / 2
                )
                let span = MKCoordinateSpan(
                    latitudeDelta: max((maxLat - minLat) * 1.4, 0.005),
                    longitudeDelta: max((maxLng - minLng) * 1.4, 0.005)
                )
                print("🗺️ DiscoveryMap: centering on (\(center.latitude), \(center.longitude)) span=(\(span.latitudeDelta), \(span.longitudeDelta))")
                map.setRegion(MKCoordinateRegion(center: center, span: span), animated: true)
            }
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: DiscoveryMapContainer
        var hasZoomed = false
        init(_ parent: DiscoveryMapContainer) { self.parent = parent }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                let title = polygon.title ?? ""

                if title == "discovered" {
                    renderer.fillColor = UIColor(red: 0.30, green: 0.85, blue: 0.35, alpha: 0.5)
                    renderer.strokeColor = UIColor(red: 0.30, green: 0.95, blue: 0.40, alpha: 0.9)
                    renderer.lineWidth = 1.5
                } else if title.hasPrefix("owned_") {
                    let hexColor = String(title.dropFirst(6))
                    let color = UIColor(Color(hex: hexColor))
                    renderer.fillColor = color.withAlphaComponent(0.65)
                    renderer.strokeColor = color.withAlphaComponent(1.0)
                    renderer.lineWidth = 2.5
                } else if title.hasPrefix("dark_") {
                    let opacity = Double(String(title.dropFirst(5))) ?? 0.3
                    renderer.fillColor = UIColor(red: 0.03, green: 0.03, blue: 0.08, alpha: CGFloat(opacity))
                    renderer.strokeColor = .clear
                }
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

