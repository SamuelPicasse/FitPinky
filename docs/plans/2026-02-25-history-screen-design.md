# History Screen Design

## Overview

Build the History tab: a list of past weeks with results, a week detail view with day-by-day breakdown, a reusable full-screen photo viewer, and streak display. All backed by expanded mock data.

## Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `MockDataService.swift` | Modify | 5 past weeks with varied results, ~33 workouts with photos |
| `DataServiceProtocol.swift` | Modify | Add `getBestStreak() -> Int` |
| `Date+Extensions.swift` | Modify | Add `weekDateRange(weekStartDay:)` formatter |
| `HistoryView.swift` | Rewrite | Dark card list + streak header |
| `WeekDetailView.swift` | Create | Progress rings + day-by-day + wager result |
| `PhotoFullScreenView.swift` | Create | Reusable swipeable photo viewer |
| `DashboardView.swift` | Modify | Replace inline overlay with PhotoFullScreenView |

## Mock Data

6 weeks total (1 current + 5 past):

| Offset | Wager | Sammy | Jotta | Result |
|--------|-------|-------|-------|--------|
| Current | Loser buys sushi | 2/4 | 1/4 | nil |
| -1 wk | Loser does the dishes | 4/4 | 4/4 | bothHit |
| -2 wk | Loser cooks dinner | 5/5 | 3/3 | bothHit |
| -3 wk | Loser plans date night | 3/4 | 4/4 | aOwes |
| -4 wk | Loser gives a massage | 4/4 | 3/4 | bOwes |
| -5 wk | Loser buys coffee all week | 2/4 | 1/3 | bothMissed |

Current streak: 2 (weeks 1+2 ago). Best streak: 2.

Each past week gets workouts spread across its days, with mock colored photos.

## History List View

- NavigationStack, dark background (`Color.surfaceBackground`)
- Streak card at top: current streak + best streak (or "Start your streak!" if 0)
- Week cards: dark card style, each a NavigationLink to WeekDetailView
  - Week date range: "Feb 17 - Feb 23"
  - Partner results: "Sammy 4/4 checkmark  Jotta 4/4 checkmark"
  - Wager outcome text
  - Horizontal row of photo thumbnails (max 4 visible)
- ContentUnavailableView if no past weeks

## Week Detail View

- Nav title: week date range
- Progress rings card (same component as Dashboard, extracted as shared helper)
- Day-by-day card: 7 rows (Mon-Sun), each showing partner thumbnails or dimmed state
- Wager result card at bottom
- Tap any photo opens PhotoFullScreenView

## Photo Full-Screen View

- Presented as `.fullScreenCover`
- Takes array of `(Workout, UserProfile)` tuples + starting index
- TabView with .page style for swipe navigation
- Each page: photo scaled to fit, member name, date/time, caption
- X button to dismiss, drag-down gesture to dismiss
- Replaces Dashboard's inline `fullScreenPhotoOverlay`

## Protocol Addition

```swift
func getBestStreak() -> Int
```

Scans all completed weeks for longest consecutive bothHit run.

## Date Extension

```swift
func weekDateRange(weekStartDay: Int) -> String
```

Returns "Feb 17 - Feb 23" format from a week start date.
