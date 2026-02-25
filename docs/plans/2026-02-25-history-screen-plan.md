# History Screen Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the History tab with week list, week detail, full-screen photo viewer, and streak display — all backed by rich mock data.

**Architecture:** Separate view files (HistoryView, WeekDetailView, PhotoFullScreenView) reading from MockDataService via @Environment. No ViewModels needed — follows the same read-only-from-service pattern as DashboardView. PhotoFullScreenView is a reusable component that replaces Dashboard's inline overlay.

**Tech Stack:** SwiftUI (iOS 17+, @Observable), no external dependencies. Build with `xcodebuild -project FitPinky.xcodeproj -scheme FitPinky -destination 'platform=iOS Simulator,name=iPhone 16' build`

---

### Task 1: Date Extension — Week Date Range Formatter

**Files:**
- Modify: `FitPinky/Extensions/Date+Extensions.swift`

**Step 1: Add `weekDateRange` method to Date extension**

Add this method after the existing `daysRemainingInWeek` method in Date+Extensions.swift:

```swift
/// Format a week range: "Feb 17 - Feb 23"
func weekDateRange(weekStartDay: Int = 1) -> String {
    let start = startOfWeek(weekStartDay: weekStartDay)
    let end = Calendar.current.date(byAdding: .day, value: 6, to: start)!
    let startStr = start.formatted(.dateTime.month(.abbreviated).day())
    let endStr = end.formatted(.dateTime.month(.abbreviated).day())
    return "\(startStr) - \(endStr)"
}
```

**Step 2: Build to verify**

Run: `xcodebuild -project FitPinky.xcodeproj -scheme FitPinky -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add FitPinky/Extensions/Date+Extensions.swift
git commit -m "feat: add weekDateRange formatter to Date extensions"
```

---

### Task 2: Protocol + MockDataService — getBestStreak and Expanded Mock Data

**Files:**
- Modify: `FitPinky/Services/DataServiceProtocol.swift`
- Modify: `FitPinky/Services/MockDataService.swift`

**Step 1: Add `getBestStreak` to DataServiceProtocol**

Add after `func getStreak() -> Int`:

```swift
func getBestStreak() -> Int
```

**Step 2: Add `getBestStreak` implementation to MockDataService**

Add after the existing `getStreak()` method:

```swift
func getBestStreak() -> Int {
    let completed = weeklyGoals
        .filter { $0.result != nil }
        .sorted { $0.weekStart > $1.weekStart }

    var best = 0
    var current = 0
    for week in completed {
        if week.result == .bothHit {
            current += 1
            best = max(best, current)
        } else {
            current = 0
        }
    }
    return best
}
```

**Step 3: Replace the entire `init()` of MockDataService with expanded mock data**

Replace the init from `init() {` through the closing `}` of init (before `// MARK: - DataServiceProtocol`). The new init creates 6 weeks (1 current + 5 past) with workouts spread across days using varied photo colors.

```swift
init() {
    let pairId = UUID()
    let userAId = UUID()
    let userBId = UUID()

    self.pair = Pair(
        id: pairId,
        userAId: userAId,
        userBId: userBId,
        weekStartDay: 1,
        inviteCode: "SWEAT1"
    )

    let sammy = UserProfile(
        id: userAId,
        pairId: pairId,
        displayName: "Sammy",
        weeklyGoal: 4
    )
    let jotta = UserProfile(
        id: userBId,
        pairId: pairId,
        displayName: "Jotta",
        weeklyGoal: 4
    )
    self.currentUser = sammy
    self.partner = jotta

    let cal = Calendar.current
    let weekStart = Date.now.startOfWeek()

    // --- Week definitions (current + 5 past) ---
    let currentWeek = WeeklyGoal(
        pairId: pairId, weekStart: weekStart,
        goalUserA: 4, goalUserB: 4,
        wagerText: "Loser buys sushi 🍣"
    )
    let week1 = WeeklyGoal(
        pairId: pairId,
        weekStart: cal.date(byAdding: .day, value: -7, to: weekStart)!,
        goalUserA: 4, goalUserB: 4,
        wagerText: "Loser does the dishes for a week",
        result: .bothHit
    )
    let week2 = WeeklyGoal(
        pairId: pairId,
        weekStart: cal.date(byAdding: .day, value: -14, to: weekStart)!,
        goalUserA: 5, goalUserB: 3,
        wagerText: "Loser cooks dinner 🍝",
        result: .bothHit
    )
    let week3 = WeeklyGoal(
        pairId: pairId,
        weekStart: cal.date(byAdding: .day, value: -21, to: weekStart)!,
        goalUserA: 4, goalUserB: 4,
        wagerText: "Loser plans date night 🌹",
        result: .aOwes
    )
    let week4 = WeeklyGoal(
        pairId: pairId,
        weekStart: cal.date(byAdding: .day, value: -28, to: weekStart)!,
        goalUserA: 4, goalUserB: 4,
        wagerText: "Loser gives a massage 💆",
        result: .bOwes
    )
    let week5 = WeeklyGoal(
        pairId: pairId,
        weekStart: cal.date(byAdding: .day, value: -35, to: weekStart)!,
        goalUserA: 4, goalUserB: 3,
        wagerText: "Loser buys coffee all week ☕️",
        result: .bothMissed
    )

    self.weeklyGoals = [currentWeek, week1, week2, week3, week4, week5]

    // --- Helper to create workouts for a week ---
    let colors: [UIColor] = [.systemIndigo, .systemTeal, .systemPurple, .systemPink, .systemOrange, .systemCyan, .systemMint]
    var colorIndex = 0
    func nextColor() -> UIColor {
        let c = colors[colorIndex % colors.count]
        colorIndex += 1
        return c
    }

    let captions = [
        "Leg day 🦵", "Morning run", "Push day", "Yoga flow 🧘", "HIIT session",
        "Chest & back", "Spin class 🚴", "Rest day jk", "Arms day 💪", "Swimming 🏊",
        "Pilates", "Boxing 🥊", "Trail run 🏃", "CrossFit", "Dance class 💃"
    ]
    var captionIndex = 0
    func nextCaption() -> String {
        let c = captions[captionIndex % captions.count]
        captionIndex += 1
        return c
    }

    func makeWorkouts(
        week: WeeklyGoal,
        sammyDays: [Int],
        jottaDays: [Int]
    ) -> [Workout] {
        var result: [Workout] = []
        for dayOffset in sammyDays {
            let date = cal.date(byAdding: .day, value: dayOffset, to: week.weekStart)!
            let hour = 7 + (dayOffset * 2) % 12  // vary time of day
            let loggedAt = cal.date(bySettingHour: hour, minute: 30, second: 0, of: date)!
            result.append(Workout(
                userId: userAId, pairId: pairId, weeklyGoalId: week.id,
                photoData: MockDataService.makeSamplePhoto(color: nextColor()),
                caption: nextCaption(), loggedAt: loggedAt, workoutDate: date
            ))
        }
        for dayOffset in jottaDays {
            let date = cal.date(byAdding: .day, value: dayOffset, to: week.weekStart)!
            let hour = 8 + (dayOffset * 3) % 10
            let loggedAt = cal.date(bySettingHour: hour, minute: 15, second: 0, of: date)!
            result.append(Workout(
                userId: userBId, pairId: pairId, weeklyGoalId: week.id,
                photoData: MockDataService.makeSamplePhoto(color: nextColor()),
                caption: nextCaption(), loggedAt: loggedAt, workoutDate: date
            ))
        }
        return result
    }

    var allWorkouts: [Workout] = []

    // Current week: Sammy 2 days, Jotta 1 day
    allWorkouts += makeWorkouts(week: currentWeek, sammyDays: [0, 1], jottaDays: [0])

    // Week 1 ago: both hit 4/4
    allWorkouts += makeWorkouts(week: week1, sammyDays: [0, 1, 3, 5], jottaDays: [0, 2, 4, 6])

    // Week 2 ago: Sammy 5/5, Jotta 3/3
    allWorkouts += makeWorkouts(week: week2, sammyDays: [0, 1, 2, 4, 6], jottaDays: [1, 3, 5])

    // Week 3 ago: Sammy 3/4 (missed), Jotta 4/4
    allWorkouts += makeWorkouts(week: week3, sammyDays: [0, 2, 5], jottaDays: [0, 2, 4, 6])

    // Week 4 ago: Sammy 4/4, Jotta 3/4 (missed)
    allWorkouts += makeWorkouts(week: week4, sammyDays: [0, 1, 3, 5], jottaDays: [1, 3, 6])

    // Week 5 ago: Sammy 2/4, Jotta 1/3 (both missed)
    allWorkouts += makeWorkouts(week: week5, sammyDays: [2, 5], jottaDays: [3])

    self.workouts = allWorkouts
    self.nudges = []
}
```

**Step 4: Build to verify**

Run: `xcodebuild -project FitPinky.xcodeproj -scheme FitPinky -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add FitPinky/Services/DataServiceProtocol.swift FitPinky/Services/MockDataService.swift
git commit -m "feat: add getBestStreak and expand mock data to 5 past weeks"
```

---

### Task 3: PhotoFullScreenView — Reusable Swipeable Photo Viewer

**Files:**
- Create: `FitPinky/Views/PhotoFullScreenView.swift`

**Step 1: Create PhotoFullScreenView.swift**

This view takes an array of photo entries and a starting index. Each entry pairs a Workout with a display name. Uses TabView with .page style for swipe navigation.

Create at `FitPinky/Views/PhotoFullScreenView.swift`:

```swift
import SwiftUI

struct PhotoEntry: Identifiable {
    let id: UUID
    let image: UIImage
    let memberName: String
    let date: Date
    let caption: String?

    init(workout: Workout, memberName: String) {
        self.id = workout.id
        self.image = UIImage(data: workout.photoData ?? Data()) ?? UIImage()
        self.memberName = memberName
        self.date = workout.loggedAt
        self.caption = workout.caption
    }
}

struct PhotoFullScreenView: View {
    let photos: [PhotoEntry]
    @State var currentIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, entry in
                    photoPage(entry)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 8)
                }
                Spacer()
            }
        }
        .offset(y: dragOffset)
        .gesture(
            DragGesture(minimumDistance: 50)
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 150 {
                        dismiss()
                    } else {
                        withAnimation(.easeOut(duration: 0.2)) { dragOffset = 0 }
                    }
                }
        )
        .background(Color.black)
        .statusBarHidden()
    }

    private func photoPage(_ entry: PhotoEntry) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(uiImage: entry.image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)

            VStack(spacing: 6) {
                Text(entry.memberName)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(entry.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute()))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                if let caption = entry.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.top, 4)
                }
            }

            Spacer()
        }
    }
}
```

**Step 2: Add to Xcode project**

The file needs to be in the FitPinky group. Since this is a flat Xcode project, just creating the file in the Views directory and ensuring it's picked up by the build. Check that the project file includes it — if using `xcodebuild` with the existing project, new Swift files in the project directory are typically auto-discovered if they're in folders referenced by the project.

If the build fails because the file isn't in the project, you'll need to add it via:
```bash
# Verify the file is in the right place
ls FitPinky/Views/PhotoFullScreenView.swift
```

**Step 3: Build to verify**

Run: `xcodebuild -project FitPinky.xcodeproj -scheme FitPinky -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add FitPinky/Views/PhotoFullScreenView.swift
git commit -m "feat: add PhotoFullScreenView with swipe navigation and drag-to-dismiss"
```

---

### Task 4: HistoryView — Complete Rewrite with Dark Cards and Streak

**Files:**
- Rewrite: `FitPinky/Views/History/HistoryView.swift`

**Step 1: Rewrite HistoryView.swift**

Replace the entire file contents:

```swift
import SwiftUI

struct HistoryView: View {
    @Environment(MockDataService.self) private var dataService
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
                    Text("🔥")
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
        let userAHit = userADays >= week.goalUserA
        let userBHit = userBDays >= week.goalUserB

        return VStack(alignment: .leading, spacing: 10) {
            // Week date range
            Text(week.weekStart.weekDateRange(weekStartDay: dataService.pair.weekStartDay))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.textSecondary)

            // Partner results
            HStack(spacing: 16) {
                resultBadge(
                    name: dataService.currentUser.displayName,
                    days: userADays, goal: week.goalUserA, hit: userAHit
                )
                resultBadge(
                    name: dataService.partner.displayName,
                    days: userBDays, goal: week.goalUserB, hit: userBHit
                )
                Spacer()
            }

            // Wager outcome
            if let result = week.result {
                Text(wagerOutcome(result: result, wagerText: week.wagerText))
                    .font(.subheadline)
                    .foregroundStyle(wagerColor(result))
            }

            // Photo thumbnails
            if !weekWorkouts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        let entries = photoEntries(for: weekWorkouts)
                        ForEach(Array(entries.prefix(4).enumerated()), id: \.element.id) { index, entry in
                            Image(uiImage: entry.image)
                                .resizable()
                                .scaledToFill()
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
            Text(hit ? "✅" : "❌")
                .font(.caption)
        }
    }

    // MARK: - Helpers

    private func photoEntries(for workouts: [Workout]) -> [PhotoEntry] {
        workouts.compactMap { workout in
            guard workout.photoData != nil else { return nil }
            let name = workout.userId == dataService.currentUser.id
                ? dataService.currentUser.displayName
                : dataService.partner.displayName
            return PhotoEntry(workout: workout, memberName: name)
        }
    }

    private func wagerOutcome(result: WeekResult, wagerText: String) -> String {
        switch result {
        case .bothHit:
            return "Both hit! 🎉"
        case .aOwes:
            return "\(dataService.currentUser.displayName) owes: \(wagerText)"
        case .bOwes:
            return "\(dataService.partner.displayName) owes: \(wagerText)"
        case .bothMissed:
            return "Both missed 😅"
        }
    }

    private func wagerColor(_ result: WeekResult) -> Color {
        switch result {
        case .bothHit: Color.success
        case .bothMissed: .red
        case .aOwes, .bOwes: .orange
        }
    }
}
```

**Step 2: Build to verify**

Run: `xcodebuild -project FitPinky.xcodeproj -scheme FitPinky -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED (WeekDetailView won't exist yet — create a stub if build fails)

If the build fails because `WeekDetailView` doesn't exist yet, create a minimal stub at `FitPinky/Views/History/WeekDetailView.swift`:

```swift
import SwiftUI

struct WeekDetailView: View {
    let week: WeeklyGoal

    var body: some View {
        Text("Week Detail")
    }
}
```

**Step 3: Commit**

```bash
git add FitPinky/Views/History/HistoryView.swift FitPinky/Views/History/WeekDetailView.swift
git commit -m "feat: rewrite HistoryView with dark cards, streak header, photo thumbnails"
```

---

### Task 5: WeekDetailView — Progress Rings, Day-by-Day, Wager Result

**Files:**
- Create/Replace: `FitPinky/Views/History/WeekDetailView.swift`

**Step 1: Write WeekDetailView.swift**

Replace the stub (or create) with the full implementation:

```swift
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
```

**Step 2: Build to verify**

Run: `xcodebuild -project FitPinky.xcodeproj -scheme FitPinky -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add FitPinky/Views/History/WeekDetailView.swift
git commit -m "feat: add WeekDetailView with progress rings, day-by-day breakdown, wager result"
```

---

### Task 6: DashboardView — Replace Inline Photo Overlay with PhotoFullScreenView

**Files:**
- Modify: `FitPinky/Views/Dashboard/DashboardView.swift`

**Step 1: Replace `@State private var fullScreenPhoto: UIImage?` with photo viewer state**

Replace these state properties:
```swift
@State private var fullScreenPhoto: UIImage?
```
With:
```swift
@State private var selectedPhotoEntries: [PhotoEntry] = []
@State private var selectedPhotoIndex: Int = 0
@State private var showPhotoViewer = false
```

**Step 2: Update the fitCamCard photo tap action**

In the `fitCamCard` method, replace:
```swift
.onTapGesture { fullScreenPhoto = uiImage }
```
With:
```swift
.onTapGesture {
    let currentWeek = currentWeek
    let allWorkouts = dataService.getWorkouts(for: currentWeek)
        .sorted { $0.loggedAt < $1.loggedAt }
    let entries: [PhotoEntry] = allWorkouts.compactMap { w in
        guard w.photoData != nil else { return nil }
        let memberName = w.userId == dataService.currentUser.id
            ? dataService.currentUser.displayName
            : dataService.partner.displayName
        return PhotoEntry(workout: w, memberName: memberName)
    }
    selectedPhotoEntries = entries
    selectedPhotoIndex = entries.firstIndex { $0.id == workout.id } ?? 0
    showPhotoViewer = true
}
```

**Step 3: Replace the `.overlay` with `.fullScreenCover`**

Remove the entire overlay block:
```swift
.overlay {
    if let photo = fullScreenPhoto {
        fullScreenPhotoOverlay(photo)
    }
}
```

And the `fullScreenPhotoOverlay` method at the bottom.

Add `.fullScreenCover` after `.onAppear`:
```swift
.fullScreenCover(isPresented: $showPhotoViewer) {
    PhotoFullScreenView(photos: selectedPhotoEntries, currentIndex: selectedPhotoIndex)
}
```

**Step 4: Build to verify**

Run: `xcodebuild -project FitPinky.xcodeproj -scheme FitPinky -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add FitPinky/Views/Dashboard/DashboardView.swift
git commit -m "feat: replace Dashboard inline photo overlay with PhotoFullScreenView"
```

---

### Task 7: Xcode Project File — Ensure New Files Are Included

**Files:**
- Modify: `FitPinky.xcodeproj/project.pbxproj` (if needed)

**Step 1: Build and check for missing files**

Run: `xcodebuild -project FitPinky.xcodeproj -scheme FitPinky -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -10`

If the build fails with "no such module" or missing file references, the new files need to be added to the Xcode project. This is common when files are created outside of Xcode.

Check if the project uses folder references (blue folders) or groups (yellow folders). If folder references, new files are auto-discovered. If groups, files need to be manually added to `project.pbxproj`.

**Step 2: If build succeeds, done. If not, add files to project.**

Use the `ruby` or `xcodeproj` gem approach, or manually check which files are missing from the build phases.

**Step 3: Final build verification**

Run: `xcodebuild -project FitPinky.xcodeproj -scheme FitPinky -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit if project file changed**

```bash
git add FitPinky.xcodeproj/project.pbxproj
git commit -m "chore: add new History files to Xcode project"
```
