import SwiftUI

/// WelcomeScreen — 1:1 port of Kotlin's WelcomeScreen.kt
/// Loading screen with weighted progress bar, rotating tips, safety lock.
struct WelcomeScreen: View {
    var onContinue: () -> Void
    @StateObject private var viewModel = WelcomeViewModel()

    // DriveHunt brand colors — from ThemeManager tokens
    private var theme: ThemeManager { ThemeManager.shared }
    private let accentGreen = Color(hex: "#00FFAA")
    private let accentBlue = Color(hex: "#00CCFF")
    private let gradientColors = [Color(hex: "#00FFAA"), Color(hex: "#00CCFF")]

    // Gameplay tips — rotates during loading (matches Kotlin TIPS)
    private let tips = [
        "💡 Capturez des hexagones en vous déplaçant dans la vraie vie",
        "🏰 Construisez des forteresses pour protéger votre territoire",
        "💎 Trouvez du butin caché dans chaque zone explorée",
        "🐉 Votre dragon grandit en capturant plus de territoire",
        "🗺️ Explorez de nouveaux quartiers pour trouver des zones rares",
        "⚔️ Défendez vos hexagones contre les autres joueurs"
    ]

    @State private var tipIndex = 0
    @State private var tipVisible = true
    @State private var pulseAlpha: Double = 0.3
    @State private var glowAlpha: Double = 0.3

    var body: some View {
        ZStack {
            // Background gradient
            theme.colors.backgroundGradient
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Logo Block (iOS-native hexagon, same as LoginScreen) ──
                ZStack {
                    // Glow behind hexagon
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [accentGreen.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 40
                            )
                        )
                        .frame(width: 80, height: 80)
                        .opacity(glowAlpha)

                    Image(systemName: "hexagon.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [accentGreen, Color(hex: "#00AAFF")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Spacer().frame(height: 12)

                Text("P. HEXAGON")
                    .font(.system(size: 32, weight: .bold)) // Material's headlineLarge roughly correlates to 32pt
                    .tracking(2)
                    .foregroundColor(theme.colors.textPrimary)

                Text("GPS Territory Capture Game")
                    .font(.system(size: 12)) // Material's bodySmall roughly correlates to 12pt
                    .foregroundColor(Color(hex: "#666666"))

                Spacer().frame(height: 48)

                // ── Progress Block ──
                // Status text with pulsing dot
                HStack(spacing: 8) {
                    if !viewModel.isReady {
                        Circle()
                            .fill(accentGreen)
                            .frame(width: 5, height: 5)
                            .opacity(pulseAlpha)
                    }
                    Text(viewModel.statusText)
                        .font(.system(size: 12))
                        .foregroundColor(theme.colors.textPrimary.opacity(0.5))
                        .tracking(0.5)
                }

                Spacer().frame(height: 12)

                // Progress bar — thin, gradient
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(theme.colors.textPrimary.opacity(0.06))

                        RoundedRectangle(cornerRadius: 1)
                            .fill(
                                LinearGradient(
                                    colors: gradientColors,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(viewModel.progress))
                            .animation(.easeOut(duration: 0.4), value: viewModel.progress)
                    }
                }
                .frame(width: UIScreen.main.bounds.width * 0.7, height: 2)

                Spacer().frame(height: 8)

                // Percentage
                Text("\(Int(viewModel.progress * 100))%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(theme.colors.textPrimary.opacity(0.2))

                Spacer().frame(height: 24)

                // ── CTA Button or Error ──
                if viewModel.isReady {
                    Button(action: onContinue) {
                        Text(viewModel.isSafetyLocked ? "Lecture requise..." : "DÉMARRER")
                            .fontWeight(.bold)
                            .font(.system(size: 15))
                            .tracking(1)
                            .frame(width: UIScreen.main.bounds.width * 0.7, height: 50)
                            .background(
                                LinearGradient(
                                    colors: viewModel.isSafetyLocked ? [Color.gray, Color.gray.opacity(0.8)] : gradientColors,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(viewModel.isSafetyLocked ? .white.opacity(0.8) : .black)
                            .cornerRadius(12)
                    }
                    .disabled(viewModel.isSafetyLocked)
                } else if let error = viewModel.fatalError {
                    // Error card — glassmorphism style
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#FF6B6B"))
                        .multilineTextAlignment(.center)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: "#FF6B6B").opacity(0.1))
                        .cornerRadius(12)
                }

                Spacer()

                // ── Rotating Tip ──
                Text(tips[tipIndex])
                    .font(.system(size: 12))
                    .italic()
                    .foregroundColor(theme.colors.textPrimary.opacity(0.25 * (tipVisible ? 1 : 0)))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(height: 40)
                    .padding(.horizontal, 8)
                    .animation(.easeInOut(duration: 0.4), value: tipVisible)

                Spacer().frame(height: 12)

                // ── Safety Notice ──
                Text("⚠ Ne pas utiliser en conduisant · Respectez le code de la route")
                    .font(.system(size: 11))
                    .foregroundColor(theme.colors.textPrimary.opacity(0.15))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Spacer().frame(height: 24)
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            viewModel.startPreloading()
            startAnimations()
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        // Pulsing dot
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            pulseAlpha = 1.0
        }
        // Hexagon glow
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            glowAlpha = 0.7
        }
        // Rotating tips
        Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            withAnimation { tipVisible = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                tipIndex = (tipIndex + 1) % tips.count
                withAnimation { tipVisible = true }
            }
        }
    }
}
