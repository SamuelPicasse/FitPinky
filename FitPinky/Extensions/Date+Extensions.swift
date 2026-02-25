import Foundation

extension Date {
    /// Start of the current week (Monday by default).
    /// weekStartDay uses 1=Monday ... 7=Sunday (app convention).
    func startOfWeek(weekStartDay: Int = 1) -> Date {
        let calendar = Calendar.current
        // Convert app convention (1=Mon..7=Sun) to Calendar convention (1=Sun, 2=Mon..7=Sat)
        let calendarWeekday = weekStartDay == 7 ? 1 : weekStartDay + 1

        // Find the most recent occurrence of that weekday
        let current = calendar.component(.weekday, from: self)
        let daysBack = (current - calendarWeekday + 7) % 7
        return calendar.startOfDay(for: calendar.date(byAdding: .day, value: -daysBack, to: self)!)
    }

    /// Calendar date component only (strips time), useful for "same day" comparisons
    var calendarDate: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Watermark format: "Wed 26 Feb • 18:34"
    var watermarkString: String {
        let day = formatted(.dateTime.weekday(.abbreviated))
        let date = formatted(.dateTime.day().month(.abbreviated))
        let time = formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        return "\(day) \(date) \u{2022} \(time)"
    }

    /// Days remaining in the week (inclusive of today).
    /// On the last day of the week, returns 1. On the first day, returns 7.
    func daysRemainingInWeek(weekStartDay: Int = 1) -> Int {
        let calendar = Calendar.current
        let weekStart = startOfWeek(weekStartDay: weekStartDay)
        let daysSinceStart = calendar.dateComponents([.day], from: weekStart, to: calendarDate).day ?? 0
        return max(1, 7 - daysSinceStart)
    }

    /// Format a week range: "Feb 17 - Feb 23"
    func weekDateRange(weekStartDay: Int = 1) -> String {
        let start = startOfWeek(weekStartDay: weekStartDay)
        let end = Calendar.current.date(byAdding: .day, value: 6, to: start)!
        let startStr = start.formatted(.dateTime.month(.abbreviated).day())
        let endStr = end.formatted(.dateTime.month(.abbreviated).day())
        return "\(startStr) - \(endStr)"
    }
}
