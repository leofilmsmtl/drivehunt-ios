import SwiftUI

/// Email verification screen — 6-digit code entry after registration.
/// Premium glassmorphism design matching LoginScreen.
struct EmailVerificationScreen: View {
    let email: String
    let onVerified: (String, String?, String, String) -> Void  // accessToken, refreshToken, displayName, role
    let onBack: () -> Void
    
    @State private var code = Array(repeating: "", count: 6)
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var resendCooldown = 0
    @State private var appeared = false
    @FocusState private var focusedIndex: Int?
    
    private var theme: ThemeManager { ThemeManager.shared }
    
    var body: some View {
        ZStack {
            theme.colors.backgroundGradient.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer().frame(height: 60)
                
                // Email icon with pulse animation
                ZStack {
                    Circle()
                        .fill(theme.colors.accent.opacity(0.15))
                        .frame(width: 100, height: 100)
                        .scaleEffect(appeared ? 1.1 : 0.9)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: appeared)
                    
                    Image(systemName: "envelope.badge.shield.half.filled")
                        .font(.system(size: 44))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [theme.colors.accent, theme.colors.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(spacing: 8) {
                    Text("Vérification Email")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(theme.colors.textPrimary)
                    
                    Text("Un code à 6 chiffres a été envoyé à")
                        .font(.subheadline)
                        .foregroundColor(theme.colors.textMuted)
                    
                    Text(email)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(theme.colors.accent)
                }
                
                // Error / Success messages
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                if let success = successMessage {
                    Text(success)
                        .font(.caption)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // 6-digit code input
                HStack(spacing: 10) {
                    ForEach(0..<6, id: \.self) { index in
                        codeDigitField(index: index)
                    }
                }
                .padding(.horizontal, 32)
                
                // Verify button
                Button(action: verifyCode) {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView().tint(.black)
                        } else {
                            Image(systemName: "checkmark.shield.fill")
                            Text("Vérifier")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [theme.colors.accent, theme.colors.secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.black)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                .disabled(isLoading || code.joined().count < 6)
                .opacity(code.joined().count < 6 ? 0.5 : 1)
                
                // Resend button
                Button(action: resendCode) {
                    if resendCooldown > 0 {
                        Text("Renvoyer le code (\(resendCooldown)s)")
                            .foregroundColor(theme.colors.textMuted)
                    } else {
                        Text("Renvoyer le code")
                            .foregroundColor(theme.colors.accent)
                    }
                }
                .font(.subheadline)
                .disabled(resendCooldown > 0 || isLoading)
                
                Spacer()
                
                // Back button
                Button(action: onBack) {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Retour")
                    }
                    .foregroundColor(theme.colors.textMuted)
                    .font(.subheadline)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            appeared = true
            focusedIndex = 0
            startResendCooldown()
        }
    }
    
    // MARK: - Code Digit Field
    
    private func codeDigitField(index: Int) -> some View {
        TextField("", text: $code[index])
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 28, weight: .bold, design: .monospaced))
            .foregroundColor(theme.colors.textPrimary)
            .frame(width: 48, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.colors.textPrimary.opacity(focusedIndex == index ? 0.12 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(focusedIndex == index ? theme.colors.accent : Color.clear, lineWidth: 2)
            )
            .focused($focusedIndex, equals: index)
            .onChange(of: code[index]) { newValue in
                let filtered = newValue.filter { $0.isNumber }
                
                if filtered.isEmpty {
                    code[index] = ""
                    // Only move focus back if we are the one being edited
                    if index > 0 && focusedIndex == index {
                        DispatchQueue.main.async { focusedIndex = index - 1 }
                    }
                } else {
                    let newChar = String(filtered.suffix(1))
                    if code[index] != newChar {
                        code[index] = newChar
                    }
                    // Only advance focus forward if we are the one being edited
                    if index < 5 && focusedIndex == index && !newChar.isEmpty {
                        DispatchQueue.main.async { focusedIndex = index + 1 }
                    }
                }
            }
    }
    
    // MARK: - Actions
    
    private func verifyCode() {
        let codeString = code.joined()
        guard codeString.count == 6 else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let baseUrl = AppState.shared.backendBaseUrl
                guard let url = URL(string: "\(baseUrl)/v1/auth/verify-email") else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL invalide"])
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.timeoutInterval = 10
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
                request.httpBody = try JSONSerialization.data(withJSONObject: [
                    "email": email,
                    "code": codeString
                ])
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Pas de réponse"])
                }
                
                guard httpResponse.statusCode == 200 else {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let msg = json["message"] as? String ?? json["error"] as? String {
                        throw NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
                    }
                    throw NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Code invalide"])
                }
                
                // Parse JWT response (backend returns token after verification)
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let accessToken = json["accessToken"] as? String ?? json["token"] as? String else {
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Réponse invalide"])
                }
                
                let refreshToken = json["refreshToken"] as? String
                let user = json["user"] as? [String: Any]
                let displayName = user?["displayName"] as? String ?? email.split(separator: "@").first.map(String.init) ?? "Joueur"
                let role = user?["role"] as? String ?? "user"
                
                await MainActor.run {
                    isLoading = false
                    onVerified(accessToken, refreshToken, displayName, role)
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func resendCode() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let baseUrl = AppState.shared.backendBaseUrl
                guard let url = URL(string: "\(baseUrl)/v1/auth/resend-verification") else { return }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.timeoutInterval = 10
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
                request.httpBody = try JSONSerialization.data(withJSONObject: ["email": email])
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                await MainActor.run {
                    isLoading = false
                    if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                        successMessage = "Code renvoyé ✅"
                        startResendCooldown()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { successMessage = nil }
                    } else {
                        errorMessage = "Échec du renvoi"
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func startResendCooldown() {
        resendCooldown = 60
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if resendCooldown > 0 {
                resendCooldown -= 1
            } else {
                timer.invalidate()
            }
        }
    }
}
