// ThemeManager.swift — Centralized design token system
// 1:1 port of Android DesignTokens + TronTheme + ModernTheme
// Architecture: ObservableObject singleton (mirrors Android CompositionLocal)

import SwiftUI

// MARK: - Theme Enum

enum AppTheme: String, CaseIterable {
    case dark   // TronTheme — neon, cyberpunk
    case light  // ModernTheme — cool blue-white
}

// MARK: - Color Tokens (mirrors Android ColorTokens)

struct ColorTokens {
    // Core Backgrounds
    let background: Color
    let backgroundGradientTop: Color
    let backgroundGradientBottom: Color
    let textOnBackground: Color
    let surface: Color
    let surfaceVariant: Color

    // Text Colors
    let textPrimary: Color
    let textSecondary: Color
    let textMuted: Color

    // Brand / Semantic
    let primary: Color
    let primaryVariant: Color
    let secondary: Color
    let accent: Color
    let accentVariant: Color

    // Functional
    let success: Color
    let successBackground: Color
    let warning: Color
    let warningBackground: Color
    let error: Color
    let errorBackground: Color
    let info: Color

    // Glass / Effects (for HUD elements)
    let glassBackground: Color
    let glassBorder: Color
    let overlayDark: Color

    // Interactive
    let buttonPrimary: Color
    let buttonSecondary: Color
    let buttonDanger: Color
    let buttonDisabled: Color

    // Computed gradient
    var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [backgroundGradientTop, backgroundGradientBottom],
            startPoint: .top, endPoint: .bottom
        )
    }
}

// MARK: - Dark Palette (TronTheme.kt)

private let darkColors = ColorTokens(
    background:              Color(hex: "#0A0A1A"),
    backgroundGradientTop:   Color(hex: "#0A0A1A"),
    backgroundGradientBottom: Color(hex: "#1A1A3E"),
    textOnBackground:        .white,
    surface:                 Color(hex: "#111111"),
    surfaceVariant:          Color(hex: "#1A1A1A"),

    textPrimary:             .white,
    textSecondary:           Color(hex: "#AAAAAA"),
    textMuted:               Color(hex: "#666666"),

    primary:                 Color(hex: "#00FFFF"),
    primaryVariant:          Color(hex: "#00CCCC"),
    secondary:               Color(hex: "#FFD700"),
    accent:                  Color(hex: "#00FF00"),
    accentVariant:           Color(hex: "#00CC00"),

    success:                 Color(hex: "#00FF00"),
    successBackground:       Color(hex: "#002200"),
    warning:                 Color(hex: "#FFD700"),
    warningBackground:       Color(hex: "#332200"),
    error:                   Color(hex: "#FF0055"),
    errorBackground:         Color(hex: "#330011"),
    info:                    Color(hex: "#00FFFF"),

    glassBackground:         Color(hex: "#0A0A0A").opacity(0.9),
    glassBorder:             Color(hex: "#00FFFF").opacity(0.5),
    overlayDark:             Color.black.opacity(0.8),

    buttonPrimary:           Color(hex: "#00FFFF"),
    buttonSecondary:         Color(hex: "#222222"),
    buttonDanger:            Color(hex: "#FF0055"),
    buttonDisabled:          Color(hex: "#444444")
)

// MARK: - Light Palette (ModernTheme.kt)

private let lightColors = ColorTokens(
    background:              Color(hex: "#F0F2FA"),
    backgroundGradientTop:   Color(hex: "#F0F2FA"),
    backgroundGradientBottom: Color(hex: "#E4E7F5"),
    textOnBackground:        Color(hex: "#1C1C2E"),
    surface:                 .white,
    surfaceVariant:          Color(hex: "#F5F6FB"),

    textPrimary:             Color(hex: "#1C1C2E"),
    textSecondary:           Color(hex: "#5A5C70"),
    textMuted:               Color(hex: "#9496A8"),

    primary:                 Color(hex: "#00C896"),
    primaryVariant:          Color(hex: "#00A87E"),
    secondary:               Color(hex: "#3B82F6"),
    accent:                  Color(hex: "#00FFAA"),
    accentVariant:           Color(hex: "#00CC88"),

    success:                 Color(hex: "#22C55E"),
    successBackground:       Color(hex: "#DCFCE7"),
    warning:                 Color(hex: "#F59E0B"),
    warningBackground:       Color(hex: "#FEF3C7"),
    error:                   Color(hex: "#EF4444"),
    errorBackground:         Color(hex: "#FEE2E2"),
    info:                    Color(hex: "#3B82F6"),

    glassBackground:         Color.white.opacity(0.95),
    glassBorder:             Color(hex: "#1C1C2E").opacity(0.08),
    overlayDark:             Color.black.opacity(0.4),

    buttonPrimary:           Color(hex: "#00C896"),
    buttonSecondary:         Color(hex: "#E4E7F5"),
    buttonDanger:            Color(hex: "#EF4444"),
    buttonDisabled:          Color(hex: "#CBCDD8")
)

// MARK: - ThemeManager Singleton

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentTheme: AppTheme {
        didSet { UserDefaults.standard.set(currentTheme.rawValue, forKey: "app_theme") }
    }

    var colors: ColorTokens {
        currentTheme == .dark ? darkColors : lightColors
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "app_theme") ?? "dark"
        self.currentTheme = AppTheme(rawValue: saved) ?? .dark
    }

    func toggleTheme() {
        currentTheme = currentTheme == .dark ? .light : .dark
    }
}
