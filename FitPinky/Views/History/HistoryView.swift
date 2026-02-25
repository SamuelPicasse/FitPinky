import SwiftUI

struct HistoryView: View {
    @Environment(MockDataService.self) private var dataService

    var body: some View {
        NavigationStack {
            List {
                let pastWeeks = dataService.getPastWeeks()
                if pastWeeks.isEmpty {
                    ContentUnavailableView(
                        "No History Yet",
                        systemImage: "calendar",
                        description: Text("Completed weeks will show up here.")
                    )
                } else {
                    ForEach(pastWeeks) { week in
                        weekRow(week)
                    }
                }
            }
            .navigationTitle("History")
        }
    }

    private func weekRow(_ week: WeeklyGoal) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Week of \(week.weekStart.formatted(.dateTime.month().day()))")
                .font(.headline)

            if let result = week.result {
                Text(resultLabel(result))
                    .font(.subheadline)
                    .foregroundStyle(resultColor(result))
            }

            if !week.wagerText.isEmpty {
                Text(week.wagerText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func resultLabel(_ result: WeekResult) -> String {
        switch result {
        case .bothHit: "Both hit their goal!"
        case .aOwes: "\(dataService.currentUser.displayName) owes"
        case .bOwes: "\(dataService.partner.displayName) owes"
        case .bothMissed: "Both missed"
        }
    }

    private func resultColor(_ result: WeekResult) -> Color {
        switch result {
        case .bothHit: .green
        case .bothMissed: .red
        case .aOwes, .bOwes: .orange
        }
    }
}
