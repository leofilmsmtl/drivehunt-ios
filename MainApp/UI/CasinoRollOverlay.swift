import SwiftUI
import AVFoundation

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
    @State private var shakeTimer: Timer? = nil  // Fix #6: stored for cleanup

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
        .onDisappear {
            // Fix #6: Clean up shake timer on dismiss
            shakeTimer?.invalidate()
            shakeTimer = nil
        }
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
            SoundEngine.shared.whoosh()
            SoundEngine.shared.vibrate(.light)
            try? await Task.sleep(nanoseconds: 400_000_000)

            // STEP 2 — base plate appears
            phase = 1
            SoundEngine.shared.plateLand(tier: rollData.baseTier)
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
            var tickStep = 0

            // Fast scan cycles
            for cycle in 0..<numCycles {
                for i in 0...4 {
                    scanIndex = i
                    currentGemColor = GEM_COLORS[GEM_TIERS[i]] ?? .white
                    SoundEngine.shared.tick(step: tickStep)
                    tickStep += 1
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
                    SoundEngine.shared.tick(step: tickStep)
                    tickStep += 1
                    SoundEngine.shared.vibrate(.soft)
                    try? await Task.sleep(nanoseconds: teaseMs[i] * 1_000_000)
                }
                for i in 0...targetIdx {
                    scanIndex = i
                    currentGemColor = GEM_COLORS[GEM_TIERS[i]] ?? .white
                    SoundEngine.shared.tick(step: tickStep)
                    tickStep += 1
                    SoundEngine.shared.vibrate(.soft)
                    try? await Task.sleep(nanoseconds: (150 + UInt64(i) * 50) * 1_000_000)
                }
            } else {
                for i in 0...targetIdx {
                    scanIndex = i
                    currentGemColor = GEM_COLORS[GEM_TIERS[i]] ?? .white
                    SoundEngine.shared.tick(step: tickStep)
                    tickStep += 1
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

            // Tier-specific SFX + haptics
            switch rollData.gemType {
            case "arcane":
                isArcaneShake = true
                SoundEngine.shared.revealLegendary()
                SoundEngine.shared.vibrate(.heavy)
                startShakeAnimation()
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    isArcaneShake = false
                    shakeOffset = .zero
                    shakeTimer?.invalidate()
                    shakeTimer = nil
                }
            case "ruby":
                SoundEngine.shared.revealEpic()
                SoundEngine.shared.vibratePattern([.heavy, .light, .medium])
            case "saphir":
                SoundEngine.shared.revealRare()
                SoundEngine.shared.vibratePattern([.light, .light, .medium])
            case "jade":
                SoundEngine.shared.revealUncommon()
                SoundEngine.shared.vibratePattern([.light, .medium])
            default:
                SoundEngine.shared.revealCommon()
                SoundEngine.shared.vibrate(.light)
            }

            try? await Task.sleep(nanoseconds: 300_000_000)

            // STEP 6 — result text
            phase = 5
            try? await Task.sleep(nanoseconds: 400_000_000)

            // Inventory refresh
            GemInventoryState.shared.fetchFromBackend()
            SoundEngine.shared.ding()
            SoundEngine.shared.vibrate(.light)
            try? await Task.sleep(nanoseconds: 300_000_000)

            // STEP 7 — closeable
            phase = 6
        }
    }

    private func startShakeAnimation() {
        shakeTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { timer in
            if !isArcaneShake { timer.invalidate(); shakeTimer = nil; return }
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

// MARK: - Sound Engine (iOS — PCM synthesis + haptics, ported from Kotlin SoundEngine)
// Fix #1: Pool of AVAudioPlayerNode — sounds overlap instead of cutting each other
// Fix #2: warmUp() for early init
// Fix #3: .playback session = plays even in silent mode
// Fix #8: Pre-created haptic generators

class SoundEngine {
    static let shared = SoundEngine()

    private let sampleRate: Double = 22050
    private let engine = AVAudioEngine()
    private let format: AVAudioFormat

    // Pool of player nodes — sounds can overlap (like Kotlin's per-sound AudioTrack)
    private let poolSize = 4
    private var playerNodes: [AVAudioPlayerNode] = []
    private var nextNodeIndex = 0

    // Pre-created haptic generators (fix #8)
    private let hapticSoft = UIImpactFeedbackGenerator(style: .soft)
    private let hapticLight = UIImpactFeedbackGenerator(style: .light)
    private let hapticMedium = UIImpactFeedbackGenerator(style: .medium)
    private let hapticHeavy = UIImpactFeedbackGenerator(style: .heavy)

    enum HapticIntensity {
        case soft, light, medium, heavy
    }

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        // Create pool of player nodes
        for _ in 0..<poolSize {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            playerNodes.append(node)
        }

        // Fix #3: .playback plays even with silent switch on
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        try? engine.start()

        // Pre-prepare haptics
        hapticSoft.prepare()
        hapticLight.prepare()
        hapticMedium.prepare()
        hapticHeavy.prepare()
    }

    /// Call early (e.g. at app launch) to pre-warm the audio engine (fix #2)
    func warmUp() {
        // Accessing .shared triggers init() — play a silent buffer to fully warm the pipeline
        let silence = [Float](repeating: 0, count: Int(sampleRate * 0.01))
        play(silence)
    }

    // MARK: - Haptics

    func vibrate(_ intensity: HapticIntensity) {
        let generator: UIImpactFeedbackGenerator
        switch intensity {
        case .soft:   generator = hapticSoft
        case .light:  generator = hapticLight
        case .medium: generator = hapticMedium
        case .heavy:  generator = hapticHeavy
        }
        generator.impactOccurred()
        generator.prepare() // Re-prepare for NEXT hit
    }

    func vibratePattern(_ pattern: [HapticIntensity]) {
        for (i, intensity) in pattern.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                self.vibrate(intensity)
            }
        }
    }

    // MARK: - PCM Tone Generation (matches Kotlin SoundEngine)

    private func generateTone(freq: Float, duration: Float, waveform: String = "sine",
                              volume: Float = 0.15, delay: Float = 0) -> [Float] {
        let totalSamples = Int((delay + duration) * Float(sampleRate))
        let delaySamples = Int(delay * Float(sampleRate))
        var samples = [Float](repeating: 0, count: totalSamples)

        for i in delaySamples..<totalSamples {
            let t = Float(i - delaySamples) / Float(sampleRate)
            let envelope = volume * max(0, 1 - t / duration)
            let phase = 2.0 * Float.pi * freq * t

            let wave: Float
            switch waveform {
            case "square":   wave = sin(phase) >= 0 ? 1 : -1
            case "sawtooth": wave = 2 * (freq * t).truncatingRemainder(dividingBy: 1) - 1
            case "triangle": wave = 2 * abs(2 * (freq * t).truncatingRemainder(dividingBy: 1) - 1) - 1
            default:         wave = sin(phase)
            }
            samples[i] = wave * envelope
        }
        return samples
    }

    private func generateNoise(duration: Float, volume: Float = 0.1, delay: Float = 0) -> [Float] {
        let totalSamples = Int((delay + duration) * Float(sampleRate))
        let delaySamples = Int(delay * Float(sampleRate))
        var samples = [Float](repeating: 0, count: totalSamples)

        for i in delaySamples..<totalSamples {
            let t = Float(i - delaySamples) / (duration * Float(sampleRate))
            let envelope = volume * max(0, 1 - t) * 0.5
            samples[i] = Float.random(in: -1...1) * envelope
        }
        return samples
    }

    private func mix(_ buffers: [Float]...) -> [Float] {
        let maxLen = buffers.map(\.count).max() ?? 0
        var mixed = [Float](repeating: 0, count: maxLen)
        for buf in buffers {
            for i in buf.indices { mixed[i] += buf[i] }
        }
        for i in mixed.indices { mixed[i] = min(1, max(-1, mixed[i])) }
        return mixed
    }

    /// Fix #1: Round-robin through pool of player nodes — no more stop() killing previous sounds
    private func play(_ samples: [Float]) {
        guard !samples.isEmpty else { return }
        if !engine.isRunning { try? engine.start() }

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        let channelData = buffer.floatChannelData![0]
        for i in samples.indices { channelData[i] = samples[i] }

        // Round-robin: pick next player node (allows 4 overlapping sounds)
        let node = playerNodes[nextNodeIndex]
        nextNodeIndex = (nextNodeIndex + 1) % poolSize

        // Don't stop — just schedule on top. Short sounds auto-finish.
        if !node.isPlaying { node.play() }
        node.scheduleBuffer(buffer, completionHandler: nil)
    }

    // MARK: - Public SFX (matches Kotlin SoundEngine exactly)

    func whoosh() {
        play(mix(
            generateNoise(duration: 0.3, volume: 0.08),
            generateTone(freq: 200, duration: 0.3, waveform: "sine", volume: 0.06),
            generateTone(freq: 100, duration: 0.4, waveform: "sine", volume: 0.04, delay: 0.1)
        ))
    }

    func tick(step: Int = 0) {
        let freq: Float = 400 + Float(step) * 100
        play(generateTone(freq: freq, duration: 0.08, waveform: "square", volume: 0.10))
    }

    func plateLand(tier: String) {
        let freq: Float = tier == "gold" ? 300 : (tier == "silver" ? 200 : 150)
        play(mix(
            generateTone(freq: freq, duration: 0.3, waveform: "sine", volume: 0.1),
            generateNoise(duration: 0.1, volume: 0.05)
        ))
    }

    func revealCommon() {
        play(mix(
            generateTone(freq: 330, duration: 0.25, waveform: "triangle", volume: 0.08),
            generateTone(freq: 294, duration: 0.3, waveform: "triangle", volume: 0.05, delay: 0.1)
        ))
    }

    func revealUncommon() {
        play(mix(
            generateTone(freq: 350, duration: 0.25, waveform: "triangle", volume: 0.08),
            generateTone(freq: 330, duration: 0.3, waveform: "triangle", volume: 0.06, delay: 0.1)
        ))
    }

    func revealRare() {
        play(mix(
            generateTone(freq: 523, duration: 0.25, waveform: "triangle", volume: 0.12),
            generateTone(freq: 659, duration: 0.3, waveform: "triangle", volume: 0.10, delay: 0.12),
            generateTone(freq: 784, duration: 0.35, waveform: "sine", volume: 0.06, delay: 0.25)
        ))
    }

    func revealEpic() {
        play(mix(
            // Sub-bass boom
            generateTone(freq: 40, duration: 0.8, waveform: "sine", volume: 0.25),
            generateTone(freq: 60, duration: 0.6, waveform: "sine", volume: 0.18, delay: 0.05),
            generateTone(freq: 80, duration: 0.5, waveform: "sine", volume: 0.12, delay: 0.1),
            // Power chord
            generateTone(freq: 261, duration: 0.3, waveform: "sawtooth", volume: 0.14, delay: 0.08),
            generateTone(freq: 392, duration: 0.3, waveform: "sawtooth", volume: 0.10, delay: 0.10),
            generateTone(freq: 523, duration: 0.25, waveform: "sawtooth", volume: 0.12, delay: 0.12),
            generateTone(freq: 784, duration: 0.25, waveform: "sawtooth", volume: 0.08, delay: 0.16),
            // Ascending fanfare
            generateTone(freq: 1047, duration: 0.4, waveform: "sine", volume: 0.16, delay: 0.20),
            generateTone(freq: 1318, duration: 0.4, waveform: "sine", volume: 0.14, delay: 0.26),
            generateTone(freq: 1568, duration: 0.5, waveform: "sine", volume: 0.12, delay: 0.32),
            generateTone(freq: 2093, duration: 0.6, waveform: "sine", volume: 0.10, delay: 0.38),
            // Cymbal crash
            generateNoise(duration: 0.5, volume: 0.18, delay: 0.15),
            // Ethereal choir
            generateTone(freq: 1047, duration: 1.0, waveform: "sine", volume: 0.05, delay: 0.55),
            generateTone(freq: 1318, duration: 1.0, waveform: "sine", volume: 0.04, delay: 0.60),
            generateTone(freq: 1568, duration: 1.2, waveform: "sine", volume: 0.04, delay: 0.65),
            // Sparkle tail
            generateTone(freq: 2093, duration: 1.5, waveform: "sine", volume: 0.03, delay: 0.70),
            generateTone(freq: 1568, duration: 2.0, waveform: "triangle", volume: 0.015, delay: 0.90)
        ))
    }

    func revealLegendary() {
        play(mix(
            // Phase 1: Earthquake (triple sub-bass)
            generateTone(freq: 30, duration: 1.2, waveform: "sine", volume: 0.30),
            generateTone(freq: 40, duration: 1.0, waveform: "sine", volume: 0.25, delay: 0.03),
            generateTone(freq: 55, duration: 0.8, waveform: "sine", volume: 0.22, delay: 0.06),
            generateTone(freq: 80, duration: 0.6, waveform: "sine", volume: 0.18, delay: 0.10),
            generateTone(freq: 100, duration: 0.15, waveform: "square", volume: 0.20, delay: 0.12),
            generateNoise(duration: 0.08, volume: 0.25, delay: 0.12),
            // Phase 2: Orchestral hit (stacked fifths)
            generateTone(freq: 131, duration: 0.4, waveform: "sawtooth", volume: 0.16, delay: 0.15),
            generateTone(freq: 196, duration: 0.4, waveform: "sawtooth", volume: 0.14, delay: 0.16),
            generateTone(freq: 261, duration: 0.35, waveform: "sawtooth", volume: 0.16, delay: 0.17),
            generateTone(freq: 392, duration: 0.35, waveform: "sawtooth", volume: 0.14, delay: 0.18),
            generateTone(freq: 523, duration: 0.3, waveform: "sawtooth", volume: 0.14, delay: 0.19),
            generateTone(freq: 659, duration: 0.3, waveform: "sawtooth", volume: 0.12, delay: 0.20),
            generateTone(freq: 784, duration: 0.3, waveform: "sawtooth", volume: 0.10, delay: 0.21),
            // Phase 3: Ascending fanfare → G7
            generateTone(freq: 1047, duration: 0.35, waveform: "sine", volume: 0.18, delay: 0.30),
            generateTone(freq: 1318, duration: 0.30, waveform: "sine", volume: 0.16, delay: 0.36),
            generateTone(freq: 1568, duration: 0.30, waveform: "sine", volume: 0.16, delay: 0.42),
            generateTone(freq: 2093, duration: 0.35, waveform: "sine", volume: 0.14, delay: 0.48),
            generateTone(freq: 2637, duration: 0.40, waveform: "sine", volume: 0.10, delay: 0.54),
            generateTone(freq: 3136, duration: 0.50, waveform: "sine", volume: 0.08, delay: 0.60),
            // Phase 4: Triple crash
            generateNoise(duration: 0.6, volume: 0.22, delay: 0.18),
            generateNoise(duration: 0.5, volume: 0.15, delay: 0.35),
            generateNoise(duration: 0.4, volume: 0.10, delay: 0.55),
            // Phase 5: Detuned heavenly choir
            generateTone(freq: 523, duration: 2.0, waveform: "sine", volume: 0.06, delay: 0.75),
            generateTone(freq: 527, duration: 2.0, waveform: "sine", volume: 0.06, delay: 0.75),
            generateTone(freq: 784, duration: 2.0, waveform: "sine", volume: 0.05, delay: 0.80),
            generateTone(freq: 788, duration: 2.0, waveform: "sine", volume: 0.05, delay: 0.80),
            generateTone(freq: 1047, duration: 2.5, waveform: "sine", volume: 0.05, delay: 0.85),
            generateTone(freq: 1051, duration: 2.5, waveform: "sine", volume: 0.05, delay: 0.85)
        ))
    }

    func ding() {
        play(mix(
            generateTone(freq: 880, duration: 0.15, waveform: "sine", volume: 0.1),
            generateTone(freq: 1320, duration: 0.2, waveform: "sine", volume: 0.08, delay: 0.08)
        ))
    }
}
