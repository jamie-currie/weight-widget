import Foundation

enum WeightRange: String, CaseIterable, Codable, Identifiable, Sendable {
    case week, month, threeMonths, sixMonths, year, all

    var id: Self { self }

    var shortTitle: String {
        switch self {
        case .week: "W"
        case .month: "M"
        case .threeMonths: "3M"
        case .sixMonths: "6M"
        case .year: "Y"
        case .all: "All"
        }
    }

    var title: String {
        switch self {
        case .week: "Week"
        case .month: "Month"
        case .threeMonths: "3 Months"
        case .sixMonths: "6 Months"
        case .year: "Year"
        case .all: "All Time"
        }
    }

    /// What the delta is measured against: the preceding window of the same length.
    var comparisonTitle: String? {
        switch self {
        case .week: "vs last week"
        case .month: "vs last month"
        case .threeMonths: "vs previous 3 months"
        case .sixMonths: "vs previous 6 months"
        case .year: "vs last year"
        case .all: nil
        }
    }

    /// Length of the rolling window in calendar days, including today; nil for all time.
    var days: Int? {
        switch self {
        case .week: 7
        case .month: 30
        case .threeMonths: 90
        case .sixMonths: 180
        case .year: 365
        case .all: nil
        }
    }

    /// Start of the range, or nil for all time. The range is the last `days` days including today.
    func startDate(now: Date = .now, calendar: Calendar = .current) -> Date? {
        guard let days else { return nil }
        return calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now))
    }

    /// Longer ranges are averaged into buckets so the line stays readable.
    var chartBucket: Calendar.Component? {
        switch self {
        case .week, .month: nil
        case .threeMonths, .sixMonths: .day
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

    /// The most recent reading before the range starts, however old. Assumes self is sorted oldest first.
    func lastBefore(_ range: WeightRange, now: Date = .now) -> WeightSample? {
        guard let start = range.startDate(now: now) else { return nil }
        return last { $0.date < start }
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
