import SwiftUI

// MARK: - Data Models

struct LootRollData {
    let gemType: String      // quartz, jade, saphir, ruby, arcane, mystere
    let baseTier: String     // "dark" (normal) or "gold" (boosts rare loot)
    let gemId: String
    let serverRarity: String // Server-authoritative rarity: common, rare, epic
}

struct LootRollResult {
    let rarity: String       // common, rare, epic
    let gemType: String
    let baseTier: String
}

// MARK: - Colors & Config

private let gemColorsMap: [String: Color] = [
    "quartz":  Color(hex: "#D9D2C0"),
    "jade":    Color(hex: "#2DBF73"),
    "saphir":  Color(hex: "#2659F2"),
    "ruby":    Color(hex: "#E61A26"),
    "arcane":  Color(hex: "#B333F2"),
    "mystere": Color(hex: "#FF6B6B"),
]

private let gemLabels: [String: String] = [
    "quartz": "QUARTZ", "jade": "JADE", "saphir": "SAPHIR",
    "ruby": "RUBY", "arcane": "ARCANE", "mystere": "MYSTÈRE",
]

private let rarityColors: [String: Color] = [
    "common": Color(hex: "#AABBCC"),
    "rare":   Color(hex: "#FFD700"),
    "epic":   Color(hex: "#FF4444"),
]

private let rarityLabels: [String: String] = [
    "common": "COMMUN",
    "rare":   "RARE ⭐",
    "epic":   "ÉPIQUE 💎",
]

// MARK: - Casino Roll Overlay

struct CasinoRollOverlay: View {
    let rollData: LootRollData
    let onRollComplete: (LootRollResult) -> Void
    let onDismiss: () -> Void

    @State private var phase: Int = 0
    // 0=entering, 1=plate, 2=spinner, 3=scanning, 4=reveal, 5=result, 6=closeable

    @State private var rolledRarity: String = "common"
    @State private var scanIndex: Int = -1
    @State private var winnerIndex: Int = -1

    private var gemColor: Color { gemColorsMap[rollData.gemType] ?? .white }
    private var gemLabel: String { gemLabels[rollData.gemType] ?? "" }
    private var rarityColor: Color { rarityColors[rolledRarity] ?? .white }

    var body: some View {
        ZStack {
            // === Scrim ===
            Color.black.opacity(phase >= 0 ? 0.88 : 0)
                .ignoresSafeArea()
                .animation(.easeIn(duration: 0.5), value: phase)

            // === Edge glow ===
            if phase >= 4 {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(rarityColor.opacity(0.6), lineWidth: 2)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            // === Content ===
            VStack(spacing: 24) {
                // ── Base plate + gem ──
                ZStack {
                    Circle()
                        .fill(
                            rollData.baseTier == "gold"
                            ? LinearGradient(colors: [Color(hex: "#FFD700"), Color(hex: "#B8860B")], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [Color(hex: "#3A3A4E"), Color(hex: "#1A1A2E")], startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: 180, height: 180)

                    // Diamond gem shape
                    if phase >= 1 {
                        DiamondGemShape(color: gemColor)
                            .frame(width: 80, height: 80)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .scaleEffect(phase >= 1 ? 1.0 : 0.3)
                .opacity(phase >= 1 ? 1.0 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: phase)

                // ── Bonus hint ──
                if phase >= 1 {
                    if let hint = bonusHint {
                        Text(hint.text)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(hint.color)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)
                            .transition(.opacity)
                    }
                }

                // ── Rarity spinner ──
                if phase >= 2 {
                    HStack(spacing: 12) {
                        ForEach(Array(["common", "rare", "epic"].enumerated()), id: \.offset) { idx, key in
                            let label = key == "common" ? "COMMUN" : (key == "rare" ? "RARE" : "ÉPIQUE")
                            let slotColor = rarityColors[key] ?? .white
                            let isScanning = scanIndex == idx
                            let isWinner = winnerIndex == idx

                            Text(label)
                                .font(.system(size: 12, weight: .heavy))
                                .tracking(1)
                                .foregroundColor(slotColor.opacity(isWinner || isScanning ? 1.0 : 0.3))
                                .frame(width: 80, height: 42)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(slotColor.opacity(isScanning || isWinner ? 0.1 : 0.03))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(slotColor.opacity(isScanning || isWinner ? 0.8 : 0), lineWidth: 2)
                                )
                                .scaleEffect(isWinner ? 1.15 : (isScanning ? 1.1 : 1.0))
                                .animation(.spring(response: 0.2), value: scanIndex)
                                .animation(.spring(response: 0.3), value: winnerIndex)
                        }
                    }
                    .transition(.opacity)
                }

                // ── Result text ──
                if phase >= 5 {
                    VStack(spacing: 8) {
                        Text("\(gemLabel) \(rarityLabels[rolledRarity] ?? "")")
                            .font(.system(size: 26, weight: .black))
                            .tracking(2)
                            .foregroundColor(rarityColor)
                            .scaleEffect(phase >= 5 ? 1.0 : 0.5)
                            .animation(.spring(response: 0.4, dampingFraction: 0.5), value: phase)

                        Text("\(rollData.baseTier == "gold" ? "Base Épique 🌟" : "Base Normale") • Ajouté à l'inventaire")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .transition(.opacity)
                }

                // ── Close button ──
                if phase >= 6 {
                    Button {
                        onDismiss()
                    } label: {
                        Text("FERMER")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(2)
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                    )
                            )
                    }
                    .transition(.opacity)
                }
            }
        }
        .onTapGesture {
            if phase >= 6 { onDismiss() }
        }
        .onAppear { startRollAnimation() }
    }

    // MARK: - Bonus Hint

    private var bonusHint: (text: String, color: Color)? {
        if rollData.gemType == "mystere" {
            return ("🌈 MYSTÈRE!  60% Rare, 40% Épique!", Color(hex: "#CC44FF"))
        } else if rollData.baseTier == "gold" {
            return ("✨ BONUS!  30% Rare, 20% Épique!", Color(hex: "#FFD700"))
        }
        return nil
    }

    // MARK: - Roll Animation

    private func startRollAnimation() {
        // Determine rarity
        let finalRarity: String
        if !rollData.serverRarity.isEmpty {
            finalRarity = rollData.serverRarity
        } else {
            let roll = Double.random(in: 0...1)
            if rollData.gemType == "mystere" {
                finalRarity = roll < 0.60 ? "rare" : "epic"
            } else if rollData.baseTier == "gold" {
                if roll < 0.50 { finalRarity = "common" }
                else if roll < 0.80 { finalRarity = "rare" }
                else { finalRarity = "epic" }
            } else {
                if roll < 0.90 { finalRarity = "common" }
                else if roll < 0.98 { finalRarity = "rare" }
                else { finalRarity = "epic" }
            }
        }

        let targetIdx: Int
        switch finalRarity {
        case "common": targetIdx = 0
        case "rare": targetIdx = 1
        default: targetIdx = 2
        }

        rolledRarity = finalRarity

        // Animation sequence
        Task { @MainActor in
            // STEP 1 — enter
            haptic(.light)
            try? await Task.sleep(nanoseconds: 400_000_000)

            // STEP 2 — plate
            withAnimation { phase = 1 }
            haptic(.medium)
            try? await Task.sleep(nanoseconds: 700_000_000)

            // STEP 3 — spinner
            withAnimation { phase = 2 }
            try? await Task.sleep(nanoseconds: 300_000_000)

            // STEP 4 — scanning
            phase = 3
            // Fast scans (3 cycles)
            for cycle in 0...2 {
                for i in 0...2 {
                    withAnimation { scanIndex = i }
                    haptic(.light)
                    try? await Task.sleep(nanoseconds: UInt64((120 + cycle * 50)) * 1_000_000)
                }
            }
            // Slow down to target
            for i in 0...targetIdx {
                withAnimation { scanIndex = i }
                haptic(.medium)
                try? await Task.sleep(nanoseconds: UInt64((250 + i * 100)) * 1_000_000)
            }

            // STEP 5 — REVEAL
            withAnimation {
                phase = 4
                scanIndex = -1
                winnerIndex = targetIdx
            }
            hapticReveal(finalRarity)
            try? await Task.sleep(nanoseconds: 400_000_000)

            // STEP 6 — result text
            withAnimation { phase = 5 }
            try? await Task.sleep(nanoseconds: 500_000_000)

            // Notify
            onRollComplete(LootRollResult(rarity: finalRarity, gemType: rollData.gemType, baseTier: rollData.baseTier))
            haptic(.light)
            try? await Task.sleep(nanoseconds: 300_000_000)

            // STEP 7 — closeable
            withAnimation { phase = 6 }
        }
    }

    // MARK: - Haptics

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private func hapticReveal(_ rarity: String) {
        switch rarity {
        case "epic":
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
        case "rare":
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        default:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
}

// MARK: - Diamond Gem Shape

struct DiamondGemShape: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let cx = size.width / 2
            let cy = size.height / 2
            let r = size.width * 0.42

            // Outer diamond
            var diamond = Path()
            diamond.move(to: CGPoint(x: cx, y: cy - r))
            diamond.addLine(to: CGPoint(x: cx + r, y: cy))
            diamond.addLine(to: CGPoint(x: cx, y: cy + r))
            diamond.addLine(to: CGPoint(x: cx - r, y: cy))
            diamond.closeSubpath()
            context.fill(diamond, with: .color(color))

            // Inner facet
            let ir = r * 0.58
            var inner = Path()
            inner.move(to: CGPoint(x: cx, y: cy - ir))
            inner.addLine(to: CGPoint(x: cx + ir, y: cy))
            inner.addLine(to: CGPoint(x: cx, y: cy + ir))
            inner.addLine(to: CGPoint(x: cx - ir, y: cy))
            inner.closeSubpath()
            context.fill(inner, with: .color(color.opacity(0.6)))

            // Highlight
            var highlight = Path()
            highlight.move(to: CGPoint(x: cx, y: cy - r))
            highlight.addLine(to: CGPoint(x: cx - r, y: cy))
            highlight.addLine(to: CGPoint(x: cx - ir, y: cy))
            highlight.addLine(to: CGPoint(x: cx, y: cy - ir))
            highlight.closeSubpath()
            context.fill(highlight, with: .color(.white.opacity(0.3)))
        }
    }
}
