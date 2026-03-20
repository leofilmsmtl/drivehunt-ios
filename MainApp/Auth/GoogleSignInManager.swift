import AuthenticationServices
import CryptoKit
import SwiftUI

/// Manages Sign in with Google using ASWebAuthenticationSession + PKCE.
/// No external SDK needed — uses Apple's built-in web auth.
/// Sends Google's authorization code to the backend for JWT exchange.
class GoogleSignInManager: NSObject, ObservableObject {
    static let shared = GoogleSignInManager()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // PKCE state
    private var codeVerifier: String?
    
    // Google OAuth 2.0 configuration
    private var clientId: String {
        if let id = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String, !id.isEmpty {
            return id
        }
        return ""
    }
    
    private var reversedClientId: String {
        clientId.split(separator: ".").reversed().joined(separator: ".")
    }
    
    private var redirectUri: String {
        // Google's required format for iOS native apps
        "\(reversedClientId):/oauthredirect"
    }
    
    // MARK: - PKCE Helpers
    
    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    /// Start the Google Sign-In flow using system browser sheet
    func signIn(
        baseUrl: String,
        from anchor: ASPresentationAnchor,
        onSuccess: @escaping (String, String?, String, String) -> Void
    ) {
        guard !clientId.isEmpty else {
            errorMessage = "Google Client ID manquant dans Info.plist"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Generate PKCE pair
        let verifier = generateCodeVerifier()
        self.codeVerifier = verifier
        let challenge = generateCodeChallenge(from: verifier)
        
        // Build Google OAuth URL with PKCE
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "prompt", value: "select_account"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        
        guard let authUrl = components.url else {
            errorMessage = "URL OAuth invalide"
            isLoading = false
            return
        }
        
        // Use ASWebAuthenticationSession (native iOS, no SDK needed)
        let session = ASWebAuthenticationSession(
            url: authUrl,
            callbackURLScheme: reversedClientId
        ) { [weak self] callbackURL, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        return
                    }
                    self.errorMessage = "Connexion Google annulée"
                }
                return
            }
            
            guard let callbackURL = callbackURL,
                  let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                  let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Pas de code d'autorisation reçu"
                }
                return
            }
            
            self.exchangeCodeWithBackend(
                code: code,
                baseUrl: baseUrl,
                onSuccess: onSuccess
            )
        }
        
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        session.start()
    }
    
    /// Send Google auth code + PKCE verifier to backend for JWT exchange
    private func exchangeCodeWithBackend(
        code: String,
        baseUrl: String,
        onSuccess: @escaping (String, String?, String, String) -> Void
    ) {
        Task {
            do {
                var body: [String: Any] = [
                    "code": code,
                    "redirectUri": redirectUri,
                    "clientId": clientId,
                    "platform": "ios"
                ]
                // Include PKCE verifier for backend to complete the exchange
                if let verifier = codeVerifier {
                    body["codeVerifier"] = verifier
                }
                
                guard let url = URL(string: "\(baseUrl)/v1/auth/google") else {
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
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                    throw NSError(domain: "", code: statusCode,
                                  userInfo: [NSLocalizedDescriptionKey: "Erreur serveur (\(statusCode))"])
                }
                
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let accessToken = json["accessToken"] as? String ?? json["token"] as? String else {
                    throw NSError(domain: "", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "Réponse invalide"])
                }
                
                let refreshToken = json["refreshToken"] as? String
                let user = json["user"] as? [String: Any]
                let displayName = user?["displayName"] as? String ?? "Joueur"
                let role = user?["role"] as? String ?? json["role"] as? String ?? "user"
                
                await MainActor.run {
                    self.isLoading = false
                    onSuccess(accessToken, refreshToken, displayName, role)
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

// MARK: - ASWebAuthenticationPresentationContextProviding

extension GoogleSignInManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
    }
}
