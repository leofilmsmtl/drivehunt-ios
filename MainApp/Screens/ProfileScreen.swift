import SwiftUI

/// Player profile screen — full replica of Android's ProfileScreen.kt.
/// Features: avatar, display name, email, role badge, player ID,
/// edit name, change password, hex skins, logout, danger zone resets.
struct ProfileScreen: View {
    var onBack: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared

    // User data
    @State private var displayName = ""
    @State private var email = ""
    @State private var isGuest = false
    @State private var score = 0
    @State private var zonesOwned = 0
    @State private var userId = ""
    @State private var hexColor = "#00FF88"
    @State private var isLoading = true

    // Dialogs
    @State private var showEditNameDialog = false
    @State private var showChangePasswordDialog = false
    @State private var showResetExploDialog = false
    @State private var showResetResourcesDialog = false
    @State private var showResetFullDialog = false
    
    // Account Deletion
    @State private var showDeleteAccountDialog = false
    @State private var showDeleteAccountConfirmDialog = false
    @State private var isDeletingAccount = false

    // Snackbar
    @State private var snackbarMessage: String?

    // Colors — from ThemeManager tokens
    private var theme: ThemeManager { ThemeManager.shared }
    private var accentColor: Color { theme.colors.accent }
    private var bgColor: Color { theme.colors.background }
    private var surfaceColor: Color { theme.colors.surface }
    private var errorColor: Color { theme.colors.error }
    private var warningColor: Color { theme.colors.warning }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(theme.colors.textPrimary)
                }
                Spacer()
                Text("MON PROFIL")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.colors.textPrimary)
                Spacer()
                // ⚠️ IMPORTANT: Use Rectangle with FIXED height, NOT Color.clear.frame(width:).
                // Color.clear without a height constraint expands infinitely in a VStack,
                // making the entire header take up ~40% of the screen.
                Rectangle().fill(Color.clear).frame(width: 20, height: 20)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            if isLoading {
                Spacer()
                ProgressView().tint(accentColor)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Avatar
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(accentColor)
                            .padding(.top, 20)

                        // Name & Email
                        Text(displayName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(theme.colors.textPrimary)
                        Text(email)
                            .font(.system(size: 14))
                            .foregroundColor(theme.colors.textSecondary)

                        // Role Badge
                        roleBadge

                        // Player ID
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(accentColor)
                            Text("ID: \(userId)")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(theme.colors.textPrimary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(surfaceColor)
                        .cornerRadius(16)

                        // Menu Card
                        menuCard

                        // Danger Zone
                        dangerZone

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .background(theme.colors.backgroundGradient.ignoresSafeArea())
        .onAppear { loadProfile() }
        .alert("Modifier le nom", isPresented: $showEditNameDialog) {
            editNameDialogContent
        }
        .alert("Changer le mot de passe", isPresented: $showChangePasswordDialog) {
            changePasswordDialogContent
        }
        .confirmationDialog("Reset Carte ?", isPresented: $showResetExploDialog, titleVisibility: .visible) {
            Button("Confirmer le reset", role: .destructive) { performReset(type: "exploration") }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Ceci effacera vos hexes découverts et possédés.\nVotre SCORE et vos SKINS seront conservés.")
        }
        .confirmationDialog("Reset Ressources ?", isPresented: $showResetResourcesDialog, titleVisibility: .visible) {
            Button("Confirmer le reset", role: .destructive) { performResetResources() }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Ceci remettra toutes vos gemmes à zéro.\nVotre carte et vos skins seront conservés.")
        }
        .confirmationDialog("Reset TOTAL ?", isPresented: $showResetFullDialog, titleVisibility: .visible) {
            Button("Tout Effacer", role: .destructive) { performReset(type: "full") }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Attention : Ceci effacera TOUT (Exploration, Stats, Score). Irréversible.")
        }
        // DELETION DIALOGS
        .confirmationDialog("Supprimer le compte ?", isPresented: $showDeleteAccountDialog, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                // Step 2 confirmation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showDeleteAccountConfirmDialog = true
                }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Attention : Ceci effacera DÉFINITIVEMENT votre compte, votre progression, et vos achats.")
        }
        .confirmationDialog("Confirmation finale", isPresented: $showDeleteAccountConfirmDialog, titleVisibility: .visible) {
            Button("Oui, supprimer DÉFINITIVEMENT", role: .destructive) { deleteAccount() }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Êtes-vous absolument sûr ? Cette action est immédiate et irréversible.")
        }
        .overlay(alignment: .bottom) {
            if let msg = snackbarMessage {
                Text(msg)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(theme.colors.surfaceVariant.cornerRadius(12))
                    .padding(.bottom, 30)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation { snackbarMessage = nil }
                        }
                    }
            }
        }
    }

    // MARK: - Role Badge

    private var roleBadge: some View {
        Group {
            if isGuest {
                Text("Compte Invité")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(warningColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(warningColor.opacity(0.15))
                    .cornerRadius(20)
            } else {
                let roleLabel: String = {
                    if email == "julien@leofilms.ca" { return "⚡ Super Admin" }
                    return "Explorateur"
                }()
                Text("Statut: \(roleLabel)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(accentColor.opacity(0.15))
                    .cornerRadius(20)
            }
        }
    }

    // MARK: - Menu Card

    private var menuCard: some View {
        VStack(spacing: 0) {
            // Edit name
            ProfileMenuItem(icon: "pencil", text: "Modifier le nom", color: accentColor) {
                showEditNameDialog = true
            }
            // Change password (before Hex Skins per user request)
            if !isGuest {
                Divider().background(Color.gray.opacity(0.2))
                ProfileMenuItem(icon: "lock.fill", text: "Changer le mot de passe", color: accentColor) {
                    showChangePasswordDialog = true
                }
                Divider().background(Color.gray.opacity(0.2))
                ProfileMenuItem(icon: "envelope.fill", text: "Changer l'email", color: accentColor) {
                    withAnimation { snackbarMessage = "Contactez le support" }
                }
            }

            Divider().background(Color.gray.opacity(0.2))

            // Hex Skins
            HStack {
                Circle()
                    .fill(Color(hex: hexColor))
                    .frame(width: 32, height: 32)
                    .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 2))
                    .foregroundColor(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hex Skins")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.colors.textPrimary)
                    Text("Personnalise ton territoire")
                        .font(.system(size: 12))
                        .foregroundColor(theme.colors.textSecondary)
                }
                .padding(.leading, 12)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .onTapGesture {
                // Present SkinPicker on top of this modal
                HudOverlayManager.shared.presentSubModal(
                    SkinPickerScreen(onBack: {
                        HudOverlayManager.shared.dismissSubModal()
                    })
                )
            }
        }
        .padding(16)
        .background(theme.colors.surfaceVariant)
        .cornerRadius(20)
    }

    // MARK: - Logout Button

    private var logoutButton: some View {
        Button {
            HudOverlayManager.shared.performLogout()
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Se déconnecter")
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundColor(errorColor)
            .background(errorColor.opacity(0.12))
            .cornerRadius(16)
        }
    }

    // MARK: - Danger Zone

    private var dangerZone: some View {
        VStack(spacing: 8) {
            Text("ZONE DE DANGER")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(errorColor)
                .padding(.top, 12)

            DangerButton(title: "Réinitialiser la Carte", color: warningColor) {
                showResetExploDialog = true
            }
            DangerButton(title: "Réinitialiser les Ressources", color: warningColor) {
                showResetResourcesDialog = true
            }
            DangerButton(title: "Réinitialiser TOUT le Compte", color: errorColor) {
                showResetFullDialog = true
            }
            
            Spacer().frame(height: 16)
            
            // Delete Account (App Store Mandatory)
            DangerButton(title: "Supprimer le Compte (Irréversible)", color: errorColor) {
                showDeleteAccountDialog = true
            }
        }
    }

    // MARK: - Dialog Content

    @State private var editNameText = ""

    private var editNameDialogContent: some View {
        Group {
            TextField("Nom d'affichage", text: $editNameText)
            Button("Enregistrer") { updateDisplayName() }
            Button("Annuler", role: .cancel) {}
        }
    }

    @State private var oldPassword = ""
    @State private var newPassword = ""

    private var changePasswordDialogContent: some View {
        Group {
            SecureField("Ancien mot de passe", text: $oldPassword)
            SecureField("Nouveau mot de passe", text: $newPassword)
            Button("Changer") { changePassword() }
            Button("Annuler", role: .cancel) {}
        }
    }

    // MARK: - API Calls

    private func loadProfile() {
        guard let token = AuthManager.shared.getAccessToken() else {
            isLoading = false
            return
        }

        userId = AuthManager.shared.getPlayerIdFromToken(token)?.prefix(8).description ?? "Unknown"

        let baseUrl = AppState.shared.backendBaseUrl
        guard let url = URL(string: "\(baseUrl)/v1/players/me") else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    withAnimation { snackbarMessage = "Erreur chargement profil" }
                    isLoading = false
                    return
                }

                displayName = json["displayName"] as? String ?? ""
                email = json["email"] as? String ?? ""
                isGuest = json["isGuest"] as? Bool ?? false
                score = json["score"] as? Int ?? 0
                zonesOwned = json["zonesOwned"] as? Int ?? 0
                let hc = json["hexColor"] as? String ?? "#00FF88"
                hexColor = hc.isEmpty ? "#00FF88" : hc
                editNameText = displayName
                isLoading = false
            }
        }.resume()
    }

    private func updateDisplayName() {
        guard let token = AuthManager.shared.getAccessToken() else { return }
        let baseUrl = AppState.shared.backendBaseUrl
        guard let url = URL(string: "\(baseUrl)/v1/players/me") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["displayName": editNameText])

        URLSession.shared.dataTask(with: request) { _, response, _ in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    displayName = editNameText
                    withAnimation { snackbarMessage = "Nom mis à jour !" }
                } else {
                    withAnimation { snackbarMessage = "Erreur mise à jour" }
                }
            }
        }.resume()
    }

    private func changePassword() {
        guard let token = AuthManager.shared.getAccessToken(),
              newPassword.count >= 6 else {
            withAnimation { snackbarMessage = "Minimum 6 caractères" }
            return
        }
        let baseUrl = AppState.shared.backendBaseUrl
        guard let url = URL(string: "\(baseUrl)/v1/auth/password") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "oldPassword": oldPassword,
            "newPassword": newPassword
        ])

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    withAnimation { snackbarMessage = "Mot de passe modifié !" }
                    oldPassword = ""
                    newPassword = ""
                } else {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                    let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "no body"
                    print("❌ Password change failed: \(code) — \(body)")
                    withAnimation { snackbarMessage = "Erreur (\(code)): \(body)" }
                }
            }
        }.resume()
    }

    private func performReset(type: String) {
        guard let token = AuthManager.shared.getAccessToken() else { return }
        let baseUrl = AppState.shared.backendBaseUrl
        guard let url = URL(string: "\(baseUrl)/v1/players/me/reset") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["type": type])

        URLSession.shared.dataTask(with: request) { _, response, _ in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    withAnimation { snackbarMessage = "Reset effectué ✅" }
                } else {
                    withAnimation { snackbarMessage = "Erreur reset" }
                }
            }
        }.resume()
    }

    private func performResetResources() {
        guard let token = AuthManager.shared.getAccessToken() else { return }
        let baseUrl = AppState.shared.backendBaseUrl
        guard let url = URL(string: "\(baseUrl)/v2/game/inventory") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { _, response, _ in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                    withAnimation { snackbarMessage = "Ressources remises à zéro ✅" }
                } else {
                    withAnimation { snackbarMessage = "Erreur reset ressources" }
                }
            }
        }.resume()
    }

    private func deleteAccount() {
        isDeletingAccount = true
        let baseUrl = AppState.shared.backendBaseUrl
        Task {
            let success = await AuthManager.shared.deleteAccount(baseUrl: baseUrl)
            DispatchQueue.main.async {
                isDeletingAccount = false
                if success {
                    HudOverlayManager.shared.performLogout()
                } else {
                    withAnimation { snackbarMessage = "Erreur de suppression du compte" }
                }
            }
        }
    }
}

// MARK: - Reusable Components

struct ProfileMenuItem: View {
    let icon: String
    let text: String
    let color: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(color)
                }
                Text(text)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    .padding(.leading, 8)
                Spacer()
            }
            .padding(.vertical, 12)
        }
    }
}

struct DangerButton: View {
    let title: String
    let color: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(color.opacity(0.12))
                .cornerRadius(12)
        }
    }
}
