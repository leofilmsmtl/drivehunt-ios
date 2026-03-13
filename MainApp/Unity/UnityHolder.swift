import Foundation
import UnityFramework

/// Singleton holder for the UnityFramework instance.
/// Equivalent of Android's UnityHolder.kt — ensures we don't create
/// multiple instances of the engine, which causes crashes.
///
/// LIFECYCLE:
/// - initialize() called once on first map screen entry
/// - pause()/resume() called on scene transitions
/// - Unity is NEVER destroyed until app termination
final class UnityHolder: NSObject {
    static let shared = UnityHolder()

    private(set) var unityFramework: UnityFramework?
    private(set) var isInitialized = false

    /// Last JWT token sent to Unity (prevents duplicate sends)
    var lastSentToken: String?

    private override init() {
        super.init()
    }

    /// Set framework reference in Unity-first mode
    func setFramework(_ fw: UnityFramework?) {
        self.unityFramework = fw
        self.isInitialized = fw != nil
    }

    // MARK: - Initialization

    /// Load and start the Unity engine.
    /// Must be called on the main thread.
    func initialize() {
        guard !isInitialized else {
            print("♻️ UnityHolder: Already initialized, skipping")
            return
        }

        let bundlePath = Bundle.main.bundlePath + "/Frameworks/UnityFramework.framework"

        guard let bundle = Bundle(path: bundlePath) else {
            print("❌ UnityHolder: Failed to create bundle from path: \(bundlePath)")
            return
        }

        if !bundle.isLoaded {
            bundle.load()
        }

        guard let principalClass = bundle.principalClass as? UnityFramework.Type else {
            print("❌ UnityHolder: Failed to get UnityFramework principal class")
            return
        }

        let fw = principalClass.getInstance()!

        // Must set execute header before running
        withUnsafePointer(to: _mh_execute_header) { headerPtr in
            fw.setExecuteHeader(headerPtr)
        }

        // Data/ folder is in the main app bundle, not in UnityFramework
        let dataBundleId = Bundle.main.bundleIdentifier ?? "com.unity3d.framework"
        print("📦 UnityHolder: Using data bundle: \(dataBundleId)")
        fw.setDataBundleId(dataBundleId)

        // Register for Unity lifecycle callbacks
        fw.register(self)

        // Run Unity in embedded mode (does NOT take over UIApplication)
        fw.runEmbedded(withArgc: CommandLine.argc, argv: CommandLine.unsafeArgv, appLaunchOpts: nil)

        self.unityFramework = fw
        self.isInitialized = true

        print("✅ UnityHolder: Unity engine initialized successfully!")
    }

    // MARK: - Lifecycle

    func pause() {
        unityFramework?.pause(true)
        print("⏸️ UnityHolder: Unity paused")
    }

    func resume() {
        unityFramework?.pause(false)
        print("▶️ UnityHolder: Unity resumed")
    }

    // MARK: - Messaging (Swift → Unity)

    /// Send a message to a Unity GameObject.
    /// Equivalent of UnitySendMessage in Android.
    func sendMessage(
        toGameObject gameObject: String,
        methodName: String,
        message: String
    ) {
        guard isInitialized else {
            print("⚠️ UnityHolder: Cannot send message — Unity not initialized")
            return
        }
        unityFramework?.sendMessageToGO(
            withName: gameObject,
            functionName: methodName,
            message: message
        )
        print("📤 UnityHolder: Sent \(methodName)(\(message)) → \(gameObject)")
    }

    // MARK: - View Access

    /// Returns Unity's root UIView for embedding in SwiftUI
    var rootView: UIView? {
        unityFramework?.appController()?.rootView
    }

    // MARK: - Reset

    func reset() {
        lastSentToken = nil
    }
}

// MARK: - UnityFrameworkListener

extension UnityHolder: UnityFrameworkListener {
    func unityDidUnload(_ notification: Notification!) {
        print("💥 UnityHolder: Unity unloaded")
        isInitialized = false
        unityFramework = nil
    }

    func unityDidQuit(_ notification: Notification!) {
        print("💥 UnityHolder: Unity quit")
        isInitialized = false
        unityFramework = nil
    }
}
