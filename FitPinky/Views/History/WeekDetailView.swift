import SwiftUI

struct WeekDetailView: View {
    @Environment(ActiveDataService.self) private var dataService
    let week: WeeklyGoal

    @State private var ringProgress: CGFloat = 0
    @State private var selectedPhotoEntries: [PhotoEntry] = []
    @State private var selectedPhotoIndex: Int = 0
    @State private var showPhotoViewer = false

    private var weekWorkouts: [Workout] {
        dataService.getWorkouts(for: week).sorted { $0.loggedAt < $1.loggedAt }
    }
    private var userADays: Int {
        dataService.workoutDays(for: dataService.currentUser.id, in: week)
    }
    private var userBDays: Int {
        dataService.workoutDays(for: dataService.partner.id, in: week)
    }
    private var isCurrentUserA: Bool { dataService.currentUser.id == dataService.pair.userAId }
    private var myGoal: Int { isCurrentUserA ? week.goalUserA : week.goalUserB }
    private var partnerGoal: Int { isCurrentUserA ? week.goalUserB : week.goalUserA }

    var body: some View {
        ZStack {
            Color.surfaceBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    progressRingsCard
                    dayByDayCard
                    wagerResultCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle(week.weekStart.weekDateRange(weekStartDay: dataService.pair.weekStartDay))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { ringProgress = 1 }
        }
        .fullScreenCover(isPresented: $showPhotoViewer) {
            PhotoFullScreenView(photos: selectedPhotoEntries, currentIndex: selectedPhotoIndex)
        }
    }

    // MARK: - Progress Rings

    private var progressRingsCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                ProgressRingView(
                    name: dataService.currentUser.displayName,
                    current: userADays,
                    goal: myGoal,
                    ringProgress: ringProgress
                )
                ProgressRingView(
                    name: dataService.partner.displayName,
                    current: userBDays,
                    goal: partnerGoal,
                    ringProgress: ringProgress
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cardBorder, lineWidth: 1))
    }

    // MARK: - Day-by-Day

    private var dayByDayCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Day by Day")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.bottom, 12)

            let allEntries = weekWorkouts.photoEntries(
                currentUserId: dataService.currentUser.id,
                currentUserName: dataService.currentUser.displayName,
                partnerName: dataService.partner.displayName
            )

            ForEach(0..<7, id: \.self) { dayOffset in
                let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: week.weekStart)!
                let dayName = date.formatted(.dateTime.weekday(.wide))
                let currentUserWorkouts = workoutsForDay(date: date, userId: dataService.currentUser.id)
                let partnerWorkouts = workoutsForDay(date: date, userId: dataService.partner.id)
                let hasWorkouts = !currentUserWorkouts.isEmpty || !partnerWorkouts.isEmpty

                VStack(spacing: 0) {
                    if dayOffset > 0 {
                        Divider()
                            .background(Color.cardBorder)
                    }

                    HStack(spacing: 12) {
                        Text(dayName)
                            .font(.subheadline)
                            .foregroundStyle(hasWorkouts ? .white : Color.textSecondary)
                            .frame(width: 90, alignment: .leading)

                        // Current user's photo or empty
                        dayThumbnail(
                            workouts: currentUserWorkouts,
                            name: dataService.currentUser.displayName,
                            allEntries: allEntries
                        )

                        // Partner's photo or empty
                        dayThumbnail(
                            workouts: partnerWorkouts,
                            name: dataService.partner.displayName,
                            allEntries: allEntries
                        )

                        Spacer()
                    }
                    .padding(.vertical, 10)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cardBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func dayThumbnail(workouts: [Workout], name: String, allEntries: [PhotoEntry]) -> some View {
        if let workout = workouts.first, workout.hasPhoto {
            WorkoutPhotoView(workout: workout)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onTapGesture {
                    selectedPhotoEntries = allEntries
                    selectedPhotoIndex = allEntries.firstIndex { $0.id == workout.id } ?? 0
                    showPhotoViewer = true
                }
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.surfaceBackground)
                .frame(width: 44, height: 44)
                .overlay {
                    Text("—")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary.opacity(0.5))
                }
        }
    }

    // MARK: - Wager Result

    private var wagerResultCard: some View {
        VStack(spacing: 8) {
            if let result = week.result {
                Text(resultTitle(result))
                    .font(.headline)
                    .foregroundStyle(result.color)
            }
            if !week.wagerText.isEmpty {
                Text(week.wagerText)
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cardBorder, lineWidth: 1))
    }

    // MARK: - Helpers

    private func workoutsForDay(date: Date, userId: UUID) -> [Workout] {
        weekWorkouts.filter {
            $0.userId == userId && $0.workoutDate.calendarDate == date.calendarDate
        }
    }

    private func resultTitle(_ result: WeekResult) -> String {
        switch result {
        case .bothHit: return "Both hit! 🎉"
        case .aOwes:
            let owerName = isCurrentUserA ? dataService.currentUser.displayName : dataService.partner.displayName
            return "\(owerName) owes"
        case .bOwes:
            let owerName = isCurrentUserA ? dataService.partner.displayName : dataService.currentUser.displayName
            return "\(owerName) owes"
        case .bothMissed: return "Both missed 😅"
        }
    }

}
