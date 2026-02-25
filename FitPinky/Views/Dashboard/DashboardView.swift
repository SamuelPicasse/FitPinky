import SwiftUI

struct DashboardView: View {
    @Environment(MockDataService.self) private var dataService
    @Binding var showSweatCam: Bool
    @State private var fullScreenPhoto: UIImage?
    @State private var ringProgress: CGFloat = 0

    private var currentWeek: WeeklyGoal { dataService.getCurrentWeek() }
    private var userDays: Int { dataService.workoutDays(for: dataService.currentUser.id, in: currentWeek) }
    private var partnerDays: Int { dataService.workoutDays(for: dataService.partner.id, in: currentWeek) }

    var body: some View {
        ZStack {
            Color.surfaceBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 14) {
                        topBar
                        progressRingsCard
                        fitCamStrip
                        wagerCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }

                Spacer(minLength: 0)
            }

            VStack {
                Spacer()
                logWorkoutButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .overlay {
            if let photo = fullScreenPhoto {
                fullScreenPhotoOverlay(photo)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { ringProgress = 1 }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Text("FitPinky")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.brand)

            Spacer()

            let streak = dataService.getStreak()
            if streak > 0 {
                HStack(spacing: 4) {
                    Text("\u{1F525}")
                    Text("\(streak) week streak")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.cardBackground, in: Capsule())
                .overlay(Capsule().stroke(Color.cardBorder, lineWidth: 1))
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Progress Rings

    private var progressRingsCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                progressRing(
                    name: dataService.currentUser.displayName,
                    current: userDays,
                    goal: currentWeek.goalUserA
                )
                progressRing(
                    name: dataService.partner.displayName,
                    current: partnerDays,
                    goal: currentWeek.goalUserB
                )
            }

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                let remaining = Date.now.daysRemainingInWeek(weekStartDay: dataService.pair.weekStartDay)
                Text("\(remaining) day\(remaining == 1 ? "" : "s") left")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(Color.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.surfaceBackground, in: Capsule())
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

    // MARK: - FitCam Strip

    private var fitCamStrip: some View {
        HStack(spacing: 12) {
            fitCamCard(
                name: dataService.currentUser.displayName,
                workout: dataService.latestWorkout(for: dataService.currentUser.id)
            )
            fitCamCard(
                name: dataService.partner.displayName,
                workout: dataService.latestWorkout(for: dataService.partner.id)
            )
        }
    }

    private func fitCamCard(name: String, workout: Workout?) -> some View {
        VStack(spacing: 8) {
            if let workout, let photoData = workout.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .contentShape(Rectangle())
                    .onTapGesture { fullScreenPhoto = uiImage }
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.cardBorder, style: StrokeStyle(lineWidth: 1, dash: [6]))
                    .frame(height: 140)
                    .overlay {
                        VStack(spacing: 6) {
                            Image(systemName: "camera")
                                .font(.title3)
                                .foregroundStyle(Color.textSecondary)
                            Text("No workout yet")
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
                        }
                    }
            }

            HStack {
                Text(name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                Spacer()
                if let workout {
                    Text(workout.loggedAt.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cardBorder, lineWidth: 1))
    }

    // MARK: - Wager Card

    private var wagerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("The Stakes \u{1F3AF}")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
            }

            if currentWeek.wagerText.isEmpty {
                Text("Tap to set a wager")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            } else {
                Text(currentWeek.wagerText)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
            }

            Text(stakesSubtitle)
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cardBorder, lineWidth: 1))
    }

    private var stakesSubtitle: String {
        let userRemaining = max(0, currentWeek.goalUserA - userDays)
        let partnerRemaining = max(0, currentWeek.goalUserB - partnerDays)

        if userRemaining == 0 && partnerRemaining == 0 {
            return "You're both on track \u{1F4AA}"
        } else if userRemaining > 0 && partnerRemaining > 0 {
            return "\(dataService.currentUser.displayName) needs \(userRemaining) more, \(dataService.partner.displayName) needs \(partnerRemaining) more"
        } else if userRemaining > 0 {
            return "\(dataService.currentUser.displayName) needs \(userRemaining) more workout\(userRemaining == 1 ? "" : "s")"
        } else {
            return "\(dataService.partner.displayName) needs \(partnerRemaining) more workout\(partnerRemaining == 1 ? "" : "s")"
        }
    }

    // MARK: - Bottom Button

    private var logWorkoutButton: some View {
        let loggedToday = dataService.hasLoggedToday()

        return Button {
            showSweatCam = true
        } label: {
            HStack(spacing: 8) {
                Text(loggedToday ? "\u{2705}" : "\u{1F4F8}")
                Text(loggedToday ? "Worked out today" : "Log today's workout")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(loggedToday ? Color.success.opacity(0.2) : Color.brand, in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(loggedToday ? Color.success : .white)
        }
    }

    // MARK: - Full Screen Photo

    private func fullScreenPhotoOverlay(_ image: UIImage) -> some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()
                .onTapGesture { fullScreenPhoto = nil }

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(20)
        }
    }
}
