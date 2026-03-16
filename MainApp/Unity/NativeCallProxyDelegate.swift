import Foundation
import Combine
/// C-callable function to lazily register the Swift delegate.
@_cdecl("ensureNativeDelegate")
func ensureNativeDelegate() {
    _ = NativeCallProxyDelegate.shared
    print("✅ ensureNativeDelegate: delegate registered")
}

/// Swift-side delegate that receives callbacks from Unity via NativeCallProxy.mm
class NativeCallProxyDelegate: NSObject, NativeCallsProtocol {

    static let shared = NativeCallProxyDelegate()

    override init() {
        super.init()
        // Do NOT call registerNativeDelegate — causes app freeze.
        // Boot callbacks are handled via NSNotificationCenter instead.
        print("✅ NativeCallProxyDelegate: Initialized")

        // Removed premature keyWindow injection which created an unkillable ghost WelcomeScreen

        // Poll for Unity's view to be ready — adds overlays + location
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] timer in
            DispatchQueue.main.async {
                let bundlePath = Bundle.main.bundlePath + "/Frameworks/UnityFramework.framework"
                if let bundle = Bundle(path: bundlePath),
                   let fwClass = bundle.principalClass as? UnityFramework.Type,
                   let fw = fwClass.getInstance(),
                   let rootView = fw.appController()?.rootViewController?.view, // Get the actual view from the VC
                   rootView.subviews.first(where: { $0.tag == 999 }) == nil {

                    // Populate UnityHolder so menu/modal code can find Unity
                    UnityHolder.shared.setFramework(fw)

                    // NEW BOOT SEQUENCE: Combine observer to wait for isUnityReady
                    var cancellable: AnyCancellable?
                    cancellable = UnityBridge.shared.$isUnityReady
                        .filter { $0 == true }
                        .first()
                        .receive(on: DispatchQueue.main)
                        .sink { _ in
                            print("🚀 NativeCallProxyDelegate: Unity is ready! Presenting login/welcome...")
                            
                            // Check if user is authenticated
                            if let token = AuthManager.shared.getAccessToken(),
                               !AuthManager.shared.isTokenExpired(token) {
                                // Logged in — show game overlays
                                HudOverlayManager.shared.addOverlays(to: rootView)
                                LocationService.shared.requestPermission()
                                LocationService.shared.startTracking()
                                // Send backend URL + auth to Unity (matches Kotlin UnityEmbedView + onLoginSuccess)
                                let baseUrl = AppState.shared.backendBaseUrl
                                UnityBridge.shared.send("SetBackendUrl", value: baseUrl)
                                UnityBridge.shared.send("SetAuthToken", value: token)
                                if let playerId = AuthManager.shared.getPlayerIdFromToken(token) {
                                    UnityBridge.shared.send("SetPlayerId", value: playerId)
                                }
                                if let refresh = AuthManager.shared.getRefreshToken() {
                                    UnityBridge.shared.send("SetRefreshToken", value: refresh)
                                }
                                print("✅ Timer: Logged in — overlays added + auth sent + location started")
                                // Show WelcomeScreen AFTER auth sent (boot callbacks can now fire)
                                HudOverlayManager.shared.showLoadingScreen(on: rootView)
                            } else {
                                // Not logged in — present login screen over Unity Window
                                let loginView = LoginScreen(onLoginSuccess: { token, refresh, displayName, role in
                                    AuthManager.shared.saveTokens(access: token, refresh: refresh ?? "", role: role)
                                    AppState.shared.isLoggedIn = true
                                    HudOverlayManager.shared.dismissModal()
                                    // Add game overlays first (behind loading screen)
                                    HudOverlayManager.shared.addOverlays(to: rootView)
                                    // Show WelcomeScreen ON TOP — Unity already booting
                                    HudOverlayManager.shared.showLoadingScreen(on: rootView)
                                    LocationService.shared.requestPermission()
                                    LocationService.shared.startTracking()
                                    // Send backend URL + auth to Unity (matches Kotlin)
                                    let baseUrl = AppState.shared.backendBaseUrl
                                    UnityBridge.shared.send("SetBackendUrl", value: baseUrl)
                                    UnityBridge.shared.send("SetAuthToken", value: token)
                                    if let playerId = AuthManager.shared.getPlayerIdFromToken(token) {
                                        UnityBridge.shared.send("SetPlayerId", value: playerId)
                                    }
                                    if let refresh = refresh {
                                        UnityBridge.shared.send("SetRefreshToken", value: refresh)
                                    }
                                    // Force GPS re-send + explore for new player
                                    LocationService.shared.resetForNewSession()
                                    GemInventoryState.shared.fetchFromBackend()
                                }).environmentObject(AppState.shared)
                                HudOverlayManager.shared.presentModal(loginView)
                                print("✅ Timer: Not logged in — natively showing LoginScreen over Unity")
                            }
                            
                            // KEEP ALIVE (avoid ARC deallocation before execution)
                            _ = cancellable
                        }

                    timer.invalidate()
                }
            }
        }
    }

    func onUnityReady() { UnityBridge.shared.onUnityReady() }
    func onAuthBridged() { UnityBridge.shared.onAuthBridged() }
    func onGPSLocked() { UnityBridge.shared.onGPSLocked() }
    func onHexHistoryLoaded(_ count: String) { UnityBridge.shared.onHexHistoryLoaded(count: count) }
    func onTilesLoaded() { UnityBridge.shared.onTilesLoaded() }
    func onZonesLoaded(_ count: String) { UnityBridge.shared.onZonesLoaded(count: count) }
    func onBootComplete() { UnityBridge.shared.onBootComplete() }
    func onHexTexturesReady() { UnityBridge.shared.onHexTexturesReady() }
    func setPlayerId(_ playerId: String) { UnityBridge.shared.setPlayerId(playerId) }
    func onInventoryUpdate(_ jsonString: String) { UnityBridge.shared.onInventoryUpdate(jsonString) }
    func onTextureProgress(_ progress: String) { UnityBridge.shared.onTextureProgress(progress) }
    func onAtlasProgress(_ progress: String) { UnityBridge.shared.onAtlasProgress(progress) }
    func setClaimable(_ hexId: String, isSteal: Bool, ownerName: String) {
        CaptureState.shared.setClaimable(hexId: hexId, isSteal: isSteal, ownerName: ownerName)
    }
    func clearClaimable() { CaptureState.shared.clearClaimable() }
    func setHexStats(_ owned: Int32, total: Int32) {
        CaptureState.shared.setHexStats(owned: Int(owned), total: Int(total))
    }
    func onClaimResult(_ success: Bool, wasSteal: Bool, message: String) {
        CaptureState.shared.onClaimResult(success: success, wasSteal: wasSteal, message: message)
    }
}
