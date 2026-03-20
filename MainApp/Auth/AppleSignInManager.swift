import AuthenticationServices
import SwiftUI

/// Manages Sign in with Apple authentication flow.
/// Sends the Apple `identityToken` to the backend for JWT exchange.
class AppleSignInManager: NSObject, ObservableObject {
    static let shared = AppleSignInManager()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var onSuccess: ((String, String?, String, String) -> Void)?
    
    /// Start the Sign in with Apple flow
    func signIn(
        baseUrl: String,
        onSuccess: @escaping (String, String?, String, String) -> Void
    ) {
        self.onSuccess = onSuccess
        isLoading = true
        errorMessage = nil
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }
    
    /// Exchange Apple identity token with backend for JWT
    private func exchangeTokenWithBackend(
        identityToken: String,
        fullName: String?,
        email: String?,
        userIdentifier: String,
        baseUrl: String
    ) {
        Task {
            do {
                var body: [String: Any] = [
                    "identityToken": identityToken,
                    "appleUserId": userIdentifier
                ]
                if let name = fullName { body["displayName"] = name }
                if let email = email { body["email"] = email }
                
                guard let url = URL(string: "\(baseUrl)/v1/auth/apple") else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL invalide"])
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.timeoutInterval = 15
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                    throw NSError(domain: "", code: code,
                                  userInfo: [NSLocalizedDescriptionKey: "Erreur serveur (\(code))"])
                }
                
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let accessToken = json["accessToken"] as? String ?? json["token"] as? String else {
                    throw NSError(domain: "", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "Réponse invalide"])
                }
                
                let refreshToken = json["refreshToken"] as? String
                let user = json["user"] as? [String: Any]
                let displayName = user?["displayName"] as? String ?? fullName ?? "Joueur"
                let role = user?["role"] as? String ?? json["role"] as? String ?? "user"
                
                await MainActor.run {
                    self.isLoading = false
                    self.onSuccess?(accessToken, refreshToken, displayName, role)
                }
                
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInManager: ASAuthorizationControllerDelegate {
    
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8) else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Impossible de récupérer le token Apple"
            }
            return
        }
        
        // Build full name from name components (only available on FIRST sign-in)
        var fullName: String?
        if let nameComponents = credential.fullName {
            let parts = [nameComponents.givenName, nameComponents.familyName].compactMap { $0 }
            if !parts.isEmpty { fullName = parts.joined(separator: " ") }
        }
        
        let email = credential.email
        let userIdentifier = credential.user
        
        // Get base URL from AppState
        let baseUrl = AppState.shared.backendBaseUrl
        
        exchangeTokenWithBackend(
            identityToken: identityToken,
            fullName: fullName,
            email: email,
            userIdentifier: userIdentifier,
            baseUrl: baseUrl
        )
    }
    
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                // User cancelled — not an error
                return
            }
            self.errorMessage = "Connexion Apple échouée: \(error.localizedDescription)"
        }
    }
}
