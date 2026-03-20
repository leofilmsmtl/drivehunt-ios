// CompassOverlay.swift — 1:1 port of Android CompassOverlay.kt
// Rotating compass needle with altitude display, driven by Unity camera data.
import SwiftUI

// MARK: - CompassState (mirrors Android CompassState object)
// Unity pushes CSV "yaw,height,mode" via NativeCallStubs → NotificationCenter → UnityBridge

class CompassState: ObservableObject {
    static let shared = CompassState()

    @Published var yaw: Float = 0       // Camera yaw in degrees
    @Published var height: Float = 2000 // Camera altitude
    @Published var mode: Int = 0        // 0=North, 1=Follow

    private init() {}

    /// Called from UnityBridge when Unity sends compass CSV
    func update(_ csv: String) {
        let parts = csv.split(separator: ",")
        guard parts.count >= 3 else { return }
        if let y = Float(parts[0]) { yaw = y }
        if let h = Float(parts[1]) { height = h }
        if let m = Int(parts[2]) { mode = m }
    }
}

// MARK: - CompassOverlay View

struct CompassOverlay: View {
    @ObservedObject private var state = CompassState.shared
    @ObservedObject private var themeManager = ThemeManager.shared

    private var isFollowMode: Bool { state.mode == 1 }
    private var modeText: String { isFollowMode ? "CAP" : "NORD" }
    private var modeColor: Color { isFollowMode ? Color(red: 0x4C/255, green: 0xFF/255, blue: 0x80/255) : Color(red: 0x80/255, green: 0xCC/255, blue: 0xFF/255) }

    private var altText: String {
        if state.height >= 1000 {
            return String(format: "%.1fkm", state.height / 1000)
        } else {
            return String(format: "%.0fm", state.height)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Compass circle
            Button(action: toggleCompass) {
                ZStack {
                    // Background
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    ThemeManager.shared.colors.surface.opacity(0.87),
                                    ThemeManager.shared.colors.surfaceVariant.opacity(0.93)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 24
                            )
                        )
                        .frame(width: 48, height: 48)

                    // Compass canvas
                    // Compass canvas — pass theme colors so Canvas redraws on toggle
                    CompassNeedle(
                        yaw: CGFloat(state.yaw),
                        ringColor: ThemeManager.shared.colors.primary.opacity(0.5),
                        southColor: ThemeManager.shared.colors.textPrimary.opacity(0.67),
                        dotColor: ThemeManager.shared.colors.textPrimary
                    )
                        .frame(width: 44, height: 44)
                }
            }
            .buttonStyle(.plain)

            // Mode label
            Text(modeText)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(modeColor)
                .padding(.top, 2)
        }
        .padding(.leading, 12)
    }

    private func toggleCompass() {
        UnityBridge.shared.send("ToggleCompass", value: "")
    }
}

// MARK: - Compass Needle (Canvas equivalent)

private struct CompassNeedle: View {
    let yaw: CGFloat
    let ringColor: Color
    let southColor: Color
    let dotColor: Color

    var body: some View {
        Canvas { context, size in
            let cx = size.width / 2
            let cy = size.height / 2
            let radius = min(size.width, size.height) / 2

            // Outer ring
            context.stroke(
                Path(ellipseIn: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)),
                with: .color(ringColor),
                lineWidth: 2
            )

            // Rotate for needle
            let needleLen = size.height * 0.38
            let needleWidth = size.width * 0.12

            // Apply rotation
            var transform = CGAffineTransform.identity
            transform = transform.translatedBy(x: cx, y: cy)
            transform = transform.rotated(by: -yaw * .pi / 180)
            transform = transform.translatedBy(x: -cx, y: -cy)

            // North (red triangle)
            var northPath = Path()
            northPath.move(to: CGPoint(x: cx, y: cy - needleLen))
            northPath.addLine(to: CGPoint(x: cx - needleWidth, y: cy))
            northPath.addLine(to: CGPoint(x: cx + needleWidth, y: cy))
            northPath.closeSubpath()
            context.fill(northPath.applying(transform), with: .color(Color(red: 0xFF/255, green: 0x33/255, blue: 0x33/255)))

            // South triangle
            var southPath = Path()
            southPath.move(to: CGPoint(x: cx, y: cy + needleLen))
            southPath.addLine(to: CGPoint(x: cx - needleWidth, y: cy))
            southPath.addLine(to: CGPoint(x: cx + needleWidth, y: cy))
            southPath.closeSubpath()
            context.fill(southPath.applying(transform), with: .color(southColor))

            // Center dot
            let dotRadius: CGFloat = 3
            context.fill(
                Path(ellipseIn: CGRect(x: cx - dotRadius, y: cy - dotRadius, width: dotRadius * 2, height: dotRadius * 2)),
                with: .color(dotColor)
            )
        }
    }
}
