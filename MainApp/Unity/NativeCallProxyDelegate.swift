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
        print("✅ NativeCallProxyDelegate: Initialized (delegate will register after Unity is ready)")

        // Poll for Unity's view to be ready — adds overlays + location + delegate
        // Deferred registration avoids freeze during tile loading
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

                    HudOverlayManager.shared.addOverlays(to: rootView)
                    LocationService.shared.requestPermission()
                    LocationService.shared.startTracking()

                    // Register delegate NOW — Unity view is ready, tiles loaded
                    registerNativeDelegate(self)
                    print("✅ Timer: Overlays added + location started + delegate registered")

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
