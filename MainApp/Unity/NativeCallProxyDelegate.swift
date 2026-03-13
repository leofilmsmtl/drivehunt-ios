import Foundation

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
        // NOTE: registerNativeDelegate causes app freeze — do NOT enable.
        // Hex capture callbacks will use UnityBridge message-based approach instead.
        print("✅ NativeCallProxyDelegate: Initialized (delegate NOT registered — freeze fix)")

        // Poll for Unity's view to be ready — adds overlays + location
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            DispatchQueue.main.async {
                let bundlePath = Bundle.main.bundlePath + "/Frameworks/UnityFramework.framework"
                if let bundle = Bundle(path: bundlePath),
                   let fwClass = bundle.principalClass as? UnityFramework.Type,
                   let fw = fwClass.getInstance(),
                   let rootView = fw.appController()?.rootView,
                   rootView.subviews.first(where: { $0.tag == 999 }) == nil {

                    // Populate UnityHolder so menu/modal code can find Unity
                    UnityHolder.shared.setFramework(fw)

                    // Check if user is authenticated
                    if let token = AuthManager.shared.getAccessToken(),
                       !AuthManager.shared.isTokenExpired(token) {
                        // Logged in — show game overlays
                        HudOverlayManager.shared.addOverlays(to: rootView)
                        LocationService.shared.requestPermission()
                        LocationService.shared.startTracking()
                        // Send token to Unity
                        UnityBridge.shared.send("ReceiveToken", value: token)
                        print("✅ Timer: Logged in — overlays added + location started")
                    } else {
                        // Not logged in — present login screen
                        let loginView = LoginScreen(onLoginSuccess: { token, refresh, role in
                            AuthManager.shared.saveTokens(access: token, refresh: refresh, role: role)
                            AppState.shared.isLoggedIn = true
                            HudOverlayManager.shared.dismissModal()
                            // Now add game overlays
                            HudOverlayManager.shared.addOverlays(to: rootView)
                            LocationService.shared.requestPermission()
                            LocationService.shared.startTracking()
                            UnityBridge.shared.send("ReceiveToken", value: token)
                        }).environmentObject(AppState.shared)
                        HudOverlayManager.shared.presentModal(loginView)
                        print("✅ Timer: Not logged in — showing login screen")
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
    func setPlayerId(_ playerId: String) { UnityBridge.shared.setPlayerId(playerId) }
    func onInventoryUpdate(_ jsonString: String) { UnityBridge.shared.onInventoryUpdate(jsonString) }
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
