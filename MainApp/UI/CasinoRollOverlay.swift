import SwiftUI

// MARK: - Data Models

struct LootRollData {
    let gemType: String      // quartz, jade, saphir, ruby, arcane
    let baseTier: String     // "dark" (normal) or "gold" (boosts rare loot)
    let gemId: String
    let serverRarity: String
}

struct LootRollResult {
    let gemType: String
    let baseTier: String
}

// MARK: - v5.1 Gem Tier Colors — match Kotlin exactly

private let GEM_COLORS: [String: Color] = [
    "quartz": Color(red: 0.75, green: 0.77, blue: 0.82),   // #C0C5D0
    "jade":   Color(red: 0.29, green: 0.87, blue: 0.50),   // #4ADE80
    "saphir": Color(red: 0.23, green: 0.51, blue: 0.96),   // #3B82F6
    "ruby":   Color(red: 0.94, green: 0.27, blue: 0.27),   // #EF4444
    "arcane": Color(red: 0.66, green: 0.33, blue: 0.97),   // #A855F7
]

private let GEM_TIERS = ["quartz", "jade", "saphir", "ruby", "arcane"]
private let GEM_LABELS = ["QUARTZ", "JADE", "SAPHIR", "RUBY", "ARCANE"]

// MARK: - Casino Roll Overlay (v5.1 — matches Kotlin exactly)

struct CasinoRollOverlay: View {
    let rollData: LootRollData
    let onDismiss: () -> Void

    @State private var phase: Int = 0
    @State private var scanIndex: Int = -1
    @State private var winnerIndex: Int = -1
    @State private var currentGemColor: Color = Color(red: 1, green: 0.42, blue: 0.42)
    @State private var showFlash = false
    @State private var isArcaneShake = false
    @State private var shakeOffset: CGSize = .zero

    private var gemColor: Color { GEM_COLORS[rollData.gemType] ?? .white }
    private var targetIdx: Int { max(0, GEM_TIERS.firstIndex(of: rollData.gemType) ?? 0) }
    private var gemLabel: String { GEM_LABELS.indices.contains(targetIdx) ? GEM_LABELS[targetIdx] : "QUARTZ" }

    var body: some View {
        ZStack {
            // ── Scrim ──
            Color.black.opacity(phase >= 1 ? 0.85 : 0)
                .animation(.easeInOut(duration: 0.6), value: phase)
                .ignoresSafeArea()

            // ── Screen flash ──
            if showFlash {
                gemColor.opacity(0.7)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            // ── Edge glow (4 edges) ──
            if phase >= 4 {
                EdgeGlowView(color: gemColor)
                    .opacity(0.6)
                    .transition(.opacity)
                    .ignoresSafeArea()
            }

            // ── Main content ──
            VStack(spacing: 0) {
                Spacer()

                // Spotlight cone
                SpotlightCone(color: gemColor)
                    .frame(width: 200, height: 140)
                    .opacity(phase >= 4 ? spotIntensity * 2 : 0)
                    .animation(.easeInOut(duration: 0.5), value: phase)

                // Base plate + gem diamond
                ZStack {
                    // Background glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    phase >= 4 ? gemColor.opacity(spotIntensity) : Color(white: 0.25, opacity: 0.5),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)

                    // Gem diamond
                    GemDiamondView(
                        color: currentGemColor,
                        size: phase >= 4 ? 100 : 80,
                        showGlow: phase >= 4
                    )
                }
                .scaleEffect(phase >= 1 ? 1 : 0.3)
                .opacity(phase >= 1 ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: phase)

                // Gold plaque hint
                if rollData.baseTier == "gold" {
                    Text("✨ PLAQUE DORÉE")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 1, green: 0.84, blue: 0))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .opacity(phase >= 1 ? 1 : 0)
                        .padding(.top, 15)
                }

                // ── Tier spinner (v5.1 — 5 gem labels) ──
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { idx in
                        let key = GEM_TIERS[idx]
                        let isScanning = scanIndex == idx
                        let isWinner = winnerIndex == idx
                        let slotColor = GEM_COLORS[key] ?? .white

                        Text(GEM_LABELS[idx])
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(0.5)
                            .foregroundColor(slotColor.opacity(isScanning || isWinner ? 1 : 0.3))
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(slotColor.opacity(isScanning || isWinner ? 0.1 : 0.03))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(slotColor.opacity(isScanning || isWinner ? 1 : 0), lineWidth: 2)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .scaleEffect(isWinner ? 1.15 : (isScanning ? 1.1 : 1.0))
                            .animation(.easeInOut(duration: 0.15), value: scanIndex)
                            .animation(.easeInOut(duration: 0.15), value: winnerIndex)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 20)
                .opacity(phase >= 2 ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: phase)

                // ── Result text ──
                VStack(spacing: 8) {
                    Text(gemLabel)
                        .font(.system(size: 28, weight: .black))
                        .tracking(2)
                        .foregroundColor(gemColor)

                    Text("\(rollData.baseTier == "gold" ? "Base Dorée" : "Base Sombre") • Ajouté à l'inventaire")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
                .opacity(phase >= 5 ? 1 : 0)
                .scaleEffect(phase >= 5 ? 1 : 0.5)
                .animation(.spring(response: 0.4, dampingFraction: 0.5), value: phase)
                .padding(.top, 20)

                // ── Close button ──
                Button(action: { if phase >= 6 { onDismiss() } }) {
                    Text("FERMER")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .opacity(phase >= 6 ? 0.5 : 0)
                .animation(.easeInOut(duration: 0.4), value: phase)
                .padding(.top, 20)

                Spacer()
            }
            .offset(isArcaneShake ? shakeOffset : .zero)
        }
        .onTapGesture { if phase >= 6 { onDismiss() } }
        .onAppear { startRollSequence() }
    }

    // MARK: - Spotlight intensity by gem tier
    private var spotIntensity: Double {
        switch rollData.gemType {
        case "arcane": return 0.40
        case "ruby":   return 0.25
        case "saphir": return 0.16
        case "jade":   return 0.10
        default:       return 0.06
        }
    }

    // MARK: - Roll Sequence (matches Kotlin timing exactly)
    private func startRollSequence() {
        let targetIdx = self.targetIdx

        Task { @MainActor in
            // STEP 1 — overlay opens
            phase = 0
            SoundEngine.shared.vibrate(.light)
            try? await Task.sleep(nanoseconds: 400_000_000)

            // STEP 2 — base plate appears
            phase = 1
            SoundEngine.shared.vibrate(.medium)
            try? await Task.sleep(nanoseconds: 600_000_000)

            // STEP 3 — spinner visible
            phase = 2
            try? await Task.sleep(nanoseconds: 300_000_000)

            // STEP 4 — scanning animation (matches Kotlin exactly)
            phase = 3
            let isHighTier = rollData.gemType == "ruby" || rollData.gemType == "arcane"
            let numCycles = isHighTier ? 4 : (2 + Int.random(in: 0...2))
            let baseSpeed: UInt64 = isHighTier ? 90 : 80
            let speedRamp: UInt64 = isHighTier ? 35 : UInt64(30 + Int.random(in: 0...19))

            // Fast scan cycles
            for cycle in 0..<numCycles {
                for i in 0...4 {
                    scanIndex = i
                    currentGemColor = GEM_COLORS[GEM_TIERS[i]] ?? .white
                    SoundEngine.shared.vibrate(.soft)
                    try? await Task.sleep(nanoseconds: (baseSpeed + UInt64(cycle) * speedRamp) * 1_000_000)
                }
            }

            // Tease: 25% on low results (quartz/jade)
            let doTease = targetIdx <= 1 && Double.random(in: 0...1) < 0.25
            if doTease {
                let teaseMs: [UInt64] = [150, 180, 220, 350, 600]
                for i in 0...4 {
                    scanIndex = i
                    currentGemColor = GEM_COLORS[GEM_TIERS[i]] ?? .white
                    SoundEngine.shared.vibrate(.soft)
                    try? await Task.sleep(nanoseconds: teaseMs[i] * 1_000_000)
                }
                for i in 0...targetIdx {
                    scanIndex = i
                    currentGemColor = GEM_COLORS[GEM_TIERS[i]] ?? .white
                    SoundEngine.shared.vibrate(.soft)
                    try? await Task.sleep(nanoseconds: (150 + UInt64(i) * 50) * 1_000_000)
                }
            } else {
                for i in 0...targetIdx {
                    scanIndex = i
                    currentGemColor = GEM_COLORS[GEM_TIERS[i]] ?? .white
                    SoundEngine.shared.vibrate(.light)
                    try? await Task.sleep(nanoseconds: (200 + UInt64(i) * 80) * 1_000_000)
                }
            }

            // STEP 5 — REVEAL
            phase = 4
            scanIndex = -1
            winnerIndex = targetIdx
            currentGemColor = gemColor

            // Screen flash
            withAnimation(.easeIn(duration: 0.05)) { showFlash = true }
            Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                withAnimation(.easeOut(duration: 0.35)) { showFlash = false }
            }

            // Tier-specific haptics
            switch rollData.gemType {
            case "arcane":
                isArcaneShake = true
                SoundEngine.shared.vibrate(.heavy)
                startShakeAnimation()
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    isArcaneShake = false
                    shakeOffset = .zero
                }
            case "ruby":
                SoundEngine.shared.vibratePattern([.heavy, .light, .medium])
            case "saphir":
                SoundEngine.shared.vibratePattern([.light, .light, .medium])
            case "jade":
                SoundEngine.shared.vibratePattern([.light, .medium])
            default:
                SoundEngine.shared.vibrate(.light)
            }

            try? await Task.sleep(nanoseconds: 300_000_000)

            // STEP 6 — result text
            phase = 5
            try? await Task.sleep(nanoseconds: 400_000_000)

            // Inventory refresh
            GemInventoryState.shared.fetchFromBackend()
            SoundEngine.shared.vibrate(.light)
            try? await Task.sleep(nanoseconds: 300_000_000)

            // STEP 7 — closeable
            phase = 6
        }
    }

    private func startShakeAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { timer in
            if !isArcaneShake { timer.invalidate(); return }
            shakeOffset = CGSize(
                width: CGFloat.random(in: -8...8),
                height: CGFloat.random(in: -5...5)
            )
        }
    }
}

// MARK: - Gem Diamond Shape

struct GemDiamondView: View {
    let color: Color
    let size: CGFloat
    let showGlow: Bool

    var body: some View {
        Canvas { context, canvasSize in
            let cx = canvasSize.width / 2
            let cy = canvasSize.height / 2
            let r = canvasSize.width * 0.42

            // Glow
            if showGlow {
                var glowPath = Path()
                glowPath.addEllipse(in: CGRect(
                    x: cx - r * 1.8, y: cy - r * 1.8,
                    width: r * 3.6, height: r * 3.6
                ))
                context.fill(glowPath, with: .color(color.opacity(0.3)))
            }

            // Outer diamond
            var outer = Path()
            outer.move(to: CGPoint(x: cx, y: cy - r))
            outer.addLine(to: CGPoint(x: cx + r, y: cy))
            outer.addLine(to: CGPoint(x: cx, y: cy + r))
            outer.addLine(to: CGPoint(x: cx - r, y: cy))
            outer.closeSubpath()
            context.fill(outer, with: .color(color))

            // Inner diamond
            let ir = r * 0.58
            var inner = Path()
            inner.move(to: CGPoint(x: cx, y: cy - ir))
            inner.addLine(to: CGPoint(x: cx + ir, y: cy))
            inner.addLine(to: CGPoint(x: cx, y: cy + ir))
            inner.addLine(to: CGPoint(x: cx - ir, y: cy))
            inner.closeSubpath()
            context.fill(inner, with: .color(color.opacity(0.65)))

            // Highlight facet
            var hl = Path()
            hl.move(to: CGPoint(x: cx, y: cy - r))
            hl.addLine(to: CGPoint(x: cx - r, y: cy))
            hl.addLine(to: CGPoint(x: cx - ir, y: cy))
            hl.addLine(to: CGPoint(x: cx, y: cy - ir))
            hl.closeSubpath()
            context.fill(hl, with: .color(.white.opacity(0.35)))

            // Sparkle dot
            context.fill(
                Path(ellipseIn: CGRect(
                    x: cx - r * 0.12, y: cy - r * 0.16,
                    width: r * 0.16, height: r * 0.16
                )),
                with: .color(.white.opacity(0.9))
            )
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Spotlight Cone

struct SpotlightCone: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: size.width * 0.4, y: 0))
            path.addLine(to: CGPoint(x: size.width * 0.6, y: 0))
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()

            context.fill(path, with: .linearGradient(
                Gradient(colors: [.clear, color.opacity(0.3)]),
                startPoint: CGPoint(x: size.width / 2, y: 0),
                endPoint: CGPoint(x: size.width / 2, y: size.height)
            ))
        }
    }
}

// MARK: - Edge Glow

struct EdgeGlowView: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width * 0.15
            let gc = color.opacity(0.25)

            // Top edge
            context.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: w)),
                         with: .linearGradient(
                            Gradient(colors: [gc, .clear]),
                            startPoint: CGPoint(x: 0, y: 0),
                            endPoint: CGPoint(x: 0, y: w)
                         ))
            // Bottom edge
            context.fill(Path(CGRect(x: 0, y: size.height - w, width: size.width, height: w)),
                         with: .linearGradient(
                            Gradient(colors: [.clear, gc]),
                            startPoint: CGPoint(x: 0, y: size.height - w),
                            endPoint: CGPoint(x: 0, y: size.height)
                         ))
            // Left edge
            context.fill(Path(CGRect(x: 0, y: 0, width: w, height: size.height)),
                         with: .linearGradient(
                            Gradient(colors: [gc, .clear]),
                            startPoint: CGPoint(x: 0, y: 0),
                            endPoint: CGPoint(x: w, y: 0)
                         ))
            // Right edge
            context.fill(Path(CGRect(x: size.width - w, y: 0, width: w, height: size.height)),
                         with: .linearGradient(
                            Gradient(colors: [.clear, gc]),
                            startPoint: CGPoint(x: size.width - w, y: 0),
                            endPoint: CGPoint(x: size.width, y: 0)
                         ))
        }
    }
}

// MARK: - Sound Engine (iOS — haptics only for now, PCM audio later)

class SoundEngine {
    static let shared = SoundEngine()

    enum HapticIntensity {
        case soft, light, medium, heavy
    }

    func vibrate(_ intensity: HapticIntensity) {
        let generator: UIImpactFeedbackGenerator
        switch intensity {
        case .soft:   generator = UIImpactFeedbackGenerator(style: .soft)
        case .light:  generator = UIImpactFeedbackGenerator(style: .light)
        case .medium: generator = UIImpactFeedbackGenerator(style: .medium)
        case .heavy:  generator = UIImpactFeedbackGenerator(style: .heavy)
        }
        generator.prepare()
        generator.impactOccurred()
    }

    func vibratePattern(_ pattern: [HapticIntensity]) {
        for (i, intensity) in pattern.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                self.vibrate(intensity)
            }
        }
    }
}
