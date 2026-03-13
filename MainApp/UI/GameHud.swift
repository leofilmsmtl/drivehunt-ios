import SwiftUI

/// Game HUD overlay — displayed on top of Unity.
/// Equivalent of Android's GameHud.kt.
///
/// Displays: zone name, hex stats, score, capture button,
/// navigation buttons to profile/admin.
struct GameHud: View {
    var onProfileTap: () -> Void
    var onAdminTap: () -> Void

    @ObservedObject private var bridge = UnityBridge.shared

    var body: some View {
        VStack(spacing: 0) {
            // Bottom pill HUD
            HStack(spacing: 16) {
                // Profile button
                Button(action: onProfileTap) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }

                Spacer()

                // Zone info (placeholder)
                VStack(spacing: 2) {
                    Text("Zone")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                    Text("—")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                // Admin button
                Button(action: onAdminTap) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
}
