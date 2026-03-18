import SwiftUI

// ═══════════════════════════════════════════════════════════════
// Premium AAA Season Quest Screen
// 1:1 copy of Android SeasonQuestScreen.kt (460L)
// ═══════════════════════════════════════════════════════════════

// Exact colors from Android (SeasonQuestScreen.kt L42-48)
private let GoldAccent      = Color(red: 1.0, green: 215/255, blue: 0)       // #FFD700
private let PremiumGold     = Color(red: 1.0, green: 165/255, blue: 0)       // #FFA500
private let CompletedGreen  = Color(red: 0,   green: 230/255, blue: 118/255) // #00E676
private let LockedGray      = Color(red: 85/255, green: 85/255, blue: 85/255)  // #555555
private let DarkSurface     = Color(red: 26/255, green: 26/255, blue: 46/255)  // #1A1A2E
private let DarkCard        = Color(red: 22/255, green: 33/255, blue: 62/255)  // #16213E
private let AccentBlue      = Color(red: 15/255, green: 52/255, blue: 96/255)  // #0F3460

struct SeasonQuestScreen: View {
    var onBack: () -> Void

    @ObservedObject private var seasonState = SeasonState.shared

    var body: some View {
        ZStack {
            DarkSurface.ignoresSafeArea()

            if seasonState.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: GoldAccent))
                    .scaleEffect(1.2)
            } else if seasonState.progress?.season == nil {
                // No active season — mirrors Android L82-101
                noSeasonView
            } else {
                seasonContentView
            }

            // Back button — mirrors Android L173-190
            backButton
        }
        .onAppear {
            seasonState.fetchProgress()
        }
    }

    // MARK: - No Season State

    private var noSeasonView: some View {
        VStack(spacing: 16) {
            Image(systemName: "timer")
                .font(.system(size: 64))
                .foregroundColor(GoldAccent)
            Text("Aucune saison active")
                .foregroundColor(.white)
                .font(.system(size: 20, weight: .bold))
        }
    }

    // MARK: - Main Content

    private var seasonContentView: some View {
        let seasonData = seasonState.progress!
        return ScrollView {
            LazyVStack(spacing: 0) {
                // Hero Header — mirrors Android L109-117
                SeasonHeroHeader(
                    seasonName: seasonData.season!.name,
                    endsAt: seasonData.season!.endsAt,
                    completedCount: seasonData.quests.filter { $0.isCompleted }.count,
                    totalCount: seasonData.quests.count,
                    currentLevel: seasonData.currentLevel
                )

                // Refresh button — mirrors Android L120-161
                refreshButton

                // Quest cards — mirrors Android L163-169
                ForEach(Array(seasonData.quests.enumerated()), id: \.element.id) { index, quest in
                    QuestCard(quest: quest, index: index)
                }
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Refresh Button

    private var refreshButton: some View {
        HStack {
            Spacer()
            Button {
                seasonState.evaluateQuests()
            } label: {
                HStack(spacing: 4) {
                    if seasonState.isEvaluating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: GoldAccent))
                            .scaleEffect(0.6)
                            .frame(width: 16, height: 16)
                    }
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundColor(GoldAccent)
                    Text("Actualiser")
                        .font(.system(size: 13))
                        .foregroundColor(GoldAccent)
                }
            }
            .disabled(seasonState.isEvaluating)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    // MARK: - Back Button

    private var backButton: some View {
        VStack {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .padding(16)
                Spacer()
            }
            Spacer()
        }
    }
}

// MARK: - Hero Header
// Mirrors Android SeasonHeroHeader (L194-306)

private struct SeasonHeroHeader: View {
    let seasonName: String
    let endsAt: String
    let completedCount: Int
    let totalCount: Int
    let currentLevel: Int

    private var progressFraction: Double {
        totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0
    }

    private var daysRemaining: Int {
        // ISO 8601 parsing — mirrors Android ZonedDateTime.parse
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let endDate = formatter.date(from: endsAt) else {
            // Try without fractional seconds
            let fmt2 = ISO8601DateFormatter()
            fmt2.formatOptions = [.withInternetDateTime]
            guard let endDate2 = fmt2.date(from: endsAt) else { return 0 }
            return max(0, Calendar.current.dateComponents([.day], from: Date(), to: endDate2).day ?? 0)
        }
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0)
    }

    var body: some View {
        ZStack {
            // Gradient background — matches Android L215-222
            LinearGradient(
                colors: [AccentBlue, DarkSurface],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(height: 200)
        .overlay(
            VStack(spacing: 0) {
                Spacer().frame(height: 56)

                // Title row — mirrors Android L231-274
                HStack {
                    VStack(alignment: .leading) {
                        Text(seasonName.uppercased())
                            .foregroundColor(GoldAccent)
                            .font(.system(size: 24, weight: .black))
                            .tracking(2)
                        Text("Niveau \(currentLevel)")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.system(size: 14))
                    }
                    Spacer()

                    // Timer badge — mirrors Android L251-273
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.system(size: 14))
                            .foregroundColor(GoldAccent)
                        Text("\(daysRemaining)j")
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }

                Spacer()

                // Progress bar — mirrors Android L277-303
                VStack(spacing: 6) {
                    HStack {
                        Text("Progression")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.system(size: 12))
                        Spacer()
                        Text("\(completedCount) / \(totalCount)")
                            .foregroundColor(GoldAccent)
                            .font(.system(size: 12, weight: .bold))
                    }
                    ProgressView(value: progressFraction)
                        .progressViewStyle(LinearProgressViewStyle(tint: GoldAccent))
                        .frame(height: 8)
                        .background(Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Spacer().frame(height: 16)
            }
            .padding(.horizontal, 24)
        )
    }
}

// MARK: - Quest Card
// Mirrors Android QuestCard (L309-458)

private struct QuestCard: View {
    let quest: SeasonQuest
    let index: Int

    private var isPaid: Bool { quest.type == "paid" }
    private var isCompleted: Bool { quest.isCompleted }
    private var progressFraction: Double {
        quest.conditionTarget > 0
            ? min(1, max(0, Double(quest.progress) / Double(quest.conditionTarget)))
            : 0
    }

    var body: some View {
        HStack(spacing: 12) {
            // Level badge — mirrors Android L346-387
            levelBadge

            // Quest info — mirrors Android L392-456
            questInfo
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isCompleted ? CompletedGreen.opacity(0.4) : Color.clear,
                    lineWidth: 1
                )
        )
        .opacity(isPaid && !isCompleted ? 0.6 : 1.0)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private var cardBackground: Color {
        if isCompleted { return DarkCard.opacity(0.9) }
        if isPaid { return Color(red: 17/255, green: 17/255, blue: 17/255) } // #111111
        return DarkCard
    }

    // MARK: - Level Badge

    private var levelBadge: some View {
        ZStack {
            Circle()
                .fill(badgeColor)
                .frame(width: 44, height: 44)
            if isCompleted {
                Circle()
                    .stroke(CompletedGreen, lineWidth: 2)
                    .frame(width: 44, height: 44)
            }

            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(CompletedGreen)
            } else if isPaid {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16))
                    .foregroundColor(PremiumGold.opacity(0.7))
            } else {
                Text("\(quest.level)")
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .bold))
            }
        }
    }

    private var badgeColor: Color {
        if isCompleted { return CompletedGreen.opacity(0.2) }
        if isPaid { return LockedGray.opacity(0.3) }
        return AccentBlue.opacity(0.5)
    }

    // MARK: - Quest Info

    private var questInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title row with PASS badge
            HStack(spacing: 6) {
                Text(quest.title)
                    .foregroundColor(titleColor)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)

                if isPaid && !isCompleted {
                    Text("PASS")
                        .foregroundColor(PremiumGold)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(PremiumGold.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            // Description
            if !isPaid, let desc = quest.description {
                Text(desc)
                    .foregroundColor(.white.opacity(0.5))
                    .font(.system(size: 12))
                    .lineLimit(2)
                    .lineSpacing(2)
            }

            // Progress bar for free uncompleted quests
            if !isPaid && !isCompleted && quest.conditionTarget > 1 {
                HStack(spacing: 8) {
                    ProgressView(value: progressFraction)
                        .progressViewStyle(LinearProgressViewStyle(tint: AccentBlue.opacity(0.8)))
                        .frame(height: 4)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 2))

                    Text("\(quest.progress)/\(quest.conditionTarget)")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.system(size: 11))
                }
                .padding(.top, 2)
            }
        }
    }

    private var titleColor: Color {
        if isCompleted { return CompletedGreen }
        if isPaid { return PremiumGold.opacity(0.7) }
        return .white
    }
}
