import Foundation
import Combine

/// Shared capture state — equivalent of Android's CaptureState.kt.
/// Tracks claim info (from Unity), hold progress, skin configuration, and results.
final class CaptureState: ObservableObject {
    static let shared = CaptureState()

    // ═══ Claim Info (pushed by Unity via NativeCallProxy) ═══

    struct ClaimInfo: Equatable {
        var hexId: String = ""
        var isSteal: Bool = false
        var ownerName: String = ""
        var canClaim: Bool = false
    }

    @Published var claimInfo = ClaimInfo()

    // ═══ Hex Stats ═══
    @Published var hexOwned: Int = 0
    @Published var hexTotal: Int = 0
    @Published var discoveryPercent: Double = 0.0

    // ═══ Hold Progress ═══
    @Published var isClaimInProgress = false
    @Published var holdProgress: Float = 0.0
    @Published var isLootCapture = false

    // ═══ Claim Result ═══
    struct ClaimResult: Equatable {
        var success: Bool = false
        var wasSteal: Bool = false
        var isLoot: Bool = false
        var lootValue: Int = 0
        var message: String = ""
        var showUntil: Date = .distantPast
    }

    @Published var lastResult = ClaimResult()

    // ═══ Skin Config (T1/T2/T3) ═══
    @Published var playerHexColor = "#00FF88"
    @Published var playerSkinTexture = ""
    @Published var playerSkinAnimation = ""

    private init() {}

    // ═══ Called by Unity via NativeCallProxy ═══

    /// Player entered a claimable hex
    func setClaimable(hexId: String, isSteal: Bool, ownerName: String) {
        DispatchQueue.main.async {
            self.claimInfo = ClaimInfo(hexId: hexId, isSteal: isSteal, ownerName: ownerName, canClaim: true)
            print("⬡ CaptureState: Claimable hex=\(hexId.prefix(8)) steal=\(isSteal)")
        }
    }

    /// Player left the claimable hex
    func clearClaimable() {
        DispatchQueue.main.async {
            self.claimInfo = ClaimInfo()
            self.isClaimInProgress = false
            print("⬡ CaptureState: Cleared claimable")
        }
    }

    /// Unity pushes hex ownership stats
    func setHexStats(owned: Int, total: Int) {
        DispatchQueue.main.async {
            self.hexOwned = owned
            self.hexTotal = total
            self.discoveryPercent = total > 0 ? (Double(owned) / Double(total)) * 100.0 : 0.0
        }
    }

    /// Unity reports claim result (success/fail)
    func onClaimResult(success: Bool, wasSteal: Bool, message: String) {
        DispatchQueue.main.async {
            let displayMessage = success ? message : self.translateFailReason(message)
            self.lastResult = ClaimResult(
                success: success,
                wasSteal: wasSteal,
                message: displayMessage,
                showUntil: Date().addingTimeInterval(2)
            )
            self.isClaimInProgress = false
            self.holdProgress = 0
            if success {
                self.claimInfo = ClaimInfo() // Hide attack icon
            }
        }
    }

    // ═══ Called by Swift (GameHudPill hold gesture) ═══

    func startClaim() {
        isClaimInProgress = true
        holdProgress = 0
        isLootCapture = false
    }

    func cancelClaim() {
        isClaimInProgress = false
        holdProgress = 0
    }

    func failClaim(_ message: String = "ÉCHEC") {
        lastResult = ClaimResult(
            success: false,
            message: message,
            showUntil: Date().addingTimeInterval(2)
        )
        isClaimInProgress = false
        holdProgress = 0
    }

    func updateProgress(_ progress: Float) {
        holdProgress = progress
    }

    // ═══ Skin setters — LIVE PUSH to Unity (matches Android CaptureState.kt) ═══

    func setPlayerHexColor(_ color: String) {
        playerHexColor = color
        // IMMEDIATE: send to Unity right now (matches Android CaptureState.setPlayerHexColor)
        if UnityBridge.shared.isUnityReady {
            UnityBridge.shared.send("SetPlayerHexColor", value: color)
        }
        print("🎨 CaptureState: T1 Color = \(color)")
    }

    func setPlayerSkinTexture(_ texture: String?) {
        playerSkinTexture = texture ?? ""
        // IMMEDIATE: send to Unity right now (matches Android CaptureState.setPlayerSkinTexture)
        let texMsg = (texture?.isEmpty == false && texture != "null") ? texture! : "none"
        if UnityBridge.shared.isUnityReady {
            UnityBridge.shared.send("SetPlayerSkinTexture", value: texMsg)
        }
        print("🎨 CaptureState: T2 Texture = \(playerSkinTexture)")
    }

    func setPlayerSkinAnimation(_ animation: String?) {
        playerSkinAnimation = animation ?? ""
        // IMMEDIATE: send to Unity right now (matches Android CaptureState.setPlayerSkinAnimation)
        let animMsg = (animation?.isEmpty == false && animation != "null") ? animation! : "none"
        if UnityBridge.shared.isUnityReady {
            UnityBridge.shared.send("SetPlayerSkinAnimation", value: animMsg)
        }
        print("🎨 CaptureState: T3 Animation = \(playerSkinAnimation)")
    }

    // ═══ Reset ═══

    func reset() {
        claimInfo = ClaimInfo()
        hexOwned = 0
        hexTotal = 0
        discoveryPercent = 0
        isClaimInProgress = false
        holdProgress = 0
        isLootCapture = false
        playerHexColor = "#00FF88"
        playerSkinTexture = ""
        playerSkinAnimation = ""
        lastResult = ClaimResult()
    }

    // ═══ Helpers ═══

    private func translateFailReason(_ reason: String) -> String {
        switch reason {
        case "INSUFFICIENT_RESOURCES": return "Ressources insuffisantes\nCollecte des gemmes d'abord!"
        case "NOT_IN_HEX": return "Tu dois être dans l'hexagone"
        case "TOO_FAR": return "Trop loin de l'hexagone"
        case "MISSING_H3_INDEX": return "Erreur: hexagone non identifié"
        case "ALREADY_OWNED": return "Tu possèdes déjà cet hexagone"
        case "UNAUTHORIZED": return "Session expirée, reconnecte-toi"
        default: return "Échec: \(reason)"
        }
    }
}
