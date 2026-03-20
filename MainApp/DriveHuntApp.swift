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

    // Backend URL configuration (matches Kotlin's BackendConfigManager)
    @Published var useNgrok: Bool {
        didSet { UserDefaults.standard.set(useNgrok, forKey: "backend_useNgrok") }
    }
    @Published var ngrokUrl: String {
        didSet { UserDefaults.standard.set(ngrokUrl, forKey: "backend_ngrokUrl") }
    }

    /// Resolved backend URL — matches Kotlin's resolveBaseUrl()
    var backendBaseUrl: String {
        if useNgrok && !ngrokUrl.isEmpty {
            return ngrokUrl
        }
        return "http://localhost:3070"
    }

    private init() {
        isLoggedIn = AuthManager.shared.getAccessToken() != nil
        useNgrok = UserDefaults.standard.object(forKey: "backend_useNgrok") != nil
            ? UserDefaults.standard.bool(forKey: "backend_useNgrok")
            : true  // Default to ngrok
        ngrokUrl = UserDefaults.standard.string(forKey: "backend_ngrokUrl")
            ?? "https://drivehunt.ngrok.app"
    }
}
