// ═══════════════════════════════════════════════════════════════
// @cross-ref  Capture Animation System
// ─────────────────────────────────────────────────────────────
// THIS FILE:  SwiftUI 2D screen effects (border trace, flash, result popup)
// ALSO SEE:   [Unity]   UI/HexCaptureAnimator.cs           → 3D hex stroke animation
//             [Unity]   Core/HexClaimUI.cs                  → Claim detection & trigger
//             [Swift]   State/CaptureState.swift            → Unity↔Swift state bridge
//             [Swift]   UI/GameHud.swift                    → Hold button / attack UI
//             [Backend] services/hex.service.js              → Claim/steal server logic
// PARITY:     1:1 port of Android CaptureOverlay.kt (176L)
// ═══════════════════════════════════════════════════════════════

import SwiftUI

/// Capture overlay — EFFECTS ONLY (animated border trace, flash, result popup).
/// The bottom pill with attack section is in GameHudPill.
/// Progress comes from CaptureState.holdProgress (published by GameHudPill).
struct CaptureOverlayView: View {
    @ObservedObject private var captureState = CaptureState.shared

    // Local animation state
    @State private var showFlash = false
    @State private var showResult = false
    @State private var resultText = ""
    @State private var resultColor = Color(red: 0.29, green: 0.87, blue: 0.50) // #4ADE80
    @State private var resultScale: CGFloat = 0.5
    @State private var resultOpacity: Double = 0

    // Parse player T1 color
    private var playerColor: Color {
        Color(hex: captureState.playerHexColor)
    }

    private var accentColor: Color {
        captureState.isLootCapture ? Color(red: 1, green: 0.84, blue: 0) : playerColor // #FFD700
    }

    var body: some View {
        // Only render when needed (performance: no draw calls when idle)
        if captureState.isClaimInProgress || showFlash || showResult {
            ZStack {
                // ===== ANIMATED BORDER TRACE =====
                if captureState.isClaimInProgress && captureState.holdProgress > 0 {
                    CaptureProgressBorder(
                        progress: CGFloat(captureState.holdProgress),
                        color: accentColor
                    )
                    .allowsHitTesting(false)
                }

                // ===== FLASH =====
                if showFlash {
                    Color.white.opacity(0.7)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }

                // ===== RESULT POPUP =====
                if showResult {
                    Text(resultText)
                        .font(.system(size: 36, weight: .black))
                        .tracking(4)
                        .foregroundColor(resultColor)
                        .scaleEffect(resultScale)
                        .opacity(resultOpacity)
                        .allowsHitTesting(false)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onChange(of: captureState.lastResult) { result in
                handleResult(result)
            }
        }
    }

    // MARK: - Result Handler (matches Android LaunchedEffect L80-106)

    private func handleResult(_ result: CaptureState.ClaimResult) {
        if result.success && result.showUntil > Date() {
            // Success — flash + popup
            resultText = result.wasSteal ? "VOLÉ!" : "CONQUIS!"
            resultColor = result.wasSteal
                ? Color(red: 0.97, green: 0.44, blue: 0.44) // #F87171
                : Color(red: 0.29, green: 0.87, blue: 0.50) // #4ADE80

            // Flash sequence: show 100ms then hide
            showFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.15)) { showFlash = false }
            }

            // Popup: scale in, hold 2s, scale out
            showResult = true
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                resultScale = 1.0
                resultOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    resultScale = 0.8
                    resultOpacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showResult = false
                    resultScale = 0.5
                    CaptureState.shared.clearResult()
                }
            }

        } else if !result.success && !result.message.isEmpty {
            // Failure popup
            resultText = result.message.isEmpty ? "ÉCHOUÉ" : result.message
            resultColor = Color(red: 0.97, green: 0.44, blue: 0.44) // #F87171

            showResult = true
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                resultScale = 1.0
                resultOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    resultScale = 0.8
                    resultOpacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showResult = false
                    resultScale = 0.5
                    CaptureState.shared.clearResult()
                }
            }
        }
    }
}

// MARK: - Border Trace Shape (matches Android Canvas drawRoundRect L116-141)

/// Draws a rounded rectangle border that progressively reveals based on progress (0→1).
/// Uses a dashed stroke where the visible portion = progress * perimeter.
struct CaptureProgressBorder: View {
    let progress: CGFloat
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            let strokeWidth: CGFloat = 4
            let cornerRadius: CGFloat = 20
            let totalPerimeter = 2 * (w + h - 4 * cornerRadius) + 2 * .pi * cornerRadius
            let drawnLength = totalPerimeter * progress

            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: strokeWidth,
                        lineCap: .round,
                        dash: [drawnLength, totalPerimeter - drawnLength]
                    )
                )
                .padding(strokeWidth / 2)
        }
        .ignoresSafeArea()
    }
}

// MARK: - CaptureState Extension — clearResult()

extension CaptureState {
    func clearResult() {
        DispatchQueue.main.async {
            self.lastResult = ClaimResult()
        }
    }
}

// MARK: - Color hex init (moved here from deleted AppNavigation.swift)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
