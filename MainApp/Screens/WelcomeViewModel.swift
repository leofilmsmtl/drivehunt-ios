import SwiftUI
import Combine

/// WelcomeViewModel — 1:1 port of Kotlin's WelcomeViewModel.kt
/// 5-stage boot pipeline with weighted progress.
final class WelcomeViewModel: ObservableObject {

    // Weighted progress — reflects real time proportions (matches Kotlin)
    private static let W_AUTH:   Float = 5    // fast
    private static let W_SERVER: Float = 5    // fast
    private static let W_UNITY:  Float = 10   // ~1-2s
    private static let W_GPS:    Float = 8    // ~1s
    private static let W_DATA:   Float = 60   // atlas + hex history
    private static let W_TOTAL:  Float = W_AUTH + W_SERVER + W_UNITY + W_GPS + W_DATA

    // --- Progress (0→1, weighted) ---
    @Published var progress: Float = 0
    @Published var statusText = "Initialisation..."
    @Published var isReady = false
    @Published var isSafetyLocked = true
    @Published var fatalError: String?
    @Published var textureLoaded: Int = 0
    @Published var textureTotal: Int = 0

    private var progressHighWater: Float = 0  // Progress NEVER goes backwards
    private var cancellables = Set<AnyCancellable>()
    private var bootTask: Task<Void, Never>?

    func startPreloading() {
        guard bootTask == nil else { return }  // Prevent double-start
        bootTask = Task { await runPipeline() }
    }

    private func setWeightedProgress(_ completedWeight: Float) {
        let newProgress = min(max(completedWeight / Self.W_TOTAL, 0), 1)
        if newProgress > progressHighWater {
            progressHighWater = newProgress
        }
        DispatchQueue.main.async { self.progress = self.progressHighWater }
    }

    private func fatal(dev: String, user: String) {
        print("❌ Preflight FATAL: \(dev)")
        DispatchQueue.main.async {
            self.fatalError = user
            self.statusText = "Erreur"
        }
    }

    @MainActor
    private func setStatus(_ text: String) {
        statusText = text
    }

    // MARK: - Boot Pipeline

    private func runPipeline() async {
        let startTime = Date()
        var accWeight: Float = 0
        let bridge = UnityBridge.shared

        await MainActor.run { bridge.resetBootFlags() }
        await setStatus("Authentification...")
        guard let token = AuthManager.shared.getAccessToken() else {
            // Try refresh
            let refreshed = await AuthManager.shared.refreshAccessToken(
                baseUrl: AppState.shared.backendBaseUrl
            )
            if !refreshed || AuthManager.shared.getAccessToken() == nil {
                fatal(dev: "No token + refresh failed", user: "Session expirée. Veuillez vous reconnecter.")
                return
            }
            accWeight += Self.W_AUTH
            setWeightedProgress(accWeight)
            // continue with refreshed token
            return await continueAfterAuth(accWeight: accWeight, startTime: startTime)
        }
        
        

        // Check  expiry
        if AuthManager.shared.isTokenExpired(token) {
            await setStatus("Token expiré — renouvellement...")
            let refreshed = await AuthManager.shared.refreshAccessToken(
                baseUrl: AppState.shared.backendBaseUrl
            )
            if !refreshed {
                fatal(dev: "Refresh failed", user: "Session expirée. Veuillez vous reconnecter.")
                return
            }
        }

        accWeight += Self.W_AUTH
        setWeightedProgress(accWeight)

        await continueAfterAuth(accWeight: accWeight, startTime: startTime)
    }

    private func continueAfterAuth(accWeight: Float, startTime: Date) async {
        var accWeight = accWeight
        let bridge = UnityBridge.shared

        // ===== 2: BACKEND CONNECTIVITY =====
        await setStatus("Connexion au serveur...")
        var backendOk = false
        for attempt in 1...3 {
            if attempt > 1 {
                await setStatus("Serveur (tentative \(attempt)/3)...")
            }
            let baseUrl = AppState.shared.backendBaseUrl
            guard let url = URL(string: "\(baseUrl)/v1/dev/map-config") else { continue }

            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            request.httpMethod = "GET"

            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) {
                    backendOk = true
                    break
                }
            } catch {
                print("⚠️ Preflight: Backend attempt \(attempt): \(error.localizedDescription)")
            }
            if attempt < 3 {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s
            }
        }

        if !backendOk {
            fatal(dev: "Backend unreachable", user: "Serveur injoignable. Vérifiez votre connexion.")
            return
        }
        accWeight += Self.W_SERVER
        setWeightedProgress(accWeight)

        // ===== 3-5: UNITY SYSTEMS (polling loop) =====
        await setStatus("Initialisation du moteur...")

        var unityPassed = false
        var dataPassed = false
        var gpsPassed = false
        var estimateStartMs: Date?

        // Smooth interpolation between texture chunk jumps (100→200→300)
        var lastRealTexCount = 0
        var lastJumpMs = Date()
        var displayedTexCount: Float = 0 // Float for smooth display

        let maxWaitSec: Double = 45
        let waitStart = Date()
        let myGen = await MainActor.run { bridge.sessionGen }

        while Date().timeIntervalSince(waitStart) < maxWaitSec {
            // AAA: abort if session changed (logout during loading)
            let currentGen = await MainActor.run { bridge.sessionGen }
            if currentGen != myGen {
                print("⚠️ Preflight: Session gen changed (\(myGen) → \(currentGen)) — aborting stale loading")
                return
            }

            let isUnityReady = await MainActor.run { bridge.isUnityReady }
            let isGPSLocked = await MainActor.run { bridge.isGPSLocked }
            let isHexHistoryLoaded = await MainActor.run { bridge.isHexHistoryLoaded }
            let texLoaded = await MainActor.run { bridge.textureLoaded }
            let texTotal = await MainActor.run { bridge.textureTotal }

            // Check Unity engine ready
            if !unityPassed && isUnityReady {
                unityPassed = true
                accWeight += Self.W_UNITY
                estimateStartMs = Date()
                print("✅ Preflight: Unity engine ready") // Matches Kotlin
            }

            // Check GPS (soft — continue without it)
            if !gpsPassed && isGPSLocked {
                gpsPassed = true
                accWeight += Self.W_GPS
                print("✅ Preflight: GPS locked") // Matches Kotlin
            }

            // Check hex loading — two paths
            // Path A: textureProgress total > 0 and loaded >= total (atlas or texture streaming done)
            // Path B: Unity explicit signal isHexTexturesReady AND texTotal == 0
            // Note: iOS NSNotifications are async, so isHexHistoryLoaded can arrive
            // *before* the first textureProgress signal, making texTotal=0 temporarily.
            // Using isHexTexturesReady fixes this race condition.
            if !dataPassed {
                let isHexTexturesReady = await MainActor.run { bridge.isHexTexturesReady }
                let atlasComplete = texTotal > 0 && texLoaded >= texTotal
                
                // Safety net: don't dismiss if texTotal == 0 but we know hexes were detected
                let noTexturesNeeded = isHexTexturesReady && texTotal == 0
                
                if atlasComplete || noTexturesNeeded {
                    dataPassed = true
                    displayedTexCount = Float(texLoaded)
                    print("✅ Preflight: Data ready (\(texLoaded)/\(texTotal))")
                }
            }

            // Smooth interpolation: when real count jumps (100→200),
            // animate the displayed count between the old and new values
            if texLoaded > lastRealTexCount {
                lastRealTexCount = texLoaded
                lastJumpMs = Date()
                displayedTexCount = Float(texLoaded) // Snap to new real value
            } else if texTotal > 0 && texLoaded < texTotal {
                // Between real jumps: estimate toward next chunk
                let secSinceJump = Float(Date().timeIntervalSince(lastJumpMs))
                let nextChunk = min(lastRealTexCount + 100, texTotal)
                let gap = Float(nextChunk - lastRealTexCount)
                let estimatedExtra = gap * (1 - 1 / (1 + secSinceJump / 2)) * 0.85
                displayedTexCount = Float(lastRealTexCount) + estimatedExtra
            }

            // Update published texture values
            await MainActor.run {
                self.textureLoaded = Int(displayedTexCount)
                self.textureTotal = max(texTotal, self.textureLoaded) // Prevent UI overflow
            }

            // Progress bar interpolation
            if dataPassed {
                setWeightedProgress(accWeight + Self.W_DATA)
            } else if texTotal > 0 {
                // Smooth progress from interpolated counter
                let smoothProgress = displayedTexCount / Float(texTotal)
                setWeightedProgress(accWeight + Self.W_DATA * smoothProgress)
            } else if unityPassed, let estimateStart = estimateStartMs {
                // Estimated progress during HTTP fetch (no sub-signals)
                let elapsedSec = Float(Date().timeIntervalSince(estimateStart))
                let estimatedProgress = (1 - 1 / (1 + elapsedSec / 4)) * 0.8
                setWeightedProgress(accWeight + Self.W_DATA * estimatedProgress)
            } else {
                setWeightedProgress(accWeight)
            }

            // All done?
            if unityPassed && dataPassed { break }

            // Status text — displayed count is smooth, not chunky
            let displayCount = Int(displayedTexCount)
            if !unityPassed {
                await setStatus("Initialisation du moteur...")
            } else if !dataPassed && displayCount > 0 {
                await setStatus("Chargement des hexagones \(displayCount)/\(texTotal)...")
            } else if !dataPassed {
                await setStatus("Récupération de l'historique...")
            }

            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
        }

        // Check FATAL failures
        if !unityPassed || !dataPassed {
            var missing: [String] = []
            if !unityPassed { missing.append("Unity engine") }
            if !dataPassed { missing.append("Atlas textures") }
            fatal(dev: "Timeout: \(missing.joined(separator: ", "))",
                  user: "Systèmes non prêts. Redémarrez l'application.")
            return
        }

        // GPS soft — warn but continue
        if !gpsPassed {
            accWeight += Self.W_GPS
            setWeightedProgress(accWeight + Self.W_DATA)
            print("⚠️ Preflight: GPS not locked yet, continuing")
        }

        // ===== DONE =====
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed < 3.5 {
            try? await Task.sleep(nanoseconds: UInt64((3.5 - elapsed) * 1_000_000_000)) // Safety warning read time
        }

        await MainActor.run {
            self.progress = 1.0
            self.statusText = "Prêt !"
            self.isSafetyLocked = false
            self.isReady = true
        }
        print("✅ Preflight PASSED in \(String(format: "%.0f", Date().timeIntervalSince(startTime) * 1000))ms")
    }
}
