import SwiftUI
import UIKit

/// Main game screen — shows Unity in its own window + HUD overlay.
struct MapScreen: View {
    @Binding var navigationPath: NavigationPath
    @EnvironmentObject var appState: AppState
    @StateObject private var locationService = LocationService.shared
    @ObservedObject private var bridge = UnityBridge.shared

    @State private var hasInitialized = false

    var body: some View {
        Color.clear
            .ignoresSafeArea()
            .onAppear {
                guard !hasInitialized else { return }
                hasInitialized = true
                initializeGameSession()
            }
            .onDisappear {
                UnityHolder.shared.pause()
            }
            .navigationBarHidden(true)
    }

    private func initializeGameSession() {
        print("🎮 MapScreen: Initializing game session...")

        if !UnityHolder.shared.isInitialized {
            UnityHolder.shared.initialize()
            _ = NativeCallProxyDelegate.shared

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                UnityBridge.shared.send("SetNativeShellPlatform", value: "iOS")
                UnityBridge.shared.send("HideDevUI", value: "true")
            }
        }

        UnityHolder.shared.unityFramework?.showUnityWindow()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let unityView = UnityHolder.shared.unityFramework?.appController()?.rootView else { return }
            HudOverlayManager.shared.addOverlays(to: unityView)
        }

        locationService.requestPermission()
        locationService.startTracking()
        UnityBridge.shared.send("SetBackendUrl", value: appState.backendBaseUrl)

        if let token = AuthManager.shared.getAccessToken() {
            UnityBridge.shared.send("SetAuthToken", value: token)
            if let playerId = AuthManager.shared.getPlayerIdFromToken(token) {
                UnityBridge.shared.send("SetPlayerId", value: playerId)
            }
            if let refreshToken = AuthManager.shared.getRefreshToken() {
                UnityBridge.shared.send("SetRefreshToken", value: refreshToken)
            }
            UnityHolder.shared.lastSentToken = token
        }

        sendSettingsToUnity()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { sendSettingsToUnity() }
    }

    private func sendSettingsToUnity() {
        let defaults = UserDefaults.standard
        if let configData = defaults.string(forKey: "game_config"),
           let data = configData.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let fogOpacity = json["fogOpacity"] as? Int ?? 100
            let tilt = max(json["tilt"] as? Int ?? 90, 76)
            let cameraHeight = json["cameraHeight"] as? Int ?? 1000
            let opacityStr = fogOpacity == 100 ? "1" : fogOpacity == 0 ? "0" : String(format: "%.2f", Double(fogOpacity) / 100.0)
            UnityBridge.shared.send("SetFogOpacity", value: opacityStr)
            UnityBridge.shared.send("SetCameraTilt", value: "\(tilt)")
            UnityBridge.shared.send("SetCameraHeight", value: "\(cameraHeight)")
        }
        if let token = AuthManager.shared.getAccessToken(), token != UnityHolder.shared.lastSentToken {
            UnityBridge.shared.send("SetAuthToken", value: token)
            UnityHolder.shared.lastSentToken = token
        }
    }
}
