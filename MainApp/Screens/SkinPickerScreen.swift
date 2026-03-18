import SwiftUI

// MARK: - Data Models

struct SkinItem: Identifiable, Equatable {
    let id: String
    let name: String
    let color: String
    let tier: Int
    let owned: Bool
    let cost: Int
    let texture: String?
    let animation: String?
}

struct InventoryResult {
    let skins: [SkinItem]
    let equippedT1: String
    let equippedT2: String?
    let equippedT3: String?
}

// MARK: - Skin Picker Screen

struct SkinPickerScreen: View {
    var onBack: () -> Void

    @State private var skins: [SkinItem] = []
    @State private var isLoading = true
    @State private var isEquipping: String? = nil
    @State private var errorMsg: String? = nil

    // Layered selection: T1 mandatory, T2/T3 optional toggles
    @State private var selectedT1: SkinItem? = nil
    @State private var selectedT2: SkinItem? = nil
    @State private var selectedT3: SkinItem? = nil

    // Label
    @State private var hexLabel = ""
    @State private var labelStyle: Int = 0 // 0=simple, 1=bold, 2=inverted

    // Snackbar
    @State private var snackbarMessage: String? = nil

    // Colors
    private let accentColor = Color(hex: "#00FF88")
    private let bgColor = Color(hex: "#0F0F23")
    private let surfaceColor = Color(hex: "#1A1A2E")
    private let borderColor = Color(hex: "#2A2A4A")
    private let mutedText = Color(hex: "#666680")

    var body: some View {
        VStack(spacing: 0) {
            // ⚠️ IMPORTANT: Use Rectangle with FIXED height, NOT Color.clear.frame(width:).
            // Color.clear without a height constraint expands infinitely in a VStack.

            // Header
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                Spacer()
                Text("HEX SKINS")
                    .font(.system(size: 18, weight: .bold))
                    .tracking(2)
                    .foregroundColor(.white)
                Spacer()
                Rectangle().fill(Color.clear).frame(width: 20, height: 20)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            if isLoading {
                Spacer()
                ProgressView().tint(accentColor)
                Spacer()
            } else if let error = errorMsg {
                Spacer()
                Text(error).foregroundColor(.red).multilineTextAlignment(.center).padding()
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // ═══ HEX PREVIEW ═══
                        hexPreviewSection

                        // ═══ LABEL / TAG ═══
                        labelSection

                        // ═══ T1: COULEURS ═══
                        tierSection(title: "🎨 Couleurs", subtitle: nil, skins: skins.filter { $0.tier == 1 }, tier: 1)

                        // ═══ T2: PATTERNS ═══
                        let t2 = skins.filter { $0.tier == 2 }
                        if !t2.isEmpty {
                            tierSection(title: "🗺️ Patterns", subtitle: "Tap pour activer/désactiver", skins: t2, tier: 2)
                        }

                        // ═══ T3: ANIMATIONS ═══
                        let t3 = skins.filter { $0.tier == 3 }
                        if !t3.isEmpty {
                            tierSection(title: "✨ Animations", subtitle: "Tap pour activer/désactiver", skins: t3, tier: 3)
                        }

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .background(bgColor.ignoresSafeArea())
        .onAppear { loadInventory() }
        .overlay(alignment: .bottom) {
            if let msg = snackbarMessage {
                Text(msg)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#333333").cornerRadius(12))
                    .padding(.bottom, 30)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation { snackbarMessage = nil }
                        }
                    }
            }
        }
    }

    // MARK: - Hex Preview

    private var hexPreviewSection: some View {
        HStack {
            Spacer()
            ZStack {
                // Hexagon shape
                HexagonShape()
                    .fill(Color(hex: selectedT1?.color ?? "#00FF88").opacity(0.6))
                    .frame(width: 90, height: 90)

                if !hexLabel.isEmpty {
                    Text(hexLabel)
                        .font(.system(size: 22, weight: .black))
                        .tracking(2)
                        .foregroundColor(.white)
                }
            }
            Spacer()
        }
        .frame(height: 130)
        .background(surfaceColor)
        .cornerRadius(16)
        .padding(.bottom, 12)
    }

    // MARK: - Label Section

    private var labelSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("✏️ TAG")
                .font(.system(size: 14, weight: .bold))
                .tracking(1)
                .foregroundColor(.white)

            TextField("3 lettres max", text: $hexLabel)
                .onChange(of: hexLabel) { newValue in
                    if newValue.count > 3 {
                        hexLabel = String(newValue.prefix(3))
                    }
                    hexLabel = hexLabel.uppercased()
                }
                .font(.system(size: 24, weight: .black))
                .tracking(4)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: 1)
                )

            // Label style selector
            HStack(spacing: 8) {
                LabelStyleCard(label: "Simple", styleIndex: 0, selectedStyle: labelStyle) { labelStyle = $0 }
                LabelStyleCard(label: "Gras", styleIndex: 1, selectedStyle: labelStyle) { labelStyle = $0 }
                LabelStyleCard(label: "Inversé", styleIndex: 2, selectedStyle: labelStyle) { labelStyle = $0 }
            }
            .padding(.top, 4)
        }
        .padding(.bottom, 16)
    }

    // MARK: - Tier Section

    private func tierSection(title: String, subtitle: String?, skins: [SkinItem], tier: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider().background(borderColor)
            Spacer().frame(height: 12)

            Text(title)
                .font(.system(size: 14, weight: .bold))
                .tracking(1)
                .foregroundColor(.white)

            if let sub = subtitle {
                Text(sub)
                    .font(.system(size: 11))
                    .foregroundColor(mutedText)
            }

            Spacer().frame(height: 8)

            // 3-column grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(skins) { skin in
                    SkinCardView(
                        skin: skin,
                        isEquipped: isEquippedSkin(skin, tier: tier),
                        isLoading: isEquipping == skin.id
                    ) {
                        handleSkinTap(skin, tier: tier)
                    }
                }
            }

            Spacer().frame(height: 8)
        }
    }

    // MARK: - Logic

    private func isEquippedSkin(_ skin: SkinItem, tier: Int) -> Bool {
        switch tier {
        case 1: return skin.id == selectedT1?.id
        case 2: return skin.id == selectedT2?.id
        case 3: return skin.id == selectedT3?.id
        default: return false
        }
    }

    private func handleSkinTap(_ skin: SkinItem, tier: Int) {
        guard skin.owned, isEquipping == nil else { return }

        if tier == 1 {
            guard skin.id != selectedT1?.id else { return }
            isEquipping = skin.id
            equipSkinAPI(skinId: skin.id) { success in
                if success {
                    selectedT1 = skin
                    syncToUnity()
                }
                isEquipping = nil
            }
        } else {
            // T2/T3: toggle on/off
            let currentSelected = tier == 2 ? selectedT2 : selectedT3
            let willDeselect = currentSelected?.id == skin.id
            isEquipping = skin.id

            if willDeselect {
                clearLayerAPI(tier: tier) { success in
                    if success {
                        if tier == 2 { selectedT2 = nil } else { selectedT3 = nil }
                        syncToUnity()
                    }
                    isEquipping = nil
                }
            } else {
                equipSkinAPI(skinId: skin.id) { success in
                    if success {
                        if tier == 2 { selectedT2 = skin } else { selectedT3 = skin }
                        syncToUnity()
                    }
                    isEquipping = nil
                }
            }
        }
    }

    private func syncToUnity() {
        if let t1 = selectedT1 {
            CaptureState.shared.setPlayerHexColor(t1.color)
        }
        CaptureState.shared.setPlayerSkinTexture(selectedT2?.texture)
        CaptureState.shared.setPlayerSkinAnimation(selectedT3?.animation)

        // Persist locally
        UserDefaults.standard.set(selectedT1?.id, forKey: "equipped_t1_id")
        UserDefaults.standard.set(selectedT1?.color, forKey: "equipped_t1_color")
        UserDefaults.standard.set(selectedT2?.id, forKey: "equipped_t2_id")
        UserDefaults.standard.set(selectedT2?.texture, forKey: "equipped_t2_texture")
        UserDefaults.standard.set(selectedT3?.id, forKey: "equipped_t3_id")
        UserDefaults.standard.set(selectedT3?.animation, forKey: "equipped_t3_animation")
    }

    // MARK: - API Calls

    private func loadInventory() {
        guard let token = AuthManager.shared.getAccessToken() else {
            isLoading = false
            errorMsg = "Non authentifié"
            return
        }
        let baseUrl = AppState.shared.backendBaseUrl

        // Fetch inventory
        guard let url = URL(string: "\(baseUrl)/v1/skins/inventory") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 8

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data,
                      let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                    errorMsg = "Erreur de chargement (\(code))"
                    isLoading = false
                    return
                }

                // Parse equipped
                let equipped = json["equipped"] as? [String: Any]
                let equippedT1 = equipped?["t1"] as? String ?? "default_green"
                let equippedT2 = equipped?["t2"] as? String
                let equippedT3 = equipped?["t3"] as? String

                // Parse skins
                guard let skinsArray = json["skins"] as? [[String: Any]] else {
                    errorMsg = "Format de données invalide"
                    isLoading = false
                    return
                }

                var parsedSkins: [SkinItem] = []
                for s in skinsArray {
                    parsedSkins.append(SkinItem(
                        id: s["id"] as? String ?? "",
                        name: s["name"] as? String ?? "",
                        color: s["color"] as? String ?? "#00FF88",
                        tier: s["tier"] as? Int ?? 1,
                        owned: s["owned"] as? Bool ?? true,
                        cost: s["cost"] as? Int ?? 0,
                        texture: s["texture"] as? String,
                        animation: s["animation"] as? String
                    ))
                }

                skins = parsedSkins
                selectedT1 = parsedSkins.first { $0.id == equippedT1 && $0.tier == 1 }
                    ?? parsedSkins.first { $0.id == "default_green" }
                selectedT2 = equippedT2 != nil ? parsedSkins.first { $0.id == equippedT2 && $0.tier == 2 } : nil
                selectedT3 = equippedT3 != nil ? parsedSkins.first { $0.id == equippedT3 && $0.tier == 3 } : nil

                syncToUnity()
                isLoading = false

                // Also load hex label from profile
                loadHexLabel(token: token, baseUrl: baseUrl)

                print("🎨 SkinPicker: Loaded \(parsedSkins.count) skins, T1=\(equippedT1) T2=\(equippedT2 ?? "nil") T3=\(equippedT3 ?? "nil")")
            }
        }.resume()
    }

    private func loadHexLabel(token: String, baseUrl: String) {
        guard let url = URL(string: "\(baseUrl)/v1/players/me") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 5

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let label = json["hexLabel"] as? String, label != "null" else { return }
            DispatchQueue.main.async { hexLabel = label }
        }.resume()
    }

    private func equipSkinAPI(skinId: String, completion: @escaping (Bool) -> Void) {
        guard let token = AuthManager.shared.getAccessToken() else { completion(false); return }
        let baseUrl = AppState.shared.backendBaseUrl
        guard let url = URL(string: "\(baseUrl)/v1/skins/equip") else { completion(false); return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["skinId": skinId])
        request.timeoutInterval = 8

        URLSession.shared.dataTask(with: request) { data, response, _ in
            DispatchQueue.main.async {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                if code == 200 {
                    completion(true)
                } else {
                    let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    print("❌ Equip failed: \(code) — \(body)")
                    withAnimation { snackbarMessage = "Erreur equip (\(code))" }
                    completion(false)
                }
            }
        }.resume()
    }

    private func clearLayerAPI(tier: Int, completion: @escaping (Bool) -> Void) {
        guard let token = AuthManager.shared.getAccessToken() else { completion(false); return }
        let baseUrl = AppState.shared.backendBaseUrl
        guard let url = URL(string: "\(baseUrl)/v1/skins/equip") else { completion(false); return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["tier": tier])
        request.timeoutInterval = 8

        URLSession.shared.dataTask(with: request) { data, response, _ in
            DispatchQueue.main.async {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                if code == 200 {
                    completion(true)
                } else {
                    print("❌ Clear layer failed: \(code)")
                    withAnimation { snackbarMessage = "Erreur clear T\(tier)" }
                    completion(false)
                }
            }
        }.resume()
    }
}

// MARK: - Skin Card

struct SkinCardView: View {
    let skin: SkinItem
    let isEquipped: Bool
    let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: skin.color), Color(hex: skin.color).opacity(0.7)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 24
                            )
                        )
                        .frame(width: 48, height: 48)
                        .shadow(color: Color(hex: skin.color).opacity(0.4), radius: 8)

                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.7)
                    } else if isEquipped {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    } else if !skin.owned {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                Text(skin.name)
                    .font(.system(size: 11, weight: isEquipped ? .bold : .regular))
                    .foregroundColor(skin.owned ? .white : Color(hex: "#666680"))
                    .lineLimit(1)

                if skin.tier >= 2 {
                    Text("T\(skin.tier)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(hex: "#FFD600"))
                }

                if isEquipped {
                    Text(skin.tier == 1 ? "ÉQUIPÉ" : "ACTIF")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(hex: "#00FF88"))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "#1A1A2E"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isEquipped ? Color(hex: "#00FF88") : Color(hex: "#2A2A4A"), lineWidth: 2)
                    )
            )
        }
        .disabled(!skin.owned || isLoading)
    }
}

// MARK: - Label Style Card

struct LabelStyleCard: View {
    let label: String
    let styleIndex: Int
    let selectedStyle: Int
    let onSelect: (Int) -> Void

    private var isSelected: Bool { styleIndex == selectedStyle }

    var body: some View {
        Button { onSelect(styleIndex) } label: {
            VStack(spacing: 4) {
                Group {
                    switch styleIndex {
                    case 0:
                        Text("ABC").font(.system(size: 14)).foregroundColor(.white)
                    case 1:
                        Text("ABC").font(.system(size: 14, weight: .black)).tracking(2).foregroundColor(.white)
                    case 2:
                        Text("ABC")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "#0F0F23"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(4)
                    default:
                        EmptyView()
                    }
                }

                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? Color(hex: "#00FF88") : Color(hex: "#888899"))

                if isSelected {
                    Text("✓")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#00FF88"))
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(hex: "#1A2E1A") : Color(hex: "#1A1A2E"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color(hex: "#00FF88") : Color(hex: "#2A2A4A"), lineWidth: 2)
                    )
            )
        }
    }
}

// MARK: - Hexagon Shape

struct HexagonShape: Shape {
    func path(in rect: CGRect) -> SwiftUI.Path {
        var path = SwiftUI.Path()
        let cx = rect.midX
        let cy = rect.midY
        let r = min(rect.width, rect.height) / 2 * 0.9

        for i in 0..<6 {
            let angle = Double(i) * 60.0 - 30.0
            let rad = angle * .pi / 180.0
            let x = cx + r * CGFloat(cos(rad))
            let y = cy + r * CGFloat(sin(rad))
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}
