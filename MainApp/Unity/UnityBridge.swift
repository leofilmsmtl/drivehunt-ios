import Foundation
import Combine

/// UnityBridge — Boot state tracking + Swift → Unity messaging
/// Unity-first mode: NO send() calls during initialization to avoid deadlock
final class UnityBridge: ObservableObject {
    static let shared = UnityBridge()

    private init() {
        // Observe boot callbacks from UnityFramework via NSNotificationCenter
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleBootCallback(_:)),
            name: NSNotification.Name("UnityBootCallback"), object: nil
        )
    }

    @objc private func handleBootCallback(_ notification: Notification) {
        guard let info = notification.userInfo,
              let signal = info["signal"] as? String else { return }
        let arg = info["arg"] as? String ?? ""
        print("📡 UnityBridge received signal: \(signal) arg=\(arg)")

        switch signal {
        case "onUnityReady":        onUnityReady()
        case "onAuthBridged":       onAuthBridged()
        case "onGPSLocked":         onGPSLocked()
        case "onHexHistoryLoaded":  onHexHistoryLoaded(count: arg)
        case "onTilesLoaded":       onTilesLoaded()
        case "onZonesLoaded":       onZonesLoaded(count: arg)
        case "onHexTexturesReady":  onHexTexturesReady()
        case "onTextureProgress":   onTextureProgress(arg)
        case "onBootComplete":      onBootComplete()
        case "setPlayerId":         setPlayerId(arg)
        case "onInventoryUpdate":   onInventoryUpdate(arg)
        case "setClaimable":
            let hexId = info["hexId"] as? String ?? ""
            let isSteal = info["isSteal"] as? Bool ?? false
            let ownerName = info["ownerName"] as? String ?? ""
            CaptureState.shared.setClaimable(hexId: hexId, isSteal: isSteal, ownerName: ownerName)
        case "clearClaimable":
            CaptureState.shared.clearClaimable()
        case "setHexStats":
            let owned = info["owned"] as? Int ?? 0
            let total = info["total"] as? Int ?? 0
            CaptureState.shared.setHexStats(owned: owned, total: total)
        case "onClaimResult":
            let success = info["success"] as? Bool ?? false
            let wasSteal = info["wasSteal"] as? Bool ?? false
            let message = info["message"] as? String ?? ""
            CaptureState.shared.onClaimResult(success: success, wasSteal: wasSteal, message: message)
        default:
            print("⚠️ UnityBridge: unknown signal '\(signal)'")
        }
    }

    @Published var isUnityReady = false
    @Published var isAuthBridged = false
    @Published var isGPSLocked = false
    @Published var isHexHistoryLoaded = false
    @Published var isTilesLoaded = false
    @Published var isZonesLoaded = false
    @Published var isHexTexturesReady = false
    @Published var isBootComplete = false
    @Published var playerId = ""

    // MARK: - Boot Callbacks (called from NativeCallProxy)

    func onUnityReady() {
        print("🎮 [1/7] Unity Engine READY")
        DispatchQueue.main.async { self.isUnityReady = true }
    }

    func onAuthBridged() {
        print("🔑 [2/7] Auth BRIDGED to Unity")
        DispatchQueue.main.async { self.isAuthBridged = true }
    }

    func onGPSLocked() {
        print("📍 [3/7] GPS Origin LOCKED")
        DispatchQueue.main.async { self.isGPSLocked = true }
    }

    func onHexHistoryLoaded(count: String) {
        print("🔷 [4/7] Hex History LOADED (\(count) hexes)")
        DispatchQueue.main.async { self.isHexHistoryLoaded = true }
    }

    func onTilesLoaded() {
        print("🗺️ [5/7] Map Tiles LOADED")
        DispatchQueue.main.async { self.isTilesLoaded = true }
    }

    func onZonesLoaded(count: String) {
        print("🏘️ [6/8] Zones LOADED (\(count) zones)")
        DispatchQueue.main.async { self.isZonesLoaded = true }
    }

    func onHexTexturesReady() {
        print("🎨 [7/8] Hex textures ALL READY")
        DispatchQueue.main.async { self.isHexTexturesReady = true }
    }

    func onBootComplete() {
        print("✅ [8/8] BOOT COMPLETE — all data loaded")
        DispatchQueue.main.async { self.isBootComplete = true }
    }

    func setPlayerId(_ id: String) {
        DispatchQueue.main.async { self.playerId = id }
    }

    func onInventoryUpdate(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("⚠️ UnityBridge: Invalid inventory JSON")
            return
        }
        DispatchQueue.main.async {
            GemInventoryState.shared.update(from: json)
            print("💎 UnityBridge: Inventory updated from Unity")
        }
    }

    // MARK: - Messaging (Swift → Unity)

    private let gameObject = "GameManager"

    func send(_ method: String, value: String) {
        UnityHolder.shared.sendMessage(
            toGameObject: gameObject,
            methodName: method,
            message: value
        )
        let defaults = UserDefaults.standard
        defaults.set(value, forKey: "bridge_\(method)")
        print("📤 UnityBridge: Sent \(method) = \(value)")
    }

    func sendByKey(_ key: String, value: String) {
        let method = keyToMethodName(key)
        send(method, value: value)
    }

    func reset() {
        resetBootFlags()
        playerId = ""
        UnityHolder.shared.reset()
    }

    /// Reset ONLY boot signal flags — used on re-login when Unity is still running.
    func resetBootFlags() {
        isUnityReady = false
        isAuthBridged = false
        isGPSLocked = false
        isHexHistoryLoaded = false
        isTilesLoaded = false
        isZonesLoaded = false
        isHexTexturesReady = false
        isBootComplete = false
        textureProgress = 0.0
        textureProgressTotal = 0
    }

    // Granular texture loading progress (0.0–1.0)
    @Published var textureProgress: Double = 0.0
    @Published var textureProgressTotal: Int = 0

    func onTextureProgress(_ arg: String) {
        let parts = arg.split(separator: ",")
        guard parts.count == 2,
              let loaded = Int(parts[0]),
              let total = Int(parts[1]),
              total > 0 else { return }
        let progress = Double(loaded) / Double(total)
        DispatchQueue.main.async {
            self.textureProgress = progress
            self.textureProgressTotal = total
        }
        print("🖼️ Texture progress: \(loaded)/\(total) (\(Int(progress * 100))%)")
    }

    private func keyToMethodName(_ key: String) -> String {
        let parts = key.split(separator: "_")
        let camelCase = parts.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
        let verbPrefixes = ["Start", "Stop", "Toggle", "Reset", "Refresh", "Clear"]
        if verbPrefixes.contains(where: { camelCase.hasPrefix($0) }) {
            return camelCase
        }
        return "Set\(camelCase)"
    }
}
