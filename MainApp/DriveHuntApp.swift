import SwiftUI

// No @main — Unity-first mode uses main.mm as entry point

/// Global app state observable — matches Kotlin's BackendConfigManager + state
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isLoggedIn = false

    // Skin caching for 0ms Unity boot injection (Option A Parity)
    @Published var playerT1Color: String = ""
    @Published var playerT2Texture: String = ""
    @Published var playerT3Animation: String = ""

    // Backend URL configuration
    @Published var ngrokUrl: String {
        didSet { UserDefaults.standard.set(ngrokUrl, forKey: "backend_ngrokUrl") }
    }

    /// Resolved backend URL
    var backendBaseUrl: String {
        return ngrokUrl.isEmpty ? "https://drivehunt.ngrok.app" : ngrokUrl
    }

    private init() {
        isLoggedIn = AuthManager.shared.getAccessToken() != nil
        
        // Force removing old "mode local" cache so it never gets stuck again
        UserDefaults.standard.removeObject(forKey: "backend_useNgrok")
        
        ngrokUrl = UserDefaults.standard.string(forKey: "backend_ngrokUrl")
            ?? "https://drivehunt.ngrok.app"
    }
}
