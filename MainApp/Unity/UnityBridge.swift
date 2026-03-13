import Foundation
import Combine

/// UnityBridge — Boot state tracking + Swift → Unity messaging
/// Unity-first mode: NO send() calls during initialization to avoid deadlock
final class UnityBridge: ObservableObject {
    static let shared = UnityBridge()

    @Published var isUnityReady = false
    @Published var isAuthBridged = false
    @Published var isGPSLocked = false
    @Published var isHexHistoryLoaded = false
    @Published var isTilesLoaded = false
    @Published var isZonesLoaded = false
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
        print("🏘️ [6/7] Zones LOADED (\(count) zones)")
        DispatchQueue.main.async { self.isZonesLoaded = true }
    }

    func onBootComplete() {
        print("✅ [7/7] BOOT COMPLETE — all data loaded")
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
        isUnityReady = false
        isAuthBridged = false
        isGPSLocked = false
        isHexHistoryLoaded = false
        isTilesLoaded = false
        isZonesLoaded = false
        isBootComplete = false
        playerId = ""
        UnityHolder.shared.reset()
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
