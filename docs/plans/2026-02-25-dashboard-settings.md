# Dashboard & Settings Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a dark-themed Dashboard (Sweatmates-inspired) and Settings screen, fully wired to MockDataService.

**Architecture:** Rewrite DashboardView with dark card-based layout. Create design system Color extension. Add SettingsView as 4th tab. Extend MockDataService + DataServiceProtocol with mutation methods for settings. Add haptic feedback on FitCam confirm. All state flows through `@Observable` MockDataService — no new view models needed.

**Tech Stack:** SwiftUI (iOS 17+, @Observable), SF Symbols, Core Graphics (existing watermark), AVFoundation (existing camera)

---

## Important Context

- No test target exists — verify by building with `xcodebuild`
- No external packages — only Apple frameworks
- `MockDataService` is `@Observable` and injected via `@Environment(MockDataService.self)`
- Week math uses 1=Monday...7=Sunday (app convention, NOT Calendar convention)
- `Workout.photoData` stores JPEG data; most mock workouts have `nil` photoData
- The FitCam flow already works: capture → watermark → confirm → `logWorkout()` → dismiss
- Current `DataServiceProtocol` has: `getCurrentUser()`, `getPartner()`, `getPair()`, `getCurrentWeek()`, `getWorkouts(for:)`, `logWorkout(photoData:caption:)`, `updateWager(text:)`, `getStreak()`, `getPastWeeks()`

## Build Command

```bash
xcodebuild -project FitPinky.xcodeproj -scheme FitPinky -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

Expected success: `** BUILD SUCCEEDED **`

---

### Task 1: Design System — Color Extension

**Files:**
- Create: `FitPinky/Extensions/Color+Theme.swift`

**Step 1: Create the theme color extension**

```swift
import SwiftUI

extension Color {
    // Brand
    static let brand = Color(red: 232/255, green: 69/255, blue: 124/255)        // #E8457C
    static let brandPurple = Color(red: 139/255, green: 92/255, blue: 246/255)  // #8B5CF6

    // Dark theme surfaces
    static let surfaceBackground = Color(red: 27/255, green: 27/255, blue: 31/255)    // #1B1B1F
    static let cardBackground = Color(red: 42/255, green: 42/255, blue: 46/255)       // #2A2A2E
    static let cardBorder = Color(red: 58/255, green: 58/255, blue: 62/255)            // #3A3A3E

    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 156/255, green: 163/255, blue: 175/255)     // #9CA3AF

    // Semantic
    static let success = Color(red: 52/255, green: 211/255, blue: 153/255)            // #34D399
}

extension ShapeStyle where Self == AngularGradient {
    /// Brand gradient for progress rings: pink to purple
    static var ringGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [.brand, .brandPurple, .brand]),
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }
}
```

**Step 2: Build to verify**

Run: `xcodebuild -project FitPinky.xcodeproj -scheme FitPinky -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```
feat: add design system color theme extension
```

---

### Task 2: Extend DataServiceProtocol + MockDataService for Settings

**Files:**
- Modify: `FitPinky/Services/DataServiceProtocol.swift`
- Modify: `FitPinky/Services/MockDataService.swift`

**Step 1: Add new protocol methods to DataServiceProtocol**

Add these methods to the protocol:

```swift
func updateDisplayName(_ name: String) async throws
func updateWeeklyGoal(_ days: Int) async throws
func updateWeekStartDay(_ day: Int) async throws
func latestWorkout(for userId: UUID) -> Workout?
func hasLoggedToday() -> Bool
```

**Step 2: Implement in MockDataService**

Add after the existing protocol methods:

```swift
func updateDisplayName(_ name: String) async throws {
    currentUser.displayName = name
}

func updateWeeklyGoal(_ days: Int) async throws {
    currentUser.weeklyGoal = days
    // Sync to the active WeeklyGoal
    guard let index = weeklyGoals.firstIndex(where: { $0.result == nil }) else { return }
    weeklyGoals[index].goalUserA = days
}

func updateWeekStartDay(_ day: Int) async throws {
    pair.weekStartDay = day
}

func latestWorkout(for userId: UUID) -> Workout? {
    let currentWeek = getCurrentWeek()
    return workouts
        .filter { $0.weeklyGoalId == currentWeek.id && $0.userId == userId }
        .sorted { $0.loggedAt > $1.loggedAt }
        .first
}

func hasLoggedToday() -> Bool {
    let today = Date.now.calendarDate
    return workouts.contains {
        $0.userId == currentUser.id && $0.workoutDate.calendarDate == today
    }
}
```

**Step 3: Build to verify**

Run: build command
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```
feat: extend DataServiceProtocol with settings and dashboard helpers
```

---

### Task 3: Rewrite DashboardView — Dark Card-Based Layout

**Files:**
- Modify: `FitPinky/Views/Dashboard/DashboardView.swift` (full rewrite)

**Step 1: Rewrite DashboardView**

This is the core of the feature. The view has these sections top-to-bottom:
1. Top bar (app name + streak pill)
2. Progress rings card (hero section)
3. FitCam strip (two photo cards side-by-side)
4. Wager card ("The Stakes")
5. Bottom action button (pinned)

Full implementation:

```swift
import SwiftUI

struct DashboardView: View {
    @Environment(MockDataService.self) private var dataService
    @State private var showSweatCam = false
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
                    .padding(.bottom, 100) // space for bottom button
                }

                Spacer(minLength: 0)
            }

            // Pinned bottom button
            VStack {
                Spacer()
                logWorkoutButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .fullScreenCover(isPresented: $showSweatCam) {
            SweatCamView()
        }
        .overlay {
            if let photo = fullScreenPhoto {
                fullScreenPhotoOverlay(photo)
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.8)) { ringProgress = 1 } }
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

            // Days left badge
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

                VStack(spacing: 2) {
                    Text("\(current)/\(goal)")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
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
```

**Step 2: Build to verify**

Run: build command
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```
feat: rewrite DashboardView with dark card-based layout
```

---

### Task 4: Create SettingsView

**Files:**
- Create: `FitPinky/Views/Settings/SettingsView.swift`

**Step 1: Create SettingsView**

```swift
import SwiftUI

struct SettingsView: View {
    @Environment(MockDataService.self) private var dataService
    @State private var showLeaveConfirmation = false

    private var currentWeek: WeeklyGoal { dataService.getCurrentWeek() }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.surfaceBackground.ignoresSafeArea()

                List {
                    profileSection
                    goalSection
                    wagerSection
                    groupSection
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Settings")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        Section {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundStyle(Color.brand)
                    .frame(width: 24)
                TextField("Display name", text: Bindable(dataService).currentUser.displayName)
                    .foregroundStyle(.white)
            }
            .listRowBackground(Color.cardBackground)
        } header: {
            Text("Profile")
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Goal

    private var goalSection: some View {
        Section {
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(Color.brand)
                    .frame(width: 24)
                Text("Weekly goal")
                    .foregroundStyle(.white)
                Spacer()
                Stepper(
                    "\(dataService.currentUser.weeklyGoal) days",
                    value: Bindable(dataService).currentUser.weeklyGoal,
                    in: 1...7
                )
                .foregroundStyle(.white)
                .onChange(of: dataService.currentUser.weeklyGoal) { _, newValue in
                    Task { try? await dataService.updateWeeklyGoal(newValue) }
                }
            }
            .listRowBackground(Color.cardBackground)

            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(Color.brand)
                    .frame(width: 24)
                Text("Week starts on")
                    .foregroundStyle(.white)
                Spacer()
                Picker("", selection: Bindable(dataService).pair.weekStartDay) {
                    Text("Monday").tag(1)
                    Text("Tuesday").tag(2)
                    Text("Wednesday").tag(3)
                    Text("Thursday").tag(4)
                    Text("Friday").tag(5)
                    Text("Saturday").tag(6)
                    Text("Sunday").tag(7)
                }
                .tint(Color.brand)
            }
            .listRowBackground(Color.cardBackground)
        } header: {
            Text("Goal")
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Wager

    private var wagerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(Color.brand)
                        .frame(width: 24)
                    Text("This week's wager")
                        .foregroundStyle(.white)
                }
                TextField("e.g. Loser buys sushi", text: wagerBinding)
                    .foregroundStyle(.white)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color.surfaceBackground, in: RoundedRectangle(cornerRadius: 8))

                HStack {
                    Spacer()
                    Text("\(currentWeek.wagerText.count)/200")
                        .font(.caption2)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .listRowBackground(Color.cardBackground)
        } header: {
            Text("Wager")
                .foregroundStyle(Color.textSecondary)
        }
    }

    private var wagerBinding: Binding<String> {
        Binding(
            get: { currentWeek.wagerText },
            set: { newValue in
                let trimmed = String(newValue.prefix(200))
                Task { try? await dataService.updateWager(text: trimmed) }
            }
        )
    }

    // MARK: - Group

    private var groupSection: some View {
        Section {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(Color.brand)
                    .frame(width: 24)
                Text("Partner")
                    .foregroundStyle(.white)
                Spacer()
                Text(dataService.partner.displayName)
                    .foregroundStyle(Color.textSecondary)
            }
            .listRowBackground(Color.cardBackground)

            HStack {
                Image(systemName: "ticket.fill")
                    .foregroundStyle(Color.brand)
                    .frame(width: 24)
                Text("Invite code")
                    .foregroundStyle(.white)
                Spacer()
                Text(dataService.pair.inviteCode)
                    .foregroundStyle(Color.textSecondary)
                    .monospacedDigit()
                Button {
                    UIPasteboard.general.string = dataService.pair.inviteCode
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(Color.brand)
                }
            }
            .listRowBackground(Color.cardBackground)

            Button(role: .destructive) {
                showLeaveConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .frame(width: 24)
                    Text("Leave Group")
                }
            }
            .listRowBackground(Color.cardBackground)
            .confirmationDialog(
                "Leave this group?",
                isPresented: $showLeaveConfirmation,
                titleVisibility: .visible
            ) {
                Button("Leave Group", role: .destructive) {
                    // No-op in mock
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your workout history will be preserved, but you'll need a new invite code to rejoin.")
            }
        } header: {
            Text("Group")
                .foregroundStyle(Color.textSecondary)
        }
    }
}
```

**Step 2: Build to verify**

Run: build command
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```
feat: add SettingsView with dark card-based design
```

---

### Task 5: Wire ContentView — Add Settings Tab + FitCam from Dashboard

**Files:**
- Modify: `FitPinky/ContentView.swift`

**Step 1: Update ContentView**

The Dashboard now handles its own FitCam `.fullScreenCover`, so the center tab intercept stays for the tab bar camera shortcut. Add the 4th Settings tab.

Replace the entire file:

```swift
import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showSweatCam = false

    var body: some View {
        ZStack {
            Color.surfaceBackground.ignoresSafeArea()

            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(0)

                Color.clear
                    .tabItem { Label("FitCam", systemImage: "camera.fill") }
                    .tag(1)

                HistoryView()
                    .tabItem { Label("History", systemImage: "calendar") }
                    .tag(2)

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(3)
            }
            .tint(Color.brand)
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == 1 {
                showSweatCam = true
                selectedTab = oldValue
            }
        }
        .fullScreenCover(isPresented: $showSweatCam) {
            SweatCamView()
        }
        .preferredColorScheme(.dark)
    }
}
```

**Step 2: Build to verify**

Run: build command
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```
feat: add Settings as 4th tab, enforce dark color scheme
```

---

### Task 6: Add Haptic Feedback to FitCam Confirm

**Files:**
- Modify: `FitPinky/Views/SweatCam/SweatCamView.swift`

**Step 1: Add haptic on confirm**

In SweatCamView, find the `onConfirm` closure in the `PhotoConfirmationView` initializer. Add haptic feedback when the photo is successfully saved:

Change the `onConfirm` closure from:
```swift
onConfirm: {
    Task {
        let success = await viewModel.confirmPhoto(dataService: dataService)
        if success { dismiss() }
    }
},
```

To:
```swift
onConfirm: {
    Task {
        let success = await viewModel.confirmPhoto(dataService: dataService)
        if success {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            dismiss()
        }
    }
},
```

**Step 2: Build to verify**

Run: build command
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```
feat: add haptic feedback on FitCam photo confirm
```

---

### Task 7: Add Sample Photo Data to MockDataService

**Files:**
- Modify: `FitPinky/Services/MockDataService.swift`

**Step 1: Generate a sample photo for mock workouts**

The FitCam strip needs `photoData` on at least one workout to show thumbnails during development. Add a helper that creates a minimal solid-color JPEG to use as mock photo data.

After the `init()` method, add a static helper:

```swift
private static func makeSamplePhoto(color: UIColor, size: CGSize = CGSize(width: 200, height: 200)) -> Data? {
    let renderer = UIGraphicsImageRenderer(size: size)
    let image = renderer.image { ctx in
        color.setFill()
        ctx.fill(CGRect(origin: .zero, size: size))
    }
    return image.jpegData(compressionQuality: 0.5)
}
```

Then update the mock workouts in `init()` to include photo data. Change the workouts array to:

```swift
self.workouts = [
    Workout(
        userId: userAId,
        pairId: pairId,
        weeklyGoalId: currentWeek.id,
        photoData: MockDataService.makeSamplePhoto(color: .systemIndigo),
        caption: "Leg day 🦵",
        loggedAt: twoDaysAgo,
        workoutDate: twoDaysAgo
    ),
    Workout(
        userId: userBId,
        pairId: pairId,
        weeklyGoalId: currentWeek.id,
        photoData: MockDataService.makeSamplePhoto(color: .systemTeal),
        caption: "Morning run",
        loggedAt: twoDaysAgo,
        workoutDate: twoDaysAgo
    ),
    Workout(
        userId: userAId,
        pairId: pairId,
        weeklyGoalId: currentWeek.id,
        photoData: MockDataService.makeSamplePhoto(color: .systemPurple),
        caption: "Push day",
        loggedAt: yesterday,
        workoutDate: yesterday
    ),
]
```

Also add `import UIKit` at the top of the file if not already present.

**Step 2: Build to verify**

Run: build command
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```
feat: add sample photo data to mock workouts for FitCam strip
```

---

### Task 8: Final Build Verification

**Step 1: Full clean build**

```bash
xcodebuild -project FitPinky.xcodeproj -scheme FitPinky -destination 'platform=iOS Simulator,name=iPhone 16' clean build 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED

**Step 2: Verify all files exist**

```bash
find FitPinky -name "*.swift" | sort
```

Expected files:
- `FitPinky/ContentView.swift`
- `FitPinky/Extensions/Color+Theme.swift` (NEW)
- `FitPinky/Extensions/Date+Extensions.swift`
- `FitPinky/FitPinkyApp.swift`
- `FitPinky/Models/Nudge.swift`
- `FitPinky/Models/Pair.swift`
- `FitPinky/Models/UserProfile.swift`
- `FitPinky/Models/WeeklyGoal.swift`
- `FitPinky/Models/Workout.swift`
- `FitPinky/Services/CameraService.swift`
- `FitPinky/Services/DataServiceProtocol.swift`
- `FitPinky/Services/MockDataService.swift`
- `FitPinky/ViewModels/SweatCamViewModel.swift`
- `FitPinky/Views/Dashboard/DashboardView.swift`
- `FitPinky/Views/History/HistoryView.swift`
- `FitPinky/Views/Settings/SettingsView.swift` (NEW)
- `FitPinky/Views/SweatCam/CameraPreviewView.swift`
- `FitPinky/Views/SweatCam/PhotoConfirmationView.swift`
- `FitPinky/Views/SweatCam/SweatCamView.swift`

**Step 3: Final commit**

If any fixes were needed, commit them:
```
fix: resolve build issues from integration
```

---

## Reactive Wiring Summary

All reactivity flows through `MockDataService` (`@Observable`):

| User Action | MockDataService Mutation | Dashboard Effect |
|---|---|---|
| Log workout via FitCam | `workouts.append(...)` | Ring animates up, photo appears in FitCam strip, button changes to "Worked out today" |
| Change wager in Settings | `weeklyGoals[i].wagerText = ...` | Wager card updates |
| Change weekly goal in Settings | `currentUser.weeklyGoal = ...; weeklyGoals[i].goalUserA = ...` | Ring denominator updates, stakes subtitle recalculates |
| Change week start day in Settings | `pair.weekStartDay = ...` | "days left" badge recalculates |
| Change display name in Settings | `currentUser.displayName = ...` | Name labels update everywhere |

No manual refresh needed — `@Observable` + `@Environment` handles it automatically.
