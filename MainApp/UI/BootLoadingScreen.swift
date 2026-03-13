import SwiftUI

/// Boot loading screen — shown while Unity loads tiles, hexes, zones.
/// Driven by UnityBridge boot state callbacks (no timers).
/// Matches Kotlin's WelcomeScreen/loading overlay.
struct BootLoadingScreen: View {
    @ObservedObject var bridge = UnityBridge.shared

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(hex: "#0A0A1A"), Color(hex: "#1A1A3E")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo
                Image(systemName: "hexagon.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#00FFAA"), Color(hex: "#00AAFF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(hex: "#00FFAA").opacity(0.4), radius: 20)

                Text("P. HEXAGON")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Boot Progress Steps
                VStack(alignment: .leading, spacing: 12) {
                    BootStep(label: "Moteur de jeu", done: bridge.isUnityReady)
                    BootStep(label: "Authentification", done: bridge.isAuthBridged)
                    BootStep(label: "Position GPS", done: bridge.isGPSLocked)
                    BootStep(label: "Historique hexagones", done: bridge.isHexHistoryLoaded)
                    BootStep(label: "Tuiles de carte", done: bridge.isTilesLoaded)
                    BootStep(label: "Zones", done: bridge.isZonesLoaded)
                }
                .padding(.horizontal, 48)

                // Progress bar
                let steps = [bridge.isUnityReady, bridge.isAuthBridged, bridge.isGPSLocked,
                            bridge.isHexHistoryLoaded, bridge.isTilesLoaded, bridge.isZonesLoaded]
                let completed = steps.filter { $0 }.count
                let progress = Double(completed) / Double(steps.count)

                VStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#00FFAA"), Color(hex: "#00CCFF")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * progress, height: 6)
                                .animation(.easeInOut(duration: 0.3), value: progress)
                        }
                    }
                    .frame(height: 6)
                    .padding(.horizontal, 48)

                    Text("\(completed)/\(steps.count)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                }

                Spacer()

                // Tip
                Text("Chargement du monde...")
                    .font(.system(size: 14))
                    .foregroundColor(.gray.opacity(0.6))
                    .padding(.bottom, 40)
            }
        }
    }
}

/// Single boot step with check/spinner indicator
struct BootStep: View {
    let label: String
    let done: Bool

    var body: some View {
        HStack(spacing: 12) {
            if done {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#00FFAA"))
            } else {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
                    .tint(Color(hex: "#00AAFF"))
            }

            Text(label)
                .font(.system(size: 14, weight: done ? .semibold : .regular))
                .foregroundColor(done ? .white : .gray)
        }
        .animation(.easeInOut(duration: 0.2), value: done)
    }
}
