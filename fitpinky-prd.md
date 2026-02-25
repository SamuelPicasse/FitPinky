# FitPinky 🤞

**A pinky promise to show up.**

Couples & Small Group Workout Accountability App

---

| | |
|---|---|
| **Version** | 3.0 |
| **Date** | February 2026 |
| **Author** | Sammy van der Poel |
| **Status** | Draft |
| **Platform** | iOS (SwiftUI + CloudKit) |
| **Distribution** | TestFlight → App Store |

---

## 1. Product Overview

### 1.1 Vision

FitPinky is a workout accountability app for couples and small groups. The concept is simple: make a pinky promise to show up, log your workout with a photo, and settle a playful wager if you don't. No calorie tracking, no performance stats — just showing up together.

### 1.2 Core Concept

- Groups of 2–3 people make a weekly workout commitment
- Log workouts with a photo (FitCam) as proof you showed up
- Set a playful wager — loser buys dinner, does the dishes, etc.
- See each other's progress in real-time throughout the week
- At week's end: who showed up and who owes?

### 1.3 Target Audience

- Couples who want to build a workout habit together
- Small friend groups (2–3 people) who want mutual accountability
- People who've struggled with solo fitness motivation
- Age range: 20–40, iPhone users

### 1.4 Scope & Constraints

- iOS only — SwiftUI, targeting iOS 17+
- CloudKit backend — zero server costs, native Apple integration
- Groups of 2–3 members (UI optimized for 2 in v1, 3-person support in data model)
- Distribution: TestFlight initially, App Store later
- Monetization: planned for later (subscription), not in v1
- Developed with Claude Code (AI-assisted Swift development)

### 1.5 Key Differentiators

- **Accountability-first**: no workout plans, no stats, no noise — just "did you show up?"
- **Photo proof via FitCam**: creates visual accountability and a fun shared record
- **Wager system**: real-life stakes make it genuinely motivating
- **Designed for pairs**: not a social network, not a group chat — intimate and focused
- **Dead simple**: open app → take photo → done. Two taps to log a workout

---

## 2. User Stories

### 2.1 Onboarding & Pairing

| ID | User Story | Priority | Size |
|---|---|---|---|
| FP-01 | As a new user, I want to sign in with my Apple ID so I can get started with one tap. | Must Have | S |
| FP-02 | As a user, I want to create a group and get an invite code to share with my partner. | Must Have | M |
| FP-03 | As a user, I want to enter an invite code to join my partner's group. | Must Have | M |
| FP-04 | As a new group, I want to set our first weekly goal and wager together. | Must Have | S |
| FP-05 | As a user without a group, I want to see a clear invite/join screen (not an empty dashboard). | Must Have | S |

### 2.2 FitCam (Workout Logging)

| ID | User Story | Priority | Size |
|---|---|---|---|
| FP-06 | As a user, I want to log a workout by taking a photo with FitCam as proof I showed up. | Must Have | L |
| FP-07 | As a user, I want a date/time watermark on my FitCam photo to prevent cheating with old photos. | Must Have | M |
| FP-08 | As a user, I want my partner to get a push notification instantly when I log a workout. | Must Have | M |
| FP-09 | As a user, I want to browse a history of all past FitCam photos. | Should Have | M |
| FP-10 | As a user, I want to add an optional caption to my workout photo. | Could Have | S |

### 2.3 Weekly Goals & Wagers

| ID | User Story | Priority | Size |
|---|---|---|---|
| FP-11 | As a user, I want to set my own weekly workout goal (1–7 days). | Must Have | S |
| FP-12 | As a group, I want to set a shared wager for the week (free text). | Must Have | S |
| FP-13 | As a user, I want goals and wagers to persist week-to-week until I change them. | Must Have | S |
| FP-14 | As a user, I want to choose which day the workout week starts. | Should Have | S |
| FP-15 | As a user, I want to see an end-of-week result: who hit their goal and who owes the wager. | Must Have | S |

### 2.4 Dashboard

| ID | User Story | Priority | Size |
|---|---|---|---|
| FP-16 | As a user, I want to see both partners' progress toward the weekly goal on a shared dashboard. | Must Have | M |
| FP-17 | As a user, I want to see the active wager prominently on the dashboard. | Must Have | S |
| FP-18 | As a user, I want to see a streak counter (consecutive weeks both partners hit their goal). | Should Have | S |
| FP-19 | As a user, I want to see the most recent FitCam photo from each partner. | Should Have | S |
| FP-20 | As a user, I want to see how many days are left in the current week. | Must Have | S |

### 2.5 Notifications & Nudges

| ID | User Story | Priority | Size |
|---|---|---|---|
| FP-21 | As a user, I want a push notification when my partner logs a workout. | Must Have | M |
| FP-22 | As a user, I want to send a nudge to my partner when they're falling behind. | Should Have | M |
| FP-23 | As a user, I want an end-of-week summary notification. | Could Have | M |

---

## 3. Feature Specifications

### 3.1 Authentication & Groups

Authentication is handled automatically via iCloud (Sign in with Apple). Group creation uses CloudKit's sharing mechanism with invite codes for discovery.

#### Auth Flow

1. App launch → check iCloud account status via `CKContainer.accountStatus()`
2. If signed in → check for existing group membership
3. If in a group → show Dashboard
4. If not in a group → show Create/Join screen
5. If not signed into iCloud → show prompt to sign in via Settings

#### Group Creation & Invite Flow

1. User A taps "Create Group" → generates a 6-character alphanumeric invite code
2. Invite code saved to CloudKit **public database** (code + CKShare URL reference)
3. Invite code expires after 48 hours
4. User A can share code via share sheet (Messages, WhatsApp, etc.) or show it on screen
5. User B taps "Join Group" → enters invite code → looks up in public DB → accepts CKShare
6. Both users now share a private CKRecordZone with full read/write access
7. A user can only be in one active group at a time

#### Multi-Person Architecture (Future-Proof)

- Data model supports 2–3 members per group
- CKShare supports up to 100 participants — no technical limit for small groups
- **v1 UI is designed for 2 people** (side-by-side progress rings)
- v2 will extend the UI to handle 3 members (3 rings, adjusted layout)
- Group settings (wager, week start day) are shared; goals are per-member

---

### 3.2 FitCam

FitCam is the core feature. It's how you log a workout — take a photo as proof, your partner sees it instantly.

#### Camera

- Full-screen camera using `AVCaptureSession` + `AVCapturePhotoOutput`
- Front/rear camera toggle (default: front camera)
- Large circular capture button, centered at bottom
- Minimal UI — no filters, no effects, no distractions
- **Live capture only** — no camera roll picker (accountability by design)

#### Watermark

- Rendered on the captured image using Core Graphics before upload
- Format: **"Wed 26 Feb • 18:34"**
- Position: bottom-left corner with padding
- Style: semi-transparent white text, subtle drop shadow for readability
- Font size scales with device screen size

#### Capture Flow

1. Tap capture → show preview with watermark applied
2. Options: Confirm (checkmark) or Retake (X)
3. Optional: type a short caption (max 100 characters)
4. On confirm: compress to HEIC (~500KB), upload as CKAsset, trigger push to group members
5. Dismiss back to Dashboard with haptic confirmation

---

### 3.3 Weekly Goals

- Each member sets their own weekly goal: 1–7 days
- Goal persists week-to-week until manually changed
- Multiple workouts on the same calendar day count as 1 day toward the goal
- Configurable week start day (default: Monday, shared across group)
- Automatic weekly rollover: new WeeklyGoal record created at start of each week

#### End-of-Week Evaluation

- Runs locally when the app is opened after the week ends (no server-side cron needed)
- Compares each member's logged workout days vs their personal goal
- Possible results: `all_hit`, `some_missed` (who owes is listed), `all_missed`
- Result stored on the WeeklyGoal record for history
- End-of-week notification sent with results summary

---

### 3.4 Wager System

Kept intentionally simple. A shared text field describing what's at stake this week. The app doesn't enforce payment — that's between the group members.

- Single free-text field, max 200 characters, visible to all group members
- Any member can update the wager at any time
- Displayed prominently on the Dashboard (e.g. "Loser buys sushi 🍣")
- Wager text stored on the WeeklyGoal record — persists in history
- No enforcement mechanics — settling is real-life between members

---

### 3.5 Dashboard

The home screen. Shows everything at a glance. Designed for two people side-by-side.

#### Layout (v1 — 2 People)

- **Progress rings**: two circular rings side-by-side, one per partner. Ring fills based on workouts logged / personal goal. Name and "3/5 days" label below each ring. Gradient stroke (pink to purple, on-brand with FitPinky).
- **Wager card**: prominent card below the rings showing the current wager text. Playful styling.
- **Days remaining**: badge or label showing "3 days left this week"
- **Streak**: "🔥 4 week streak" — or empty state if streak is 0
- **Recent FitCam**: most recent photo thumbnail from each partner with timestamp. Tap to view full size.
- **FitCam button**: floating action button or prominent center tab — fastest path in the app

#### Design Direction

- Clean and minimal — think Apple Health meets BeReal
- Dark mode support from day one
- Brand color: pink/magenta (`#E8457C`) with warm accents
- Haptic feedback on workout log confirmation
- Subtle animations on progress ring updates

---

### 3.6 History

- Scrollable list of past weeks, newest first
- Each week shows: dates, both partners' scores vs goals, wager outcome
- Tap into a week for day-by-day detail with FitCam photo thumbnails
- FitCam gallery view: all photos grouped by week, tappable for full-screen view
- Streak history visible (consecutive weeks both hit goal)

---

### 3.7 Notifications

- **Partner logged a workout**: "Sammy just showed up! 💪" (with FitCam thumbnail if supported)
- **Nudge from partner**: "Sammy says: gym time? 😏" (custom or preset message)
- **End-of-week results**: "Week's over! You both hit your goals 🎉" or "Sammy owes: buy sushi 🍣"
- All via CloudKit `CKQuerySubscription` — no server logic needed

---

### 3.8 Settings

- Display name (editable)
- Weekly goal picker (1–7, stepper or segmented control)
- Wager text field (also editable from dashboard)
- Week start day picker (Monday–Sunday)
- Group info: partner name, invite code, leave group option
- Notification preferences
- About / version info

---

## 4. Data Model (CloudKit Records)

All group data lives in a shared private CKRecordZone. Invite codes live in the public database for discovery.

### 4.1 InviteCode (Public Database)

| Field | Type | Notes |
|---|---|---|
| recordID | CKRecord.ID | Auto-generated |
| code | String | 6-char alphanumeric, unique, indexed |
| shareURL | String | URL string of the CKShare to accept |
| creatorName | String | Display name of the group creator |
| expiresAt | Date | 48 hours after creation |
| status | String | active \| accepted \| expired |

### 4.2 Group (Shared Private Zone)

| Field | Type | Notes |
|---|---|---|
| recordID | CKRecord.ID | Auto-generated |
| name | String | Group name (optional, e.g. "Sammy & Lisa") |
| weekStartDay | Int64 | 1=Monday (default), 7=Sunday |
| maxMembers | Int64 | 2 or 3 |
| createdAt | Date | |

### 4.3 Member

| Field | Type | Notes |
|---|---|---|
| recordID | CKRecord.ID | Auto-generated |
| groupRef | CKRecord.Reference | FK to Group |
| displayName | String | Shown on dashboard and notifications |
| weeklyGoal | Int64 | Personal target days per week (1–7) |
| timezone | String | IANA timezone (e.g. Europe/Amsterdam) |
| role | String | owner \| member |
| joinedAt | Date | |

### 4.4 WeeklyGoal

| Field | Type | Notes |
|---|---|---|
| recordID | CKRecord.ID | Auto-generated |
| groupRef | CKRecord.Reference | FK to Group |
| weekStart | Date | Start date of this week |
| wagerText | String | The wager description (max 200 chars) |
| memberGoals | String (JSON) | `{ memberID: goalDays }` snapshot at week start |
| result | String? | nil \| all_hit \| some_missed \| all_missed |
| resultDetail | String? (JSON) | `{ memberID: { goal: 5, logged: 3, hit: false } }` |

### 4.5 Workout

| Field | Type | Notes |
|---|---|---|
| recordID | CKRecord.ID | Auto-generated |
| memberRef | CKRecord.Reference | FK to Member who logged it |
| groupRef | CKRecord.Reference | FK to Group |
| weeklyGoalRef | CKRecord.Reference | FK to WeeklyGoal |
| photo | CKAsset | FitCam photo (compressed HEIC, ~500KB) |
| caption | String? | Optional text (max 100 chars) |
| loggedAt | Date | Timestamp of logging (UTC) |
| workoutDate | Date | Calendar date this counts toward (user's local tz) |

### 4.6 Nudge

| Field | Type | Notes |
|---|---|---|
| recordID | CKRecord.ID | Auto-generated |
| senderRef | CKRecord.Reference | FK to Member who sent it |
| groupRef | CKRecord.Reference | FK to Group |
| message | String | Nudge text or preset emoji |
| sentAt | Date | |

---

## 5. Technical Architecture

### 5.1 Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI (iOS 17+, @Observable macro) |
| Language | Swift 5.9+ |
| Backend | CloudKit (private DB with CKShare for group sync) |
| Auth | iCloud account (automatic, no custom auth flow) |
| Invite Discovery | CloudKit public database (invite code lookup) |
| Photo Storage | CKAsset (free, automatic CDN) |
| Push Notifications | CKQuerySubscription (on Workout + Nudge record types) |
| Camera | AVFoundation (AVCaptureSession + AVCapturePhotoOutput) |
| Image Processing | Core Graphics (UIGraphicsImageRenderer for watermark) |
| Local Cache | SwiftData (offline-first, mirrors CloudKit records) |
| Widgets (v2) | WidgetKit |
| Distribution | TestFlight → App Store |
| Dev Tools | Xcode 15+ / Claude Code |

### 5.2 CloudKit Architecture

#### Database Structure

- **Public Database**: InviteCode records only — for invite code lookup by joining users
- **Private Database + CKShare**: all group data (Group, Member, WeeklyGoal, Workout, Nudge) in a shared CKRecordZone per group
- **Zone**: one CKRecordZone per group (e.g. `FitPinkyGroup_<UUID>`)

#### Sharing Flow

1. Owner creates Group record + CKRecordZone + CKShare
2. Owner saves InviteCode to public DB with CKShare URL reference
3. Joiner looks up code in public DB → retrieves CKShare URL → accepts share
4. Both users now see all records in the shared zone
5. CKQuerySubscription on Workout/Nudge types → triggers push to other zone participants

#### Sync Strategy

- Use `CKFetchRecordZoneChangesOperation` for efficient delta sync
- Store a server change token locally (SwiftData) to only fetch what's new
- On app foreground: sync latest changes
- On push notification: sync the specific record type that changed
- Offline: queue writes locally, sync when connectivity returns (CloudKit handles this)

### 5.3 Project Structure

```
FitPinky/
├── App/                    # FitPinkyApp.swift, AppDelegate
├── Views/
│   ├── Dashboard/          # DashboardView, ProgressRingView, WagerCardView
│   ├── FitCam/             # FitCamView, CameraPreviewView, WatermarkRenderer
│   ├── History/            # HistoryListView, WeekDetailView, PhotoGalleryView
│   ├── Onboarding/         # CreateGroupView, JoinGroupView, SetupGoalView
│   └── Settings/           # SettingsView, GoalPickerView, GroupInfoView
├── ViewModels/             # DashboardVM, FitCamVM, HistoryVM, OnboardingVM
├── Models/                 # Group, Member, Workout, WeeklyGoal, Nudge, InviteCode
├── Services/
│   ├── CloudKitService.swift       # All CK operations, zone management, sharing
│   ├── CameraService.swift         # AVFoundation camera management
│   ├── WatermarkService.swift      # Core Graphics watermark rendering
│   ├── NotificationService.swift   # Push notification handling + subscriptions
│   └── DataServiceProtocol.swift   # Protocol for swapping mock/real service
├── Extensions/             # Date+, CKRecord+, Color+
└── Resources/              # Assets, Colors, Fonts
```

---

## 6. Screens & Navigation

### 6.1 Tab Structure

| Tab | SF Symbol | Screen | Key Elements |
|---|---|---|---|
| Home | `house.fill` | Dashboard | Progress rings, wager, recent photos, streak |
| (Center) | `camera.fill` | FitCam | Full-screen camera, watermark, capture |
| History | `calendar` | Week History | Past weeks, results, photo gallery |
| Settings | `gearshape` | Settings | Goal, wager, week start, group info |

### 6.2 Screen Flow

**First launch**: iCloud check → Create/Join Group screen

**Create flow**: Create Group → set display name → set weekly goal → set wager → share invite code → wait for partner → Dashboard

**Join flow**: Enter invite code → set display name → set weekly goal → Dashboard

**Main loop**: Dashboard → FitCam (center tab, full-screen cover) → capture → confirm → back to Dashboard (updated)

---

## 7. Release Plan

### 7.1 v1.0 — MVP

Get the core loop working: pair up, set a goal, log workouts with FitCam, see each other's progress.

- iCloud authentication (automatic)
- Group creation + partner pairing via invite code
- FitCam with photo capture and date/time watermark
- Weekly goal setting (per partner)
- Dashboard with dual progress rings + wager display
- Wager text field (shared)
- Push notification when partner logs a workout
- Basic week history with results
- End-of-week evaluation

### 7.2 v1.1 — Polish & Retention

- FitCam photo history gallery (full-screen browsing)
- Streak counter and streak display on dashboard
- Nudge/poke button
- Custom week start day
- End-of-week summary notification
- Captions on FitCam photos
- Dark mode refinement
- Haptic feedback throughout
- Animations on progress ring updates

### 7.3 v2.0 — Growth

- iOS home screen widget (WidgetKit) showing partner progress
- 3-person group UI support
- Calendar heatmap for workout history
- Monthly recap view
- Shareable streak cards (export as image for Instagram stories)
- App Store release
- Subscription model (details TBD)

### 7.4 v2.1 — Delight (Stretch)

- Apple Watch quick-log companion
- Emoji reactions on FitCam photos
- Wager templates / suggested wagers
- Animated celebrations when both partners hit their goal
- Photo collage generation (weekly highlights)

---

## 8. Development Notes for Claude Code

These notes help guide AI-assisted development:

- Target **iOS 17+** to use `@Observable` macro and latest SwiftUI APIs (`NavigationStack`)
- CloudKit container ID: `iCloud.com.sammyvanderpoel.fitpinky` (configure in Xcode capabilities)
- Required Xcode capabilities: **iCloud** (CloudKit), **Push Notifications**, **Background Modes** (Remote Notifications)
- Add `NSCameraUsageDescription` to Info.plist ("FitPinky needs camera access for FitCam workout photos")
- Use `DataServiceProtocol` so mock and CloudKit implementations are swappable
- Build all UI against `MockDataService` first, swap to `CloudKitService` when ready
- Camera watermark: render with `UIGraphicsImageRenderer` before creating CKAsset
- Handle `CKError.networkUnavailable` gracefully — queue writes for retry
- All date logic must be timezone-aware: store in UTC, display in user's local timezone
- TestFlight builds expire after 90 days — set a calendar reminder to re-upload
- Keep the `MockDataService` permanently for Xcode previews

---

## 9. Open Questions

- Should both partners share the same week start day, or can each have their own?
- What happens if a workout is logged after midnight but before sleep? Allow backdating to "today"?
- Should nudges have preset messages, free text, or both?
- For the streak: does it break if only one partner misses, or only if both miss?
- Photo retention: keep all photos forever, or auto-clean older than X months?
- Should the dashboard show today's workout status (checkmark) or just the weekly count?
- Group naming: auto-generate (e.g. "Sammy & Lisa") or let the user pick?
- When someone leaves a group, what happens to historical data?
