# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FitPinky is an iOS workout accountability app for couples/small groups (2-3 people). Users make weekly workout commitments, log workouts via photo proof (SweatCam), set playful wagers, and track who showed up. iOS 17+ only, SwiftUI + CloudKit backend.

Full product spec: `fitpinky-prd.md`

## Build & Run

Xcode project, no SPM packages, no external dependencies:

```bash
xcodebuild -project FitPinky.xcodeproj -scheme FitPinky -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build
```

No test targets exist yet. No linter is configured.

**Simulator vs Device**: `DataServiceProtocol.swift` uses a `#if targetEnvironment(simulator)` typealias — simulator builds use `MockDataService` (mock data, no CloudKit), device builds use `CloudKitService`. This means CloudKit-only methods (like `createGroup`, `joinGroup`) are guarded with `#if targetEnvironment(simulator)` in views.

## Architecture

**MVVM + Services** pattern with SwiftUI `@Environment` dependency injection.

```
Models → Services (DataServiceProtocol) → ViewModels → Views
```

- **Models** (`FitPinky/Models/`): Plain `Codable` structs — `Pair`, `UserProfile`, `WeeklyGoal`, `Workout`, `Nudge`
- **Services** (`FitPinky/Services/`): `DataServiceProtocol` defines the data interface. `MockDataService` (simulator) and `CloudKitService` (device) both conform. `CameraService` wraps AVFoundation.
- **ViewModels** (`FitPinky/ViewModels/`): `SweatCamViewModel` manages camera lifecycle, photo capture, and watermark rendering via Core Graphics.
- **Views** (`FitPinky/Views/`): Organized by feature — `Dashboard/`, `History/`, `SweatCam/`, `Settings/`, `Onboarding/`
- **Extensions** (`FitPinky/Extensions/`): `Date+Extensions.swift` (week math), `Color+Theme.swift` (app-wide color palette)

### App Routing

`FitPinkyApp.swift` drives a state machine based on the data service's observable properties:

```
isLoading → LaunchScreenView
needsAuthentication → ICloudSignInView
!hasGroup → OnboardingView (create/join group flow)
else → ContentView (main 4-tab app)
```

The service is injected via `.environment(dataService)` at the window group level. `.preferredColorScheme(.dark)` is applied here (app-wide, not per-view).

### Navigation

`ContentView` uses a `TabView` with 4 tabs: Home (Dashboard), FitCam, History, Settings. The FitCam tab intercepts selection and opens a `.fullScreenCover` modal instead of navigating to a tab page.

### CloudKit Data Model

`CloudKitService` uses a single `CKRecordZone` per group, shared via `CKShare`. The zone owner (group creator) accesses it via the private database; the joiner accesses it via the shared database. `activeGroupDatabase` switches automatically based on `groupZoneLocation`.

Record types: `Group`, `Member`, `WeeklyGoal`, `Workout`, `InviteCode` (public DB).

### Lazy Photo Loading

Photos are NOT loaded during `fetchAllRecords`. Instead, `Workout.photoRecordName` stores the CKRecord name. Views use `WorkoutPhotoView` (a reusable async component) which calls `dataService.loadPhoto(for:)` on demand and shows a loading spinner. A `photoCache: [UUID: Data]` dictionary in `CloudKitService` prevents redundant fetches. Locally captured photos (via SweatCam) are stored in `Workout.photoData` and available immediately.

### Onboarding & Invite Flow

Group creation writes a `CKShare` + `InviteCode` record (public DB). Invite codes use charset `ABCDEFGHJKMNPQRSTUVWXYZ23456789` (no ambiguous 0/O/1/I/L). The pending invite code is persisted in `UserDefaults` (`CloudKitService.pendingInviteCodeKey`) for crash recovery. `InviteCodeView` polls `checkForPartner()` every 5 seconds. `hasGroup` becomes true only when `memberCount >= 2`.

## Conventions

- **iOS 17+ APIs**: Uses `@Observable` macro (not `ObservableObject`/`@Published`), `onChange(of:)` with old/new values, `ContentUnavailableView`
- **Dark theme**: All colors via `Color+Theme.swift` — `Color.brand` (#E8457C pink), `Color.surfaceBackground`, `Color.cardBackground`, `Color.cardBorder`, `Color.textSecondary`, `Color.success`
- **Week math**: Week start day uses 1=Monday through 7=Sunday (not Apple's Calendar convention of 1=Sunday). See `Date+Extensions.swift`.
- **Workout deduplication**: Multiple workouts on the same calendar day count as 1 day toward the weekly goal. See `workoutDays(for:in:)`.
- **3AM rule**: Workouts logged between midnight and 3AM count for the previous day. See `effectiveWorkoutDate()` in `CloudKitService`.
- **Week result enum**: `WeekResult` cases are `bothHit`, `aOwes`, `bOwes`, `bothMissed` — tied to `userA`/`userB` identity in `Pair`. Has a `.color` computed property.
- **Camera mirroring**: Front camera captures are horizontally flipped to match the preview. See `CameraService.capturePhoto()`.
- **Photo watermark format**: `"Wed 26 Feb • 18:34"` — rendered bottom-left with semi-transparent white text and drop shadow. Font scales at 3.5% of image width.
- **Photo display**: Always use `WorkoutPhotoView` for displaying workout photos. Check `workout.hasPhoto` (not `workout.photoData != nil`) to determine if a photo exists.

## Not Yet Implemented

Push notifications, nudge feature.
