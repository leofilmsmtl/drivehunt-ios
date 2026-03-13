import SwiftUI

/// A SwiftUI view that embeds the Unity 3D engine.
/// Equivalent of Android's UnityEmbedView.kt (AndroidView wrapping UnityPlayer).
///
/// LIFECYCLE STRATEGY (same as Android):
/// - Creates Unity when first displayed
/// - PAUSES Unity when navigating away (Profile, Admin)
/// - RESUMES Unity when returning
/// - NEVER destroys until app termination
struct UnityEmbedView: UIViewRepresentable {

    func makeUIView(context: Context) -> UIView {
        // Initialize Unity if not already done
        if !UnityHolder.shared.isInitialized {
            print("🎮 UnityEmbedView: Initializing Unity engine...")
            UnityHolder.shared.initialize()

            // Register the Swift delegate for Unity → Swift callbacks
            _ = NativeCallProxyDelegate.shared
            print("🔗 UnityEmbedView: NativeCallProxy delegate registered")

            // Tell Unity an iOS native shell is present (hide dev UI)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                UnityBridge.shared.send("SetNativeShellPlatform", value: "iOS")
                UnityBridge.shared.send("HideDevUI", value: "true")
                print("📱 UnityEmbedView: Sent shell identification to Unity")
            }
        }

        guard let rootView = UnityHolder.shared.rootView else {
            print("❌ UnityEmbedView: Unity rootView is nil!")
            let fallback = UIView()
            fallback.backgroundColor = .black
            return fallback
        }

        print("✅ UnityEmbedView: Unity view attached to SwiftUI")
        return rootView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Resume Unity on view update (equivalent of Android's update block)
        UnityHolder.shared.resume()
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        // Pause Unity when view is removed from hierarchy
        print("📱 UnityEmbedView: View dismantled — pausing Unity")
        UnityHolder.shared.pause()
    }
}
