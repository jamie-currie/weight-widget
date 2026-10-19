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

    /// Start of the range, or nil for all time. Week means the last 7 days including today.
    func startDate(now: Date = .now, calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: now)
        switch self {
        case .week: return calendar.date(byAdding: .day, value: -6, to: today)
        case .month: return calendar.date(byAdding: .month, value: -1, to: today)
        case .threeMonths: return calendar.date(byAdding: .month, value: -3, to: today)
        case .sixMonths: return calendar.date(byAdding: .month, value: -6, to: today)
        case .year: return calendar.date(byAdding: .year, value: -1, to: today)
        case .all: return nil
        }
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

    /// Latest minus first reading in the range; nil with fewer than two readings.
    var delta: Double? {
        guard count > 1, let first, let last else { return nil }
        return last.kg - first.kg
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
