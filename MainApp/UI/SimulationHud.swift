import SwiftUI

/// Simulation HUD overlay — matches Kotlin's ModernSimulationOverlay.
/// Shows play/pause, speed slider, and stop button when GPS simulation is running.
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
                        .foregroundColor(.white.opacity(0.6))

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
                                .foregroundColor(Color(hex: "#4DB6AC"))
                                .frame(width: 52, height: 52)
                                .background(Color(hex: "#4DB6AC").opacity(0.15))
                                .clipShape(Circle())
                        }

                        // Speed slider
                        VStack(spacing: 4) {
                            Text("\(Int(locationService.simSpeedKmh)) km/h")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)

                            Slider(
                                value: Binding(
                                    get: { locationService.simSpeedKmh },
                                    set: { locationService.setSimulationSpeed($0) }
                                ),
                                in: 10...200,
                                step: 5
                            )
                            .tint(Color(hex: "#64B5F6"))
                        }
                        .frame(maxWidth: .infinity)

                        // Stop
                        Button {
                            locationService.stopRouteSimulation()
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "#E57373"))
                                .frame(width: 44, height: 44)
                                .background(Color(hex: "#E57373").opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(hex: "#1a1a1a").opacity(0.95))
                        .shadow(color: .black.opacity(0.4), radius: 12)
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 100) // Above game HUD
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.4), value: locationService.isSimRunning)
        }
    }
}
