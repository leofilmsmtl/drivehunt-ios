import SwiftUI
import UIKit
import Combine

/// UIView subclass that passes through touches on non-interactive areas.
/// This lets multi-touch gestures (zoom, tilt) reach Unity's view beneath HUD overlays.
/// Without this, the hosting controller's view eats ALL touches in its frame,
/// preventing Unity from seeing the second finger for pinch/tilt gestures.
///
/// KEY INSIGHT: SwiftUI adds UIGestureRecognizers to internal layout/container views
/// (not just buttons). Simply checking for gesture recognizers in the parent chain
/// causes false positives — transparent spacers/stacks get treated as interactive.
/// Instead we check if the hit view renders visible content before intercepting.
class PassthroughView: UIView {
    /// Posted when a touch passes through to Unity (no interactive SwiftUI element was hit)
    static let touchPassedThrough = Notification.Name("PassthroughView.touchPassedThrough")
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        guard let hitView = hit else {
            NotificationCenter.default.post(name: Self.touchPassedThrough, object: nil)
            return nil
        }
        // This container itself — always pass through
        if hitView === self {
            NotificationCenter.default.post(name: Self.touchPassedThrough, object: nil)
            return nil
        }
        // Check if the hit view is ACTUALLY an interactive control with visible content
        if isVisibleInteractiveView(hitView) { return hit }
        // Everything else (transparent layout views, spacers, stacks) — pass through to Unity
        NotificationCenter.default.post(name: Self.touchPassedThrough, object: nil)
        return nil
    }

    /// A view is "visible interactive" if it's a UIControl OR has gesture recognizers
    /// AND has visible rendered content (not just a transparent SwiftUI layout container).
    private func isVisibleInteractiveView(_ view: UIView) -> Bool {
        // Direct UIControl (UIButton, UISlider, etc.) — always interactive
        if view is UIControl { return true }
        
        // Check the view itself — does it have gesture recognizers AND visible content?
        if hasGestureRecognizers(view) && hasVisibleContent(view) { return true }
        
        // Walk UP the parent chain — but only flag as interactive if we find
        // a UIControl or a view with BOTH recognizers AND visible content
        var parent = view.superview
        while let p = parent {
            if p === self { break }
            if p is UIControl { return true }
            if hasGestureRecognizers(p) && hasVisibleContent(p) { return true }
            parent = p.superview
        }
        return false
    }
    
    private func hasGestureRecognizers(_ view: UIView) -> Bool {
        guard let recognizers = view.gestureRecognizers else { return false }
        return !recognizers.isEmpty
    }
    
    /// Checks if a view has actual visible rendered content (not transparent).
    /// SwiftUI layout containers typically have clear backgrounds and zero-size visible content.
    private func hasVisibleContent(_ view: UIView) -> Bool {
        // Non-clear, non-nil background = visible
        if let bg = view.backgroundColor, bg != .clear && bg.cgColor.alpha > 0.01 {
            return true
        }
        // Has sublayers with non-transparent content (e.g. SwiftUI rendering layers)
        if let layers = view.layer.sublayers {
            for layer in layers {
                if let bg = layer.backgroundColor, UIColor(cgColor: bg) != .clear && bg.alpha > 0.01 {
                    return true
                }
            }
        }
        // Check if this is a SwiftUI control host (has accessible label or specific class)
        let className = String(describing: type(of: view))
        if className.contains("Button") || className.contains("Control") || className.contains("Slider") {
            return true
        }
        return false
    }
}

/// Full-screen container for the Resource Dock.
/// Only the dock button area (top-right, 280×50px below safe area) intercepts touches.
/// Everything else — including the expanded panel (read-only), zoom gestures, menu —
/// passes through to Unity. Posts touchPassedThrough notification on pass-through.
class ResourceDockContainerView: UIView {
    /// The interactive dock button rect (set after layout)
    private var dockButtonRect: CGRect = .zero
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Calculate the dock button rect: top-right corner, below safe area
        let safeTop = safeAreaInsets.top + 12  // matches constraint constant
        let dockWidth: CGFloat = 280
        let dockHeight: CGFloat = 50
        dockButtonRect = CGRect(
            x: bounds.width - dockWidth - 8,  // 8px from right edge
            y: safeTop,
            width: dockWidth,
            height: dockHeight
        )
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Only intercept touches in the dock button area
        if dockButtonRect.contains(point) {
            // Let SwiftUI handle the dock button tap
            return super.hitTest(point, with: event)
        }
        // Everything else: pass through to Unity + post dismiss notification
        NotificationCenter.default.post(name: PassthroughView.touchPassedThrough, object: nil)
        return nil
    }
}

// MARK: - Boot Loading Screen (inlined to avoid target membership issues)


/// Manages the HUD overlays on top of Unity's window.
/// Retains UIHostingControllers so they don't get deallocated.
final class HudOverlayManager {
    static let shared = HudOverlayManager()

    private var bottomHostingController: UIHostingController<AnyView>?
    private var topHostingController: UIHostingController<AnyView>?
    private var menuHostingController: UIHostingController<AnyView>?
    private var simHostingController: UIHostingController<AnyView>?

    // MARK: - Token Refresh Timer (parity with Android UnityEmbedView.kt)
    // Android refreshes proactively every 30s, starting 10min before token expiry.
    // With 1h token: refresh starts at ~50min, 20 retry attempts before 60min expiry.
    private var tokenRefreshTimer: Timer?

    /// Wraps a hosting controller's view in a PassthroughView
    private func makePassthroughContainer(for hostingController: UIHostingController<AnyView>, tag: Int) -> PassthroughView {
        let container = PassthroughView()
        container.backgroundColor = .clear
        container.tag = tag
        container.translatesAutoresizingMaskIntoConstraints = false

        let hosted = hostingController.view!
        hosted.backgroundColor = .clear
        hosted.isOpaque = false
        hosted.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hosted)

        NSLayoutConstraint.activate([
            hosted.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosted.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosted.topAnchor.constraint(equalTo: container.topAnchor),
            hosted.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    func addOverlays(to unityView: UIView) {
        // Remove old overlays
        unityView.subviews.filter { [999, 998, 997, 996, 995, 994].contains($0.tag) }.forEach { $0.removeFromSuperview() }

        // --- CAPTURE OVERLAY (border trace + flash + result popup) ---
        // Added FIRST so it's behind all HUD controls but in front of Unity.
        // Parity: 1:1 with Android CaptureOverlay.kt
        let captureOverlay = AnyView(CaptureOverlayView())
        let captureHost = UIHostingController(rootView: captureOverlay)
        let captureContainer = makePassthroughContainer(for: captureHost, tag: 995)
        unityView.addSubview(captureContainer)

        NSLayoutConstraint.activate([
            captureContainer.leadingAnchor.constraint(equalTo: unityView.leadingAnchor),
            captureContainer.trailingAnchor.constraint(equalTo: unityView.trailingAnchor),
            captureContainer.topAnchor.constraint(equalTo: unityView.topAnchor),
            captureContainer.bottomAnchor.constraint(equalTo: unityView.bottomAnchor),
        ])

        // --- SIMULATION HUD (added FIRST so it's behind other overlays) ---
        let simHud = AnyView(SimulationHud())
        let simHost = UIHostingController(rootView: simHud)
        let simContainer = makePassthroughContainer(for: simHost, tag: 996)
        unityView.addSubview(simContainer)

        NSLayoutConstraint.activate([
            simContainer.leadingAnchor.constraint(equalTo: unityView.leadingAnchor),
            simContainer.trailingAnchor.constraint(equalTo: unityView.trailingAnchor),
            simContainer.topAnchor.constraint(equalTo: unityView.topAnchor),
            simContainer.bottomAnchor.constraint(equalTo: unityView.bottomAnchor)
        ])
        self.simHostingController = simHost

        // --- BOTTOM HUD (MENU pill) — on top of sim overlay ---
        let bottomHud = AnyView(GameHudPill())
        let bottomHost = UIHostingController(rootView: bottomHud)
        let bottomContainer = makePassthroughContainer(for: bottomHost, tag: 999)
        unityView.addSubview(bottomContainer)

        NSLayoutConstraint.activate([
            bottomContainer.leadingAnchor.constraint(equalTo: unityView.leadingAnchor),
            bottomContainer.trailingAnchor.constraint(equalTo: unityView.trailingAnchor),
            bottomContainer.bottomAnchor.constraint(equalTo: unityView.bottomAnchor),
            bottomContainer.heightAnchor.constraint(equalToConstant: 100)
        ])
        self.bottomHostingController = bottomHost

        // --- TOP LEFT: Compass Overlay (mirrors Android MapScreen.kt:371) ---
        let compassView = AnyView(CompassOverlay())
        let compassHost = UIHostingController(rootView: compassView)
        let compassContainer = makePassthroughContainer(for: compassHost, tag: 994)
        unityView.addSubview(compassContainer)

        NSLayoutConstraint.activate([
            compassContainer.leadingAnchor.constraint(equalTo: unityView.leadingAnchor),
            compassContainer.topAnchor.constraint(equalTo: unityView.safeAreaLayoutGuide.topAnchor, constant: -21),
            compassContainer.widthAnchor.constraint(equalToConstant: 80),
            compassContainer.heightAnchor.constraint(equalToConstant: 80),
        ])


        // --- TOP RIGHT: Resource dock ---
        // Uses ResourceDockContainerView — a purpose-built UIView that only intercepts
        // touches in the top 50px (dock button area). Everything below passes through.
        // Full-screen container so the expanded panel renders properly below.
        let topView = AnyView(
            ResourceDockView()
                .onAppear { GemInventoryState.shared.fetchFromBackend() }
        )
        let topHost = UIHostingController(rootView: topView)
        topHost.view.backgroundColor = .clear
        topHost.view.isOpaque = false
        let topContainer = ResourceDockContainerView()
        topContainer.backgroundColor = .clear
        topContainer.tag = 998
        topContainer.translatesAutoresizingMaskIntoConstraints = false
        topContainer.clipsToBounds = false

        let hostedTop = topHost.view!
        hostedTop.backgroundColor = .clear
        hostedTop.isOpaque = false
        hostedTop.translatesAutoresizingMaskIntoConstraints = false
        hostedTop.clipsToBounds = false
        topContainer.addSubview(hostedTop)
        
        NSLayoutConstraint.activate([
            hostedTop.leadingAnchor.constraint(equalTo: topContainer.leadingAnchor),
            hostedTop.trailingAnchor.constraint(equalTo: topContainer.trailingAnchor),
            hostedTop.topAnchor.constraint(equalTo: topContainer.topAnchor),
            hostedTop.bottomAnchor.constraint(equalTo: topContainer.bottomAnchor),
        ])
        
        unityView.addSubview(topContainer)

        NSLayoutConstraint.activate([
            topContainer.leadingAnchor.constraint(equalTo: unityView.leadingAnchor),
            topContainer.trailingAnchor.constraint(equalTo: unityView.trailingAnchor),
            topContainer.topAnchor.constraint(equalTo: unityView.topAnchor),
            topContainer.bottomAnchor.constraint(equalTo: unityView.bottomAnchor),
        ])
        self.topHostingController = topHost

        print("✅ HudOverlayManager: Overlays added with touch passthrough")

        // Start periodic token refresh (matches Android's 30s loop)
        startTokenRefreshTimer()
    }

    // MARK: - Token Refresh Timer (Android parity)
    // Ported from AppNavigation.swift L62-89 — proactive refresh every 30s
    // Android: isTokenExpired() triggers at (exp - 600s) = 10min before expiry
    // With 1h token: ~20 retry attempts in the 10min window before real expiry
    private func startTokenRefreshTimer() {
        tokenRefreshTimer?.invalidate()
        tokenRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let _ = self else { return }
            Task { @MainActor in
                guard let token = AuthManager.shared.getAccessToken() else { return }

                if AuthManager.shared.isTokenExpired(token) {
                    print("🔄 HudOverlayManager: Token near-expiry — refreshing...")
                    let baseUrl = AppState.shared.backendBaseUrl
                    let refreshed = await AuthManager.shared.refreshAccessToken(baseUrl: baseUrl)
                    if refreshed {
                        if let newToken = AuthManager.shared.getAccessToken() {
                            UnityBridge.shared.send("SetAuthToken", value: newToken)
                            UnityHolder.shared.lastSentToken = newToken
                            print("✅ HudOverlayManager: Token refreshed & sent to Unity")
                        }
                    } else {
                        print("❌ HudOverlayManager: Token refresh failed")
                    }
                }
            }
        }
        print("🔄 HudOverlayManager: Token refresh timer started (every 30s)")
    }

    /// Stop token refresh timer — called on logout
    func stopTokenRefreshTimer() {
        tokenRefreshTimer?.invalidate()
        tokenRefreshTimer = nil
        print("🔄 HudOverlayManager: Token refresh timer stopped")
    }

    /// Full application logout sequence. 
    /// Clears tokens, UserDefaults, notifies Unity, resets singletons, and forces navigation to the Login screen.
    @MainActor
    func performLogout(_ beforeStateChange: (() -> Void)? = nil) {
        // 1. Server-side refresh token invalidation (fire-and-forget)
        AuthManager.shared.serverLogout(baseUrl: AppState.shared.backendBaseUrl)

        // 2. Clear tokens
        AuthManager.shared.logout()

        // 3. Clear ALL player-specific UserDefaults (matches Kotlin's SharedPreferences clear)
        for key in ["equipped_skins", "capture_prefs", "DriveHunt_prefs", "app_prefs"] {
            UserDefaults.standard.removeObject(forKey: key)
        }

        // 4. Tell Unity to clear ALL game state + reload scene FIRST
        UnityBridge.shared.send("ResetSession", value: "")
        UnityBridge.shared.send("OnLogout", value: "")

        // 5. Reset ALL Swift singletons (matches Kotlin SessionManager.endSession)
        CaptureState.shared.reset()
        GemInventoryState.shared.reset()
        LocationService.shared.stopRouteSimulation()
        LocationService.shared.resetForNewSession()
        UnityBridge.shared.reset()
        stopTokenRefreshTimer()

        // Hook for UI teardown (e.g. dismissing modals)
        beforeStateChange?()

        // 6. Remove HUD overlays + present login
        // UIKit modal dismissal animation takes exactly 0.4s. 
        // A minimum delay of 0.5s is required to avoid the new presentation failing silently.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.removeOverlays()

            let loginView = LoginScreen(onLoginSuccess: { token, refresh, displayName, role in
                // Login guard: clear previous data
                for key in ["equipped_skins", "capture_prefs", "DriveHunt_prefs", "app_prefs"] {
                    UserDefaults.standard.removeObject(forKey: key)
                }

                // Save new tokens
                AuthManager.shared.saveTokens(access: token, refresh: refresh ?? "", role: role)
                AppState.shared.isLoggedIn = true
                self.dismissModal()

                // Re-add game overlays + show loading screen natively
                if let rootView = UnityHolder.shared.unityFramework?.appController()?.rootView {
                    self.addOverlays(to: rootView)
                    self.showLoadingScreen(on: rootView)
                }
                
                LocationService.shared.requestPermission()
                LocationService.shared.startTracking()

                // Send auth payloads immediately (Unity is already running from the previous session)
                let baseUrl = AppState.shared.backendBaseUrl
                UnityBridge.shared.send("SetBackendUrl", value: baseUrl)
                UnityBridge.shared.send("SetAuthToken", value: token)
                if let playerId = AuthManager.shared.getPlayerIdFromToken(token) {
                    UnityBridge.shared.send("SetPlayerId", value: playerId)
                }
                if let refresh = refresh {
                    UnityBridge.shared.send("SetRefreshToken", value: refresh)
                }
                LocationService.shared.resetForNewSession()
                GemInventoryState.shared.fetchFromBackend()
                // PARITY: Fetch + push equipped skins (matches Android re-login)
                NativeCallProxyDelegate.shared.fetchAndPushSkins(token: token)
                print("✅ Re-login: Auth sent and WelcomeScreen deployed.")
            }).environmentObject(AppState.shared)
            self.presentModal(loginView)
        }
    }


    private var modalHostingController: UIHostingController<AnyView>?
    private var loadingHostingController: UIHostingController<AnyView>?

    /// Present a SwiftUI screen as a fullScreen modal from Unity's root VC.
    /// IMPORTANT: We must present from Unity's VC, NOT from the SwiftUI WindowGroup
    /// window — that window has NavigationStack overhead that adds top offset.
    func presentModal<Content: View>(_ content: Content) {
        guard let unityVC = UnityHolder.shared.unityFramework?.appController()?.rootViewController else {
            print("❌ HudOverlayManager: No Unity root VC")
            return
        }

        // Walk to topmost presented VC
        var topVC: UIViewController = unityVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        let hostingVC = UIHostingController(rootView: AnyView(content))
        hostingVC.view.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1)
        hostingVC.modalPresentationStyle = .overFullScreen

        topVC.present(hostingVC, animated: true)
        self.modalHostingController = hostingVC

        print("📐 Presented modal from: \(type(of: topVC)), frame: \(topVC.view.frame)")
    }

    func dismissModal() {
        modalHostingController?.dismiss(animated: true)
        modalHostingController = nil
    }

    // MARK: - Welcome / Loading Screen
    
    /// Show the real WelcomeScreen as a direct subview overlay instead of a modal!
    /// Crucial because Unity's RootViewController doesn't exist yet on early launch.
    func showLoadingScreen(on targetView: UIView) {
        // Remove old loading if any
        targetView.subviews.first(where: { $0.tag == 997 })?.removeFromSuperview()

        let welcomeView = WelcomeScreen(onContinue: { [weak self] in
            self?.dismissLoadingScreen()
        }).environmentObject(AppState.shared)
        
        let loadingHost = UIHostingController(rootView: AnyView(welcomeView))
        loadingHost.view.backgroundColor = .clear
        loadingHost.view.isOpaque = false
        loadingHost.view.tag = 997
        loadingHost.view.translatesAutoresizingMaskIntoConstraints = false
        targetView.addSubview(loadingHost.view)

        NSLayoutConstraint.activate([
            loadingHost.view.leadingAnchor.constraint(equalTo: targetView.leadingAnchor),
            loadingHost.view.trailingAnchor.constraint(equalTo: targetView.trailingAnchor),
            loadingHost.view.topAnchor.constraint(equalTo: targetView.topAnchor),
            loadingHost.view.bottomAnchor.constraint(equalTo: targetView.bottomAnchor)
        ])
        self.loadingHostingController = loadingHost
        print("✅ WelcomeScreen successfully shown via explicitly added UIHostingController")
    }
    
    func dismissLoadingScreen() {
        guard let host = loadingHostingController else { return }
        UIView.animate(withDuration: 0.5, animations: { [weak host] in
            host?.view.alpha = 0
        }) { [weak self] _ in
            host.view.removeFromSuperview()
            self?.loadingHostingController = nil
            print("✅ WelcomeScreen explicitly dismissed (user tapped continue)")
        }
    }

    // MARK: - Casino Roll Overlay

    private var casinoRollContainer: UIView?
    private var casinoRollHostVC: UIHostingController<CasinoRollOverlay>?  // Fix #5: retain VC

    /// Show the casino roll overlay on top of everything
    func showCasinoRoll(data: LootRollData) {
        guard let unityView = UnityHolder.shared.unityFramework?.appController()?.rootView else { return }
        let parentVC = UnityHolder.shared.unityFramework?.appController()?.rootViewController

        // Remove existing if any
        dismissCasinoRoll()

        let rollView = CasinoRollOverlay(
            rollData: data,
            onDismiss: { [weak self] in
                self?.dismissCasinoRoll()
            }
        )

        let hostVC = UIHostingController(rootView: rollView)
        hostVC.view.backgroundColor = .clear
        hostVC.view.isOpaque = false

        // Fix #5: Proper VC lifecycle
        parentVC?.addChild(hostVC)

        let container = UIView()
        container.tag = 999
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .clear

        hostVC.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hostVC.view)

        NSLayoutConstraint.activate([
            hostVC.view.topAnchor.constraint(equalTo: container.topAnchor),
            hostVC.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hostVC.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostVC.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        unityView.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: unityView.topAnchor),
            container.bottomAnchor.constraint(equalTo: unityView.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: unityView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: unityView.trailingAnchor),
        ])

        hostVC.didMove(toParent: parentVC)

        self.casinoRollContainer = container
        self.casinoRollHostVC = hostVC
        print("🎰 Casino roll overlay shown for: \(data.gemType)")
    }

    func dismissCasinoRoll() {
        // Fix #5: Proper VC cleanup
        casinoRollHostVC?.willMove(toParent: nil)
        casinoRollContainer?.removeFromSuperview()
        casinoRollHostVC?.removeFromParent()
        casinoRollHostVC = nil
        casinoRollContainer = nil

        // Fix #4: Allow new gem taps
        UnityBridge.shared.resetCollectingState()
    }

    /// Present a sub-modal on TOP of the existing modal (e.g., SkinPicker from Profile)
    func presentSubModal<Content: View>(_ content: Content) {
        guard let modalVC = modalHostingController else {
            // No existing modal — fall back to normal presentModal
            presentModal(content)
            return
        }

        // Find topmost presented VC from modal
        var topVC: UIViewController = modalVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        let hostingVC = UIHostingController(rootView: AnyView(content))
        hostingVC.view.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.14, alpha: 1) // #0F0F23
        hostingVC.modalPresentationStyle = .overFullScreen

        topVC.present(hostingVC, animated: true)
    }

    func dismissSubModal() {
        guard let modalVC = modalHostingController else { return }
        // The sub-modal is the one presented ON TOP of the main modal
        if let presented = modalVC.presentedViewController {
            presented.dismiss(animated: true)
        }
    }

    /// Present the menu as an overlay on Unity's view
    func showMenu(on unityView: UIView) {
        // Remove existing
        unityView.subviews.filter { $0.tag == 997 }.forEach { $0.removeFromSuperview() }

        let menuView = AnyView(
            GameMenuOverlay(onDismiss: {
                self.hideMenu(from: unityView)
            })
        )
        let menuHost = UIHostingController(rootView: menuView)
        menuHost.view.backgroundColor = .clear
        menuHost.view.isOpaque = false
        menuHost.view.tag = 997
        menuHost.view.translatesAutoresizingMaskIntoConstraints = false
        unityView.addSubview(menuHost.view)

        NSLayoutConstraint.activate([
            menuHost.view.leadingAnchor.constraint(equalTo: unityView.leadingAnchor),
            menuHost.view.trailingAnchor.constraint(equalTo: unityView.trailingAnchor),
            menuHost.view.topAnchor.constraint(equalTo: unityView.topAnchor),
            menuHost.view.bottomAnchor.constraint(equalTo: unityView.bottomAnchor)
        ])
        self.menuHostingController = menuHost
    }

    func hideMenu(from unityView: UIView) {
        unityView.subviews.filter { $0.tag == 997 }.forEach { $0.removeFromSuperview() }
        menuHostingController = nil
    }

    func removeOverlays() {
        bottomHostingController?.view.removeFromSuperview()
        topHostingController?.view.removeFromSuperview()
        menuHostingController?.view.removeFromSuperview()
        simHostingController?.view.removeFromSuperview()
        companionHostingController?.view.removeFromSuperview()
        bottomHostingController = nil
        topHostingController = nil
        menuHostingController = nil
        simHostingController = nil
        companionHostingController = nil
    }

    // MARK: - Companion Viewer

    private var companionHostingController: UIHostingController<AnyView>?
    var fadeOverlay: UIView?

    /// Creates a branded AAA transition overlay with pulsing dragon icon
    func createBrandedTransition(on parentView: UIView) -> UIView {
        let overlay = UIView(frame: parentView.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.14, alpha: 1.0)

        // Dragon emoji label — centered
        let dragon = UILabel()
        dragon.text = "\u{1F409}"
        dragon.font = UIFont.systemFont(ofSize: 64)
        dragon.textAlignment = .center
        dragon.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(dragon)

        // Loading text
        let label = UILabel()
        label.text = "Chargement..."
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor(white: 1.0, alpha: 0.5)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(label)

        NSLayoutConstraint.activate([
            dragon.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            dragon.centerYAnchor.constraint(equalTo: overlay.centerYAnchor, constant: -16),
            label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            label.topAnchor.constraint(equalTo: dragon.bottomAnchor, constant: 12)
        ])

        // Pulsing animation on the dragon
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 0.9
        pulse.toValue = 1.1
        pulse.duration = 0.8
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        dragon.layer.add(pulse, forKey: "pulse")

        return overlay
    }

    func showCompanion(on unityView: UIView) {
        // Remove existing
        unityView.subviews.filter { $0.tag == 993 }.forEach { $0.removeFromSuperview() }

        // Hide all HUD overlays for clean showcase view
        bottomHostingController?.view.isHidden = true
        topHostingController?.view.isHidden = true
        simHostingController?.view.isHidden = true
        // Hide compass
        unityView.subviews.first(where: { $0.tag == 994 })?.isHidden = true

        let companionView = AnyView(
            CompanionOverlayView(onDismiss: {
                // Don't send ExitCompanionView here — hideCompanion handles timing
                self.hideCompanion(from: unityView)
            })
        )
        let host = UIHostingController(rootView: companionView)
        host.view.backgroundColor = .clear
        host.view.isOpaque = false
        host.view.tag = 993
        host.view.translatesAutoresizingMaskIntoConstraints = false
        unityView.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: unityView.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: unityView.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: unityView.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: unityView.bottomAnchor)
        ])
        self.companionHostingController = host

        // Fade out the black transition overlay after scene is loaded
        if let fade = fadeOverlay {
            UIView.animate(withDuration: 0.3, delay: 0.15, options: .curveEaseOut) {
                fade.alpha = 0
            } completion: { _ in
                fade.removeFromSuperview()
                self.fadeOverlay = nil
            }
        }
    }

    func hideCompanion(from unityView: UIView) {
        guard let window = unityView.window else { return }

        // 1. Show branded transition over everything
        let fade = createBrandedTransition(on: window)
        fade.alpha = 0
        window.addSubview(fade)
        self.fadeOverlay = fade

        UIView.animate(withDuration: 0.2) {
            fade.alpha = 1
        } completion: { _ in
            // 2. Screen is covered — safe to clean up companion overlay
            unityView.subviews.filter { $0.tag == 993 }.forEach { $0.removeFromSuperview() }
            self.companionHostingController = nil
            self.bottomHostingController?.view.isHidden = false
            self.topHostingController?.view.isHidden = false
            self.simHostingController?.view.isHidden = false
            unityView.subviews.first(where: { $0.tag == 994 })?.isHidden = false

            // 3. NOW send exit to Unity (screen is fully covered)
            UnityBridge.shared.send("ExitCompanionView", value: "")

            // 4. Fade out handled by onShowcaseExited callback
            //    Fallback timer in case callback doesn't fire
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.fadeOutTransition()
            }
        }
    }

    /// Called by onShowcaseExited callback or fallback timer
    func fadeOutTransition() {
        guard let fade = fadeOverlay else { return }
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut) {
            fade.alpha = 0
        } completion: { _ in
            fade.removeFromSuperview()
            self.fadeOverlay = nil
        }
    }
}
// ResourceDockView is now in its own file: ResourceDockView.swift

// MARK: - Bottom HUD Pill (MENU + Attack)

struct GameHudPill: View {
    @ObservedObject private var captureState = CaptureState.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var holdProgress: CGFloat = 0
    @State private var isHolding = false
    @State private var holdTimer: Timer? = nil
    @State private var holdStartHexId = ""

    private let claimDuration: Double = 3.0  // seconds for claim
    private let stealDuration: Double = 5.0  // seconds for steal

    var body: some View {
        VStack(spacing: 0) {
            // === Claim Result Toast ===
            if captureState.lastResult.showUntil > Date() {
                let result = captureState.lastResult
                Text(result.message)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(result.success ? Color(hex: "#00FF88") : Color(hex: "#FF5252"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ThemeManager.shared.colors.surface.opacity(0.95))
                    )
                    .padding(.bottom, 8)
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { CaptureState.shared.lastResult = CaptureState.ClaimResult() }
                        }
                    }
            }

            HStack(spacing: 0) {
                // === CENTER: MENU button ===
                Button {
                    guard let unityView = UnityHolder.shared.unityFramework?.appController()?.rootView else { return }
                    HudOverlayManager.shared.showMenu(on: unityView)
                } label: {
                    Text("MENU")
                        .font(.system(size: 20, weight: .heavy))
                        .tracking(3)
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }

                // === RIGHT SLOT: ATTACK (only when canClaim) ===
                if captureState.claimInfo.canClaim {
                    // Divider
                    Rectangle()
                        .fill(ThemeManager.shared.colors.textPrimary.opacity(0.12))
                        .frame(width: 1, height: 28)
                        .padding(.horizontal, 4)

                    // Attack button with hold gesture
                    attackButton
                }
            }
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(ThemeManager.shared.colors.glassBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .strokeBorder(
                                themeManager.currentTheme == .light
                                    ? LinearGradient(
                                        colors: [ThemeManager.shared.colors.textPrimary.opacity(0.1), ThemeManager.shared.colors.textPrimary.opacity(0.06)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                      )
                                    : LinearGradient(
                                        colors: [ThemeManager.shared.colors.primary.opacity(0.5), ThemeManager.shared.colors.secondary.opacity(0.3)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                      ),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: themeManager.currentTheme == .light
                            ? Color.black.opacity(0.1) : Color.black.opacity(0.5),
                        radius: themeManager.currentTheme == .light ? 16 : 10,
                        y: 4
                    )
            )
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Attack Button

    private var attackButton: some View {
        let isSteal = captureState.claimInfo.isSteal
        let attackIcon = isSteal ? "⚔️" : "⬡"
        let attackColor = isSteal ? Color(hex: "#F87171") : Color(hex: "#A78BFA")

        return ZStack {
            // Progress ring
            if isHolding {
                Circle()
                    .trim(from: 0, to: holdProgress)
                    .stroke(attackColor, lineWidth: 3)
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
            }

            Text(attackIcon)
                .font(.system(size: 24))
        }
        .frame(width: 48, height: 48)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isHolding ? attackColor.opacity(0.2) : Color.clear)
        )
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isHolding else { return }
                    startHold()
                }
                .onEnded { _ in
                    if holdProgress < 1.0 {
                        cancelHold()
                    }
                }
        )
    }

    // MARK: - Hold Logic

    private func startHold() {
        isHolding = true
        holdStartHexId = captureState.claimInfo.hexId
        holdProgress = 0
        CaptureState.shared.startClaim()

        // Haptic start
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        // Tell Unity to start hex animation
        let color = CaptureState.shared.playerHexColor
        UnityBridge.shared.send("OnHexAnimStart", value: "\(holdStartHexId)|\(color)")

        // Timer to animate progress
        let duration = captureState.claimInfo.isSteal ? stealDuration : claimDuration
        let interval: Double = 1.0 / 60.0
        let increment = CGFloat(interval / duration)

        holdTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            holdProgress += increment
            CaptureState.shared.updateProgress(Float(holdProgress))

            // Send progress to Unity
            UnityBridge.shared.send("OnHexAnimProgress", value: "\(holdProgress)")

            // Check if player left hex
            if captureState.claimInfo.hexId != holdStartHexId && holdProgress < 0.99 {
                timer.invalidate()
                holdTimer = nil
                isHolding = false
                holdProgress = 0
                CaptureState.shared.failClaim("ÉCHEC")
                let notif = UINotificationFeedbackGenerator()
                notif.notificationOccurred(.error)
                UnityBridge.shared.send("OnHexAnimStop", value: "")
                return
            }

            if holdProgress >= 1.0 {
                timer.invalidate()
                holdTimer = nil
                isHolding = false

                // Haptic success
                let notif = UINotificationFeedbackGenerator()
                notif.notificationOccurred(.success)

                // Verify still in hex
                if captureState.claimInfo.hexId != holdStartHexId {
                    CaptureState.shared.failClaim("ÉCHEC")
                    UnityBridge.shared.send("OnHexAnimStop", value: "")
                } else {
                    // Request claim from Unity
                    UnityBridge.shared.send("OnClaimRequested", value: holdStartHexId)
                }
            }
        }
    }

    private func cancelHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        isHolding = false
        holdProgress = 0
        CaptureState.shared.cancelClaim()

        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        UnityBridge.shared.send("OnHexAnimStop", value: "")
    }
}

// MARK: - Game Menu Overlay (Apple-style bottom sheet)
// Replicates UnityMenuOverlay from ModernUI.kt

struct GameMenuOverlay: View {
    var onDismiss: () -> Void

    @State private var appeared = false
    @State private var dragOffset: CGFloat = 0

    private var theme: ThemeManager { ThemeManager.shared }
    @ObservedObject private var themeManager = ThemeManager.shared

    private var accentColor: Color { theme.colors.accent }
    private let mintAccent = Color(hex: "#4DB6AC")
    private let peachAccent = Color(hex: "#FFB74D")
    private let blueAccent = Color(hex: "#64B5F6")
    private var errorColor: Color { theme.colors.error }
    private var surfaceColor: Color { theme.colors.surface }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Scrim
            Color.black.opacity(appeared ? 0.9 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismissAnimated() }

            // Sheet
            VStack(spacing: 10) {
                // Drag handledis mo
                Capsule()
                    .fill(theme.colors.textPrimary.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)

                // Hero Header — hex shape + stats
                VStack(spacing: 12) {
                    // Hex icon
                    Text("⬡")
                        .font(.system(size: 60))
                        .foregroundColor(accentColor.opacity(0.6))

                    // Stats row
                    HStack {
                        HeroStat(value: "0", label: "DÉCOUVERTS", color: accentColor)
                        Divider().frame(height: 32).background(Color.gray.opacity(0.2))
                        HeroStat(value: "0", label: "POSSÉDÉS", color: accentColor)
                    }
                    .padding(.horizontal, 24)
                }
                .opacity(appeared ? 1 : 0)

                // Row 1: Admin + Profil
                HStack(spacing: 10) {
                    MenuCard(label: "Admin", icon: "gearshape.fill", accentColor: mintAccent) {
                        let adminView = AdminScreen(onBack: { HudOverlayManager.shared.dismissModal() })
                        HudOverlayManager.shared.presentModal(adminView)
                    }
                    MenuCard(label: "Profil", icon: "person.fill", accentColor: peachAccent) {
                        let profileView = ProfileScreen(onBack: { HudOverlayManager.shared.dismissModal() })
                        HudOverlayManager.shared.presentModal(profileView)
                    }
                }
                .padding(.horizontal, 16)
                .offset(y: appeared ? 0 : 60)
                .opacity(appeared ? 1 : 0)

                // Row 2: Saison — mirrors Android ModernUI.kt L666-671
                HStack(spacing: 10) {
                    MenuCard(label: "🏆 Saison", icon: "star.fill", accentColor: Color(red: 1.0, green: 215/255, blue: 0)) {
                        let seasonView = SeasonQuestScreen(onBack: { HudOverlayManager.shared.dismissModal() })
                        HudOverlayManager.shared.presentModal(seasonView)
                    }
                    MenuCard(label: "🏰 Forteresse", icon: "building.columns.fill", accentColor: Color(red: 0xCD/255, green: 0x7F/255, blue: 0x32/255)) {
                        let fortressView = FortressScreen(onBack: { HudOverlayManager.shared.dismissModal() })
                        HudOverlayManager.shared.presentModal(fortressView)
                    }
                }
                .padding(.horizontal, 16)
                .offset(y: appeared ? 0 : 80)
                .opacity(appeared ? 1 : 0)

                // Row 2.5: Compagnon — mirrors Android ModernUI.kt L675-681
                HStack(spacing: 10) {
                    MenuCard(label: "\u{1F409} Compagnon", icon: "pawprint.fill", accentColor: Color(red: 0x66/255, green: 0xBB/255, blue: 0x6A/255)) {
                        guard let unityView = UnityHolder.shared.unityFramework?.appController()?.rootView else { return }
                        guard let window = unityView.window else { return }

                        // 1. Branded transition overlay on KEY WINDOW (above ALL SwiftUI)
                        let fade = HudOverlayManager.shared.createBrandedTransition(on: window)
                        fade.alpha = 0
                        window.addSubview(fade)
                        HudOverlayManager.shared.fadeOverlay = fade

                        UIView.animate(withDuration: 0.2) {
                            fade.alpha = 1
                        } completion: { _ in
                            // 2. Screen is 100% black now — close menu + send to Unity
                            UnityBridge.shared.send("EnterCompanionView", value: "")
                            onDismiss()
                            // 3. showCompanion() is called by Unity callback (onShowcaseReady)
                            //    — no hardcoded timer needed
                        }
                    }
                }
                .padding(.horizontal, 16)
                .offset(y: appeared ? 0 : 80)
                .opacity(appeared ? 1 : 0)

                // Divider
                Divider().background(theme.colors.textSecondary.opacity(0.15)).padding(.horizontal, 16).padding(.vertical, 4)

                // Mode Sombre toggle — mirrors Android ModernUI.kt toggle cards
                HStack(spacing: 10) {
                    ThemeToggleCard(
                        label: "Mode Sombre",
                        icon: themeManager.currentTheme == .dark ? "moon.fill" : "sun.max.fill",
                        isOn: themeManager.currentTheme == .dark,
                        accentColor: accentColor
                    ) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            themeManager.toggleTheme()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .offset(y: appeared ? 0 : 80)
                .opacity(appeared ? 1 : 0)

                // Logout
                Button {
                    HudOverlayManager.shared.performLogout { onDismiss() }
                } label: {
                    Text("Déconnexion")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(errorColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(errorColor.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 16)
                .offset(y: appeared ? 0 : 60)
                .opacity(appeared ? 1 : 0)

                // Version
                Text("P. Hexagon V 1.0")
                    .font(.system(size: 11))
                    .foregroundColor(theme.colors.textSecondary.opacity(0.3))
                    .padding(.top, 8)
                    .padding(.bottom, 48)
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(theme.colors.background.opacity(0.97))
            )
            .offset(y: dragOffset + (appeared ? 0 : 400))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height * 0.35
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 {
                            dismissAnimated()
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
    }

    private func dismissAnimated() {
        withAnimation(.easeIn(duration: 0.25)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }

    private func dismissModal() {
        UnityHolder.shared.unityFramework?.appController()?.rootViewController?.dismiss(animated: true)
    }
}

// MARK: - Menu Card (with chevron)

struct MenuCard: View {
    let label: String
    let icon: String
    let accentColor: Color
    let action: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared

    private var isLight: Bool { themeManager.currentTheme == .light }

    var body: some View {
        Button(action: action) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accentColor.opacity(isLight ? 0.18 : 0.2))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(accentColor)
                }
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ThemeManager.shared.colors.textPrimary.opacity(0.9))
                Spacer()
                Text("›")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(ThemeManager.shared.colors.textSecondary.opacity(0.4))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isLight ? ThemeManager.shared.colors.surface : ThemeManager.shared.colors.textPrimary.opacity(0.05))
                    .shadow(color: isLight ? Color.black.opacity(0.06) : .clear, radius: 8, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isLight
                                    ? ThemeManager.shared.colors.textPrimary.opacity(0.08)
                                    : Color(hex: "#00C8FF").opacity(0.15),
                                lineWidth: 1
                            )
                    )
            )
        }
    }
}

// MARK: - Hero Stat

struct HeroStat: View {
    let value: String
    let label: String
    let color: Color
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1)
                .foregroundColor(ThemeManager.shared.colors.textSecondary.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Theme Toggle Card (mirrors Android ModernUI.kt toggle cards)

struct ThemeToggleCard: View {
    let label: String
    let icon: String
    let isOn: Bool
    let accentColor: Color
    let action: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared

    private var isLight: Bool { themeManager.currentTheme == .light }

    var body: some View {
        Button(action: action) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accentColor.opacity(isLight ? 0.18 : 0.2))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(accentColor)
                }
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ThemeManager.shared.colors.textPrimary.opacity(0.9))
                Spacer()

                // Toggle dot
                ZStack {
                    Capsule()
                        .fill(isOn ? accentColor.opacity(0.3) : Color.gray.opacity(0.2))
                        .frame(width: 44, height: 24)
                    Circle()
                        .fill(isOn ? accentColor : Color.gray.opacity(0.5))
                        .frame(width: 18, height: 18)
                        .offset(x: isOn ? 10 : -10)
                        .animation(.spring(response: 0.3), value: isOn)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isLight ? ThemeManager.shared.colors.surface : ThemeManager.shared.colors.textPrimary.opacity(0.05))
                    .shadow(color: isLight ? Color.black.opacity(0.06) : .clear, radius: 8, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isLight
                                    ? ThemeManager.shared.colors.textPrimary.opacity(0.08)
                                    : Color(hex: "#00C8FF").opacity(0.15),
                                lineWidth: 1
                            )
                    )
            )
        }
    }
}

// MARK: - Companion Overlay View (close-up dragon viewer)

struct CompanionOverlayView: View {
    let onDismiss: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var appeared = false

    // All 19 dragon animations as (emoji, label, animName)
    private let animations: [(String, String, String)] = [
        ("🔥", "Roar", "roar"),
        ("🦅", "Vol", "fly"),
        ("🍪", "Manger", "eat"),
        ("💤", "Dormir", "rest"),
        ("⬆️", "Saut", "jump"),
        ("🚶", "Marche", "walk"),
        ("🏃", "Course", "run"),
        ("💥", "Dégâts", "damage"),
        ("✅", "Oui", "yes"),
        ("❌", "Non", "no"),
        ("💀", "Mort", "die"),
        ("🤢", "Malade", "sick"),
        ("🔥", "Feu", "fire"),
        ("🧍", "Idle", "idle"),
        ("↙️", "Vol G", "fly_l"),
        ("↗️", "Vol D", "fly_r"),
        ("⬆️", "Vol H", "fly_up"),
        ("⬇️", "Vol B", "fly_down"),
        ("🐉", "Vol Feu", "fly_fire"),
    ]

    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack {
                // Top bar
                HStack {
                    Text("🐉 Compagnon")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 4)

                    Spacer()

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) { appeared = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            onDismiss()
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.7))
                            .shadow(color: .black.opacity(0.3), radius: 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 12)

                Spacer()

                // Bottom action area
                VStack(spacing: 12) {
                    // Scrollable animation strip — all 19 animations
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(0..<animations.count, id: \.self) { i in
                                let anim = animations[i]
                                CompanionActionButton(emoji: anim.0, label: anim.1) {
                                    UnityBridge.shared.send("CompanionPlayAnimation", value: anim.2)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // Randomize button
                    Button(action: {
                        UnityBridge.shared.send("RandomizeDragon", value: "")
                    }) {
                        HStack(spacing: 8) {
                            Text("🎲")
                                .font(.system(size: 20))
                            Text("Randomiser")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#22C55E"), Color(hex: "#16A34A")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: Color(hex: "#22C55E").opacity(0.4), radius: 12, y: 4)
                        )
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4)) { appeared = true }
        }
    }
}

// MARK: - Companion Action Button

struct CompanionActionButton: View {
    let emoji: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(emoji)
                    .font(.system(size: 22))
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(width: 56, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
        }
    }
}

