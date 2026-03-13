import SwiftUI

// No @main — Unity-first mode uses main.mm as entry point

/// Global app state observable
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isLoggedIn = false
    @Published var backendBaseUrl = "https://drivehunt.ngrok.app"

    private init() {
        isLoggedIn = AuthManager.shared.getAccessToken() != nil
    }
}
