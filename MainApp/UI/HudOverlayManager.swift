import SwiftUI
import UIKit

/// UIView subclass that passes through touches on transparent areas.
/// This lets taps reach Unity's view beneath our HUD overlays.
class PassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        // If the hit is this container itself, pass through to Unity
        // Only intercept if a real child (button, etc.) was tapped
        return hit === self ? nil : hit
    }
}

/// Manages the HUD overlays on top of Unity's window.
/// Retains UIHostingControllers so they don't get deallocated.
final class HudOverlayManager {
    static let shared = HudOverlayManager()

    private var bottomHostingController: UIHostingController<AnyView>?
    private var topHostingController: UIHostingController<AnyView>?
    private var menuHostingController: UIHostingController<AnyView>?

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
        unityView.subviews.filter { [999, 998].contains($0.tag) }.forEach { $0.removeFromSuperview() }

        // --- BOTTOM HUD (MENU pill) ---
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

        // --- TOP RIGHT: Resource dock ---
        let topView = AnyView(
            ResourceDockView()
                .onAppear { GemInventoryState.shared.fetchFromBackend() }
        )
        let topHost = UIHostingController(rootView: topView)
        let topContainer = makePassthroughContainer(for: topHost, tag: 998)
        unityView.addSubview(topContainer)

        NSLayoutConstraint.activate([
            topContainer.trailingAnchor.constraint(equalTo: unityView.trailingAnchor, constant: -12),
            topContainer.topAnchor.constraint(equalTo: unityView.safeAreaLayoutGuide.topAnchor, constant: 4),
            topContainer.widthAnchor.constraint(equalToConstant: 320),
            topContainer.heightAnchor.constraint(equalToConstant: 400)
        ])
        self.topHostingController = topHost

        print("✅ HudOverlayManager: Overlays added with touch passthrough")
    }

    private var modalHostingController: UIHostingController<AnyView>?

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
        bottomHostingController = nil
        topHostingController = nil
        menuHostingController = nil
    }
}
// ResourceDockView is now in its own file: ResourceDockView.swift

// MARK: - Bottom HUD Pill (MENU + Attack)

struct GameHudPill: View {
    @ObservedObject private var captureState = CaptureState.shared
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
                            .fill(Color(hex: "#0A0A0A").opacity(0.95))
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
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }

                // === RIGHT SLOT: ATTACK (only when canClaim) ===
                if captureState.claimInfo.canClaim {
                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 1, height: 28)
                        .padding(.horizontal, 4)

                    // Attack button with hold gesture
                    attackButton
                }
            }
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(red: 0.04, green: 0.04, blue: 0.04).opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color(hex: "#00FFAA").opacity(0.5), Color(hex: "#00BBFF").opacity(0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
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

    private let accentColor = Color(hex: "#00FFAA")
    private let mintAccent = Color(hex: "#4DB6AC")
    private let peachAccent = Color(hex: "#FFB74D")
    private let blueAccent = Color(hex: "#64B5F6")
    private let errorColor = Color(hex: "#FF4444")
    private let surfaceColor = Color(hex: "#1A1A2E")

    var body: some View {
        ZStack(alignment: .bottom) {
            // Scrim
            Color.black.opacity(appeared ? 0.9 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismissAnimated() }

            // Sheet
            VStack(spacing: 10) {
                // Drag handle
                Capsule()
                    .fill(Color.white.opacity(0.3))
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

                // Divider
                Divider().background(Color.gray.opacity(0.15)).padding(.horizontal, 16).padding(.vertical, 4)

                // Logout
                Button {
                    AuthManager.shared.logout()
                    onDismiss()
                    // Force restart to login
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        AppState.shared.isLoggedIn = false
                    }
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
                Text("DriveHunt v1.0")
                    .font(.system(size: 11))
                    .foregroundColor(Color.gray.opacity(0.3))
                    .padding(.top, 8)
                    .padding(.bottom, 48)
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(surfaceColor.opacity(0.97))
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

    var body: some View {
        Button(action: action) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accentColor.opacity(0.2))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(accentColor)
                }
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                Text("›")
                    .font(.system(size: 18))
                    .foregroundColor(.gray.opacity(0.3))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "#00C8FF").opacity(0.15), lineWidth: 1)
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

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1)
                .foregroundColor(.gray.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}
