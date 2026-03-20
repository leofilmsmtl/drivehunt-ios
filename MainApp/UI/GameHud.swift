import SwiftUI

/// Game HUD overlay — displayed on top of Unity.
/// Equivalent of Android's GameHud.kt.
///
/// Displays: zone name, hex stats, score, capture button,
/// navigation buttons to profile/admin.
struct GameHud: View {
    var onProfileTap: () -> Void
    var onAdminTap: () -> Void

    @ObservedObject private var bridge = UnityBridge.shared
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        ZStack {
            // Simulation HUD (appears when GPS sim is running)
            SimulationHud()

            VStack(spacing: 0) {
                Spacer()

                // Bottom pill HUD
                HStack(spacing: 16) {
                    // Profile button
                    Button(action: onProfileTap) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    }

                    Spacer()

                    // Zone info (placeholder)
                    VStack(spacing: 2) {
                        Text("Zone")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(ThemeManager.shared.colors.textSecondary)
                        Text("—")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    }

                    Spacer()

                    // Admin button
                    Button(action: onAdminTap) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 22))
                            .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(ThemeManager.shared.colors.glassBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(
                                    LinearGradient(
                                        colors: [ThemeManager.shared.colors.primary.opacity(0.5), ThemeManager.shared.colors.secondary.opacity(0.5)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Simulation HUD (matches Kotlin ModernSimulationOverlay)

/// Simulation HUD overlay — shows play/pause, speed slider, and stop button
/// when GPS simulation is running. Matches Kotlin's ModernSimulationOverlay.
struct SimulationHud: View {
    @ObservedObject var locationService = LocationService.shared

    var body: some View {
        if locationService.isSimRunning {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 12) {
                    // Header
                    Text("SIMULATION EN COURS")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundColor(ThemeManager.shared.colors.textPrimary.opacity(0.6))

                    // Controls row
                    HStack(spacing: 16) {
                        // Play / Pause
                        Button {
                            if locationService.isSimPaused {
                                locationService.resumeRouteSimulation()
                            } else {
                                locationService.pauseRouteSimulation()
                            }
                        } label: {
                            Image(systemName: locationService.isSimPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Color(red: 0.3, green: 0.71, blue: 0.67))
                                .frame(width: 52, height: 52)
                                .background(Color(red: 0.3, green: 0.71, blue: 0.67).opacity(0.15))
                                .clipShape(Circle())
                        }

                        // Speed slider
                        VStack(spacing: 4) {
                            Text("\(Int(locationService.simSpeedKmh)) km/h")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(ThemeManager.shared.colors.textPrimary)

                            Slider(
                                value: Binding(
                                    get: { locationService.simSpeedKmh },
                                    set: { locationService.setSimulationSpeed($0) }
                                ),
                                in: 10...200,
                                step: 5
                            )
                            .tint(Color(red: 0.39, green: 0.71, blue: 0.96))
                        }
                        .frame(maxWidth: .infinity)

                        // Stop
                        Button {
                            locationService.stopRouteSimulation()
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(red: 0.9, green: 0.45, blue: 0.45))
                                .frame(width: 44, height: 44)
                                .background(Color(red: 0.9, green: 0.45, blue: 0.45).opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(ThemeManager.shared.colors.surface.opacity(0.95))
                        .shadow(color: .black.opacity(0.4), radius: 12)
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 190) // Above game HUD + bottom menu pill
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.4), value: locationService.isSimRunning)
        }
    }
}
