import SwiftUI

struct HistoryView: View {
    @Environment(ActiveDataService.self) private var dataService
    @State private var selectedPhotoEntries: [PhotoEntry] = []
    @State private var selectedPhotoIndex: Int = 0
    @State private var showPhotoViewer = false

    private var pastWeeks: [WeeklyGoal] { dataService.getPastWeeks() }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.surfaceBackground.ignoresSafeArea()

                if pastWeeks.isEmpty {
                    ContentUnavailableView(
                        "No History Yet",
                        systemImage: "calendar",
                        description: Text("Completed weeks will show up here.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            streakCard
                            ForEach(pastWeeks) { week in
                                NavigationLink(destination: WeekDetailView(week: week)) {
                                    weekCard(week)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("History")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .fullScreenCover(isPresented: $showPhotoViewer) {
            PhotoFullScreenView(photos: selectedPhotoEntries, currentIndex: selectedPhotoIndex)
        }
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        let currentStreak = dataService.getStreak()
        let bestStreak = dataService.getBestStreak()

        return VStack(spacing: 8) {
            if currentStreak > 0 {
                HStack(spacing: 6) {
                    Text("\u{1F525}")
                    Text("Current streak: \(currentStreak) week\(currentStreak == 1 ? "" : "s")")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            } else {
                Text("Start your streak this week!")
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            if bestStreak > 0 {
                Text("Best streak: \(bestStreak) week\(bestStreak == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cardBorder, lineWidth: 1))
    }

    // MARK: - Week Card

    private func weekCard(_ week: WeeklyGoal) -> some View {
        let weekWorkouts = dataService.getWorkouts(for: week)
            .sorted { $0.loggedAt < $1.loggedAt }
        let userADays = dataService.workoutDays(for: dataService.currentUser.id, in: week)
        let userBDays = dataService.workoutDays(for: dataService.partner.id, in: week)
        let isCurrentUserA = dataService.currentUser.id == dataService.pair.userAId
        let myGoal = isCurrentUserA ? week.goalUserA : week.goalUserB
        let partnerGoal = isCurrentUserA ? week.goalUserB : week.goalUserA
        let userAHit = userADays >= myGoal
        let userBHit = userBDays >= partnerGoal

        return VStack(alignment: .leading, spacing: 10) {
            // Week date range
            Text(week.weekStart.weekDateRange(weekStartDay: dataService.pair.weekStartDay))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.textSecondary)

            // Partner results
            HStack(spacing: 16) {
                resultBadge(
                    name: dataService.currentUser.displayName,
                    days: userADays, goal: myGoal, hit: userAHit
                )
                resultBadge(
                    name: dataService.partner.displayName,
                    days: userBDays, goal: partnerGoal, hit: userBHit
                )
                Spacer()
            }

            // Wager outcome
            if let result = week.result {
                Text(wagerOutcome(result: result, wagerText: week.wagerText))
                    .font(.subheadline)
                    .foregroundStyle(result.color)
            }

            // Photo thumbnails
            if !weekWorkouts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        let entries = weekWorkouts.photoEntries(
                            currentUserId: dataService.currentUser.id,
                            currentUserName: dataService.currentUser.displayName,
                            partnerName: dataService.partner.displayName
                        )
                        ForEach(Array(entries.prefix(4).enumerated()), id: \.element.id) { index, entry in
                            WorkoutPhotoView(workout: entry.workout)
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onTapGesture {
                                    selectedPhotoEntries = entries
                                    selectedPhotoIndex = index
                                    showPhotoViewer = true
                                }
                        }
                        if entries.count > 4 {
                            Text("+\(entries.count - 4)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.textSecondary)
                                .frame(width: 56, height: 56)
                                .background(Color.surfaceBackground, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cardBorder, lineWidth: 1))
    }

    private func resultBadge(name: String, days: Int, goal: Int, hit: Bool) -> some View {
        HStack(spacing: 4) {
            Text("\(name) \(days)/\(goal)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text(hit ? "\u{2705}" : "\u{274C}")
                .font(.caption)
        }
    }

    // MARK: - Helpers

    private func wagerOutcome(result: WeekResult, wagerText: String) -> String {
        let isCurrentUserA = dataService.currentUser.id == dataService.pair.userAId
        switch result {
        case .bothHit:
            return "Both hit! \u{1F389}"
        case .aOwes:
            let owerName = isCurrentUserA ? dataService.currentUser.displayName : dataService.partner.displayName
            return "\(owerName) owes: \(wagerText)"
        case .bOwes:
            let owerName = isCurrentUserA ? dataService.partner.displayName : dataService.currentUser.displayName
            return "\(owerName) owes: \(wagerText)"
        case .bothMissed:
            return "Both missed \u{1F605}"
        }
    }

}
