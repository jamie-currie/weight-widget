import Foundation

enum WeightRange: String, CaseIterable, Codable, Identifiable, Sendable {
    case week, month
    /// Keeps its old raw value so saved settings from when it was "3 Months" still load.
    case quarter = "threeMonths"
    case year, all

    var id: Self { self }

    var shortTitle: String {
        switch self {
        case .week: "W"
        case .month: "M"
        case .quarter: "Q"
        case .year: "Y"
        case .all: "All"
        }
    }

    var title: String {
        switch self {
        case .week: "Week"
        case .month: "Month"
        case .quarter: "Quarter"
        case .year: "Year"
        case .all: "All Time"
        }
    }

    /// What the delta is measured against: the preceding calendar period.
    var comparisonTitle: String? {
        switch self {
        case .week: "vs last week"
        case .month: "vs last month"
        case .quarter: "vs last quarter"
        case .year: "vs last year"
        case .all: nil
        }
    }

    /// Each window is a calendar period of this length: a week (starting on the locale's first
    /// weekday), a month, a quarter or a year. Nil for all time, which is a single window.
    var period: (component: Calendar.Component, count: Int)? {
        switch self {
        case .week: (.weekOfYear, 1)
        case .month: (.month, 1)
        case .quarter: (.month, 3)
        case .year: (.month, 12)
        case .all: nil
        }
    }

    /// Start of the calendar period containing `now`, or nil for all time.
    func startDate(now: Date = .now, calendar: Calendar = .current) -> Date? {
        switch period {
        case nil:
            return nil
        case (.weekOfYear, _)?:
            return calendar.dateInterval(of: .weekOfYear, for: now)?.start
        case (_, let months)?:
            let parts = calendar.dateComponents([.year, .month], from: now)
            guard let year = parts.year, let month = parts.month else { return nil }
            return calendar.date(from: DateComponents(year: year, month: (month - 1) / months * months + 1, day: 1))
        }
    }

    /// End of the window `offset` windows before the current one. The current window ends at `now`;
    /// earlier ones end at the last second of their final day.
    func windowEnd(offset: Int, now: Date = .now, calendar: Calendar = .current) -> Date {
        guard offset > 0 else { return now }
        return periodEnd(windowsAhead: 1 - offset, now: now, calendar: calendar) ?? now
    }

    /// Right-hand end of the chart: the end of the period, so the current one is laid out like the
    /// earlier ones. For All, `now`.
    func chartEnd(now: Date = .now, calendar: Calendar = .current) -> Date {
        periodEnd(windowsAhead: 1, now: now, calendar: calendar) ?? now
    }

    /// The last second before the start of the period `windowsAhead` periods after the current one.
    private func periodEnd(windowsAhead: Int, now: Date, calendar: Calendar) -> Date? {
        guard let period, let start = startDate(now: now, calendar: calendar),
              let nextStart = calendar.date(byAdding: period.component, value: period.count * windowsAhead, to: start) else { return nil }
        return nextStart.addingTimeInterval(-1)
    }

    /// Longer ranges are averaged into buckets so the line stays readable.
    var chartBucket: Calendar.Component? {
        switch self {
        case .week, .month: nil
        case .quarter: .day
        case .year, .all: .weekOfYear
        }
    }
}

extension Array where Element == WeightSample {
    /// Samples inside the range, oldest first. Assumes self is sorted oldest first.
    func filtered(to range: WeightRange, now: Date = .now) -> [WeightSample] {
        guard let start = range.startDate(now: now) else { return self }
        return filter { $0.date >= start && $0.date <= now }
    }

    /// Where the straight line between the nearest readings either side of `date` crosses it, however
    /// far apart they are. Nil unless there's a reading on each side, or if one is exactly at `date`.
    func interpolatedKg(at date: Date) -> Double? {
        guard !contains(where: { $0.date == date }),
              let before = filter({ $0.date < date }).max(by: { $0.date < $1.date }),
              let after = filter({ $0.date > date }).min(by: { $0.date < $1.date }) else { return nil }
        let fraction = date.timeIntervalSince(before.date) / after.date.timeIntervalSince(before.date)
        return before.kg + (after.kg - before.kg) * fraction
    }

    func chartPoints(for range: WeightRange, calendar: Calendar = .current) -> [WeightSample] {
        guard let component = range.chartBucket else { return self }
        let groups = Dictionary(grouping: self) {
            calendar.dateInterval(of: component, for: $0.date)?.start ?? $0.date
        }
        return groups.values.map { items in
            let kg = items.map(\.kg).reduce(0, +) / Double(items.count)
            let time = items.map(\.date.timeIntervalSinceReferenceDate).reduce(0, +) / Double(items.count)
            return WeightSample(id: items[0].id, date: Date(timeIntervalSinceReferenceDate: time), kg: kg, isFromThisApp: false)
        }
        .sorted { $0.date < $1.date }
    }
}
