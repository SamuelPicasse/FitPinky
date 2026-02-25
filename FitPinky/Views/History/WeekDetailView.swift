import SwiftUI

struct WeekDetailView: View {
    @Environment(MockDataService.self) private var dataService
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
                progressRing(
                    name: dataService.currentUser.displayName,
                    current: userADays,
                    goal: week.goalUserA
                )
                progressRing(
                    name: dataService.partner.displayName,
                    current: userBDays,
                    goal: week.goalUserB
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cardBorder, lineWidth: 1))
    }

    private func progressRing(name: String, current: Int, goal: Int) -> some View {
        let fraction = goal > 0 ? min(CGFloat(current) / CGFloat(goal), 1.0) : 0

        return VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.cardBorder, lineWidth: 10)

                Circle()
                    .trim(from: 0, to: fraction * ringProgress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.brand, .brandPurple, .brand]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8), value: ringProgress)

                Text("\(current)/\(goal)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .frame(width: 110, height: 110)

            Text(name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Day-by-Day

    private var dayByDayCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Day by Day")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.bottom, 12)

            let allEntries = weekPhotoEntries()

            ForEach(0..<7, id: \.self) { dayOffset in
                let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: week.weekStart)!
                let dayName = date.formatted(.dateTime.weekday(.wide))
                let sammyWorkouts = workoutsForDay(date: date, userId: dataService.currentUser.id)
                let jottaWorkouts = workoutsForDay(date: date, userId: dataService.partner.id)
                let hasWorkouts = !sammyWorkouts.isEmpty || !jottaWorkouts.isEmpty

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

                        // Sammy's photo or empty
                        dayThumbnail(
                            workouts: sammyWorkouts,
                            name: dataService.currentUser.displayName,
                            allEntries: allEntries
                        )

                        // Jotta's photo or empty
                        dayThumbnail(
                            workouts: jottaWorkouts,
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
        if let workout = workouts.first,
           let photoData = workout.photoData,
           let uiImage = UIImage(data: photoData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
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
                    .foregroundStyle(resultColor(result))
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

    private func weekPhotoEntries() -> [PhotoEntry] {
        weekWorkouts.compactMap { workout in
            guard workout.photoData != nil else { return nil }
            let name = workout.userId == dataService.currentUser.id
                ? dataService.currentUser.displayName
                : dataService.partner.displayName
            return PhotoEntry(workout: workout, memberName: name)
        }
    }

    private func resultTitle(_ result: WeekResult) -> String {
        switch result {
        case .bothHit: "Both hit! 🎉"
        case .aOwes: "\(dataService.currentUser.displayName) owes"
        case .bOwes: "\(dataService.partner.displayName) owes"
        case .bothMissed: "Both missed 😅"
        }
    }

    private func resultColor(_ result: WeekResult) -> Color {
        switch result {
        case .bothHit: Color.success
        case .bothMissed: .red
        case .aOwes, .bOwes: .orange
        }
    }
}
