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
                                // PARITY: Fetch equipped skins from backend → CaptureState (matches Android's LaunchedEffect(isLoggedIn))
                                self?.fetchAndPushSkins(token: token)
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
                                    // PARITY: Fetch equipped skins (matches Android's LaunchedEffect(isLoggedIn))
                                    NativeCallProxyDelegate.shared.fetchAndPushSkins(token: token)
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
    func onBootComplete() {
        UnityBridge.shared.onBootComplete()
        // PARITY: Push cached skin data to Unity NOW + delayed retry
        // Matches Android's LaunchedEffect(isBootComplete, currentSkinTexture, ...)
        pushCachedSkinsToUnity()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.pushCachedSkinsToUnity()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.pushCachedSkinsToUnity()
        }
    }
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

    // MARK: - Skin Sync (PARITY with Android AppNavigation.kt LaunchedEffect)

    /// Fetch equipped skins from backend and store in CaptureState.
    /// Matches Android's LaunchedEffect(isLoggedIn) → fetch → CaptureState.setPlayerSkinTexture()
    func fetchAndPushSkins(token: String) {
        print("🎨 NativeCallProxy: Fetching equipped skins...")
        let baseUrl = AppState.shared.backendBaseUrl
        guard let url = URL(string: "\(baseUrl)/v1/skins/inventory") else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 8

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let equipped = json["equipped"] as? [String: Any],
                  let skins = json["skins"] as? [[String: Any]] else {
                print("⚠️ NativeCallProxy: Skin fetch failed — \(error?.localizedDescription ?? "HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")")
                return
            }

            let equippedT1 = equipped["t1"] as? String ?? "default_green"
            let equippedT2 = equipped["t2"] as? String
            let equippedT3 = equipped["t3"] as? String

            var t1Color = "#00FF88"
            var t2Texture = ""
            var t3Animation = ""

            for skin in skins {
                let skinId = skin["id"] as? String ?? ""
                if skinId == equippedT1 { t1Color = skin["color"] as? String ?? "#00FF88" }
                if let t2 = equippedT2, skinId == t2 { t2Texture = skin["texture"] as? String ?? "" }
                if let t3 = equippedT3, skinId == t3 { t3Animation = skin["animation"] as? String ?? "" }
            }

            DispatchQueue.main.async {
                print("🎨 NativeCallProxy: Skins fetched — T1=\(t1Color) T2=\(t2Texture) T3=\(t3Animation)")
                CaptureState.shared.setPlayerHexColor(t1Color)
                CaptureState.shared.setPlayerSkinTexture(t2Texture.isEmpty ? nil : t2Texture)
                CaptureState.shared.setPlayerSkinAnimation(t3Animation.isEmpty ? nil : t3Animation)

                // Push immediately if Unity is ready (covers re-login when isBootComplete was reset)
                // isUnityReady is NEVER reset — it stays true once Unity engine starts
                if UnityBridge.shared.isUnityReady {
                    self.pushCachedSkinsToUnity()
                    // Delayed retry — ensures LoadHistory has finished
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.pushCachedSkinsToUnity()
                    }
                }
            }
        }.resume()
    }

    /// Push cached skin data from CaptureState to Unity.
    /// Matches Android's LaunchedEffect(isBootComplete, currentHexColor, currentSkinTexture, currentSkinAnimation)
    /// Retry logic ported from AppNavigation.swift L36-61: immediate + 2s + 5s
    private func pushCachedSkinsToUnity() {
        // Send #1: Immediate
        sendSkinDataToUnity(attempt: 1)

        // Send #2: 2s delayed retry — catches early Unity timing issues
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.sendSkinDataToUnity(attempt: 2)
        }

        // Send #3: 5s delayed retry — catches late network fetches
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.sendSkinDataToUnity(attempt: 3)
        }
    }

    private func sendSkinDataToUnity(attempt: Int) {
        let t1 = CaptureState.shared.playerHexColor
        let t2 = CaptureState.shared.playerSkinTexture
        let t3 = CaptureState.shared.playerSkinAnimation

        let texVal = t2.isEmpty ? "none" : t2
        let colorVal = t1.isEmpty ? "#00FF88" : t1
        let animVal = t3.isEmpty ? "none" : t3

        print("🎨 NativeCallProxy: Skin push #\(attempt) → tex='\(texVal)' color='\(colorVal)' anim='\(animVal)'")

        // Same order as Android: texture → color → animation
        UnityBridge.shared.send("SetPlayerSkinTexture", value: texVal)
        UnityBridge.shared.send("SetPlayerHexColor", value: colorVal)
        UnityBridge.shared.send("SetPlayerSkinAnimation", value: animVal)
    }
}
