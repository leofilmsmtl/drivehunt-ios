// FortressScreen.swift — 1:1 port of Android FortressScreen.kt
import SwiftUI

// MARK: - Color Palette (mirrors Android FortressScreen.kt)
private let fortressDark = Color(red: 0x0D/255, green: 0x0D/255, blue: 0x0D/255)
private let fortressSurface = Color(red: 0x1A/255, green: 0x1A/255, blue: 0x1A/255)
private let fortressCard = Color(red: 0x22/255, green: 0x22/255, blue: 0x22/255)
private let fortressGold = Color(red: 0xD4/255, green: 0xAF/255, blue: 0x37/255)
private let fortressBronze = Color(red: 0xCD/255, green: 0x7F/255, blue: 0x32/255)
private let fortressSteel = Color(red: 0x8A/255, green: 0x9B/255, blue: 0xA8/255)
private let fortressRed = Color(red: 0xE5/255, green: 0x39/255, blue: 0x35/255)
private let fortressGreen = Color(red: 0x43/255, green: 0xA0/255, blue: 0x47/255)
private let fortressBlue = Color(red: 0x1E/255, green: 0x88/255, blue: 0xE5/255)

struct FortressScreen: View {
    @ObservedObject private var state = FortressState.shared
    @State private var showBuildConfirm: FortressCluster? = nil
    @State private var showDestroyConfirm = false

    let onBack: () -> Void

    var body: some View {
        ZStack {
            fortressDark.ignoresSafeArea()

            if state.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: fortressGold))
                    .scaleEffect(1.5)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Hero Header
                        fortressHeader

                        if let fortress = state.fortress {
                            // Fortress Status Card
                            fortressStatusCard(fortress)

                            // Section: Hexagones du cluster
                            sectionTitle("HEXAGONES DU CLUSTER")

                            ForEach(fortress.hexes) { hex in
                                hexCard(hex)
                            }

                            // Destroy Button
                            Spacer().frame(height: 24)
                            destroyButton
                        } else {
                            // No fortress — show available clusters
                            sectionTitle("CLUSTERS DISPONIBLES")

                            if state.clusters.isEmpty {
                                noClustersMessage
                            } else {
                                Text("Sélectionne un cluster de 3 hexagones pour construire ta forteresse")
                                    .font(.system(size: 13))
                                    .foregroundColor(fortressSteel.opacity(0.7))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 4)

                                ForEach(Array(state.clusters.enumerated()), id: \.element.id) { index, cluster in
                                    clusterCard(cluster: cluster, index: index)
                                }
                            }
                        }

                        Spacer().frame(height: 32)
                    }
                }
            }

            // Back Button
            VStack {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(16)
                    Spacer()
                }
                Spacer()
            }
        }
        .task {
            await state.loadData()
        }
        // Build Confirmation
        .alert("CONSTRUIRE LA FORTERESSE", isPresented: Binding(
            get: { showBuildConfirm != nil },
            set: { if !$0 { showBuildConfirm = nil } }
        )) {
            Button("Annuler", role: .cancel) { showBuildConfirm = nil }
            Button("CONSTRUIRE") {
                guard let cluster = showBuildConfirm else { return }
                Task {
                    await MainActor.run { state.isBuilding = true }
                    let hexIds = cluster.hexes.map { $0.h3Index }
                    _ = await state.buildFortress(hexIndices: hexIds, tier: cluster.tier)
                    await MainActor.run { state.isBuilding = false }
                    showBuildConfirm = nil
                }
            }
            .disabled(state.isBuilding)
        } message: {
            if let cluster = showBuildConfirm {
                Text("Tu es sur le point de construire une citadelle de Tier \(cluster.tier) avec \(cluster.hexes.count) hexagones.\n\n⚠️  Tu ne peux avoir qu'une seule forteresse.")
            }
        }
        // Destroy Confirmation
        .alert("DÉTRUIRE LA FORTERESSE", isPresented: $showDestroyConfirm) {
            Button("Annuler", role: .cancel) { }
            Button("DÉTRUIRE", role: .destructive) {
                Task {
                    await MainActor.run { state.isDestroying = true }
                    let success = await state.destroyFortress()
                    if success {
                        await state.fetchClusters()
                    }
                    await MainActor.run { state.isDestroying = false }
                }
            }
            .disabled(state.isDestroying)
        } message: {
            Text("Es-tu sûr de vouloir détruire ta forteresse ? Cette action est irréversible.")
        }
    }

    // ═══════════════════════════════════════════
    // HERO HEADER
    // ═══════════════════════════════════════════

    private var fortressHeader: some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(
                colors: [Color(red: 0x1B/255, green: 0x28/255, blue: 0x38/255), fortressDark],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 200)

            VStack(alignment: .leading, spacing: 4) {
                Spacer()

                Text(state.fortress != nil ? "MA FORTERESSE" : "FORTERESSES")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(fortressGold)
                    .tracking(3)

                if let f = state.fortress {
                    Text("Tier \(f.tier) — \(f.status.uppercased())")
                        .font(.system(size: 14))
                        .foregroundColor(fortressSteel.opacity(0.7))
                        .tracking(1)
                } else {
                    Text("Construis ta citadelle")
                        .font(.system(size: 14))
                        .foregroundColor(fortressSteel.opacity(0.7))
                        .tracking(1)
                }

                Spacer().frame(height: 16)

                if let f = state.fortress {
                    HStack {
                        Spacer()
                        statusBadge(f.status)
                    }
                }
            }
            .padding(.top, 56)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(height: 200)
    }

    private func statusBadge(_ status: String) -> some View {
        let config: (Color, String, String) = {
            switch status {
            case "active": return (fortressGreen, "shield.fill", "ACTIVE")
            case "breached": return (fortressRed, "exclamationmark.triangle.fill", "BRÈCHE")
            case "ruined": return (fortressSteel, "xmark.circle.fill", "RUINES")
            default: return (fortressSteel, "xmark", "DÉTRUITE")
            }
        }()

        return HStack(spacing: 6) {
            Image(systemName: config.1)
                .font(.system(size: 12))
                .foregroundColor(config.0)
            Text(config.2)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(config.0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(config.0.opacity(0.15))
        .cornerRadius(8)
    }

    // ═══════════════════════════════════════════
    // FORTRESS STATUS CARD
    // ═══════════════════════════════════════════

    private func fortressStatusCard(_ fortress: Fortress) -> some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                statItem(label: "TIER", value: "\(fortress.tier)", icon: "star.fill", color: fortressGold)
                Spacer()
                statItem(label: "HEXES", value: "\(fortress.hexes.count)", icon: "hexagon.fill", color: fortressBlue)
                Spacer()
                statItem(label: "SKIN", value: fortress.skinId.replacingOccurrences(of: "_", with: " ").capitalized, icon: "paintpalette.fill", color: fortressBronze)
                Spacer()
            }

            if fortress.status == "breached" {
                Spacer().frame(height: 12)
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(fortressRed)
                        .font(.system(size: 16))
                    Text("Forteresse percée ! Reconquiers l'hexagone perdu dans les 24h.")
                        .font(.system(size: 12))
                        .foregroundColor(fortressRed)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(fortressRed.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(fortressCard)
        .cornerRadius(16)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func statItem(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 20))
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(fortressSteel.opacity(0.6))
                .tracking(1)
        }
    }

    // ═══════════════════════════════════════════
    // HEX CARD
    // ═══════════════════════════════════════════

    private func hexCard(_ hex: FortressHex) -> some View {
        let roleConfig: (Color, String, String) = {
            switch hex.role {
            case "core": return (fortressGold, "building.columns.fill", "DONJON")
            case "gate": return (fortressBronze, "door.left.hand.open", "PORTE")
            default: return (fortressSteel, "square.grid.3x3.fill", "MUR")
            }
        }()

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(roleConfig.0.opacity(0.15))
                    .overlay(Circle().stroke(roleConfig.0.opacity(0.3), lineWidth: 1))
                Image(systemName: roleConfig.1)
                    .foregroundColor(roleConfig.0)
                    .font(.system(size: 14))
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(roleConfig.2)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(roleConfig.0)
                    .tracking(1)
                Text("H3: \(String(hex.h3Index.suffix(8)))...")
                    .font(.system(size: 11))
                    .foregroundColor(fortressSteel.opacity(0.5))
            }

            Spacer()
        }
        .padding(12)
        .background(fortressSurface)
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 3)
    }

    // ═══════════════════════════════════════════
    // CLUSTER CARD
    // ═══════════════════════════════════════════

    private func clusterCard(cluster: FortressCluster, index: Int) -> some View {
        Button {
            showBuildConfirm = cluster
        } label: {
            HStack(spacing: 14) {
                // Cluster number badge
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: [fortressGold, fortressBronze], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    Text("\(index + 1)")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(.black)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Cluster #\(index + 1)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text("\(cluster.hexes.count) hexagones • Tier \(cluster.tier)")
                        .font(.system(size: 12))
                        .foregroundColor(fortressSteel.opacity(0.6))
                }

                Spacer()

                Text("CONSTRUIRE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(fortressGold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(fortressGold.opacity(0.15))
                    .cornerRadius(8)
            }
            .padding(16)
            .background(fortressCard)
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    // ═══════════════════════════════════════════
    // UTILITY VIEWS
    // ═══════════════════════════════════════════

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(fortressSteel.opacity(0.5))
            .tracking(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }

    private var noClustersMessage: some View {
        VStack(spacing: 12) {
            Image(systemName: "hammer.fill")
                .foregroundColor(fortressSteel.opacity(0.4))
                .font(.system(size: 40))
            Text("Aucun cluster disponible")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(fortressSteel.opacity(0.6))
            Text("Capture 3 hexagones adjacents pour débloquer un emplacement de forteresse.")
                .font(.system(size: 13))
                .foregroundColor(fortressSteel.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }

    private var destroyButton: some View {
        Button(action: { showDestroyConfirm = true }) {
            HStack(spacing: 6) {
                Image(systemName: "trash.fill")
                    .foregroundColor(fortressRed.opacity(0.5))
                    .font(.system(size: 12))
                Text("Détruire ma forteresse")
                    .font(.system(size: 12))
                    .foregroundColor(fortressRed.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }
}
