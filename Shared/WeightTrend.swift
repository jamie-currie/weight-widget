import Foundation

/// How much data a window needs before its average is compared. Both the current and the
/// preceding window must pass, otherwise no delta is shown.
struct TrendRequirements: Sendable {
    struct Rule: Sendable {
        /// Distinct days with at least one reading.
        var minimumDays: Int
        /// The window is split into this many equal parts and each needs a reading day, so a
        /// burst of weigh-ins at one end can't stand in for the whole window.
        var segments: Int
    }

    var rules: [WeightRange: Rule]

    static let standard = TrendRequirements(rules: [
        .week: Rule(minimumDays: 3, segments: 2),
        .month: Rule(minimumDays: 6, segments: 3),
        .threeMonths: Rule(minimumDays: 10, segments: 3),
        .sixMonths: Rule(minimumDays: 15, segments: 3),
        .year: Rule(minimumDays: 20, segments: 4),
    ])
}

/// Average weight over a range's rolling window ending today, and its change from the
/// immediately preceding window of the same length. Shared by the app and the widget.
///
/// Readings are first averaged per local calendar day, so several weigh-ins on one day count
/// once. Days without readings are skipped, never filled in.
struct WeightTrend: Equatable, Sendable {
    /// Mean of the daily means in the current window; nil if it has no readings.
    let average: Double?
    /// Current average minus the preceding window's; nil for All Time or when either window
    /// fails the requirements.
    let delta: Double?

    init(
        samples: [WeightSample],
        range: WeightRange,
        now: Date = .now,
        calendar: Calendar = .current,
        requirements: TrendRequirements = .standard
    ) {
        let today = calendar.startOfDay(for: now)
        let daily = samples.dailyMeans(until: now, calendar: calendar)

        guard let length = range.days else {
            average = daily.isEmpty ? nil : daily.map(\.kg).reduce(0, +) / Double(daily.count)
            delta = nil
            return
        }

        let current = Window(endingBefore: today, offset: 0, length: length, daily: daily, calendar: calendar)
        let previous = Window(endingBefore: today, offset: length, length: length, daily: daily, calendar: calendar)
        average = current.average

        if let rule = requirements.rules[range],
           current.satisfies(rule), previous.satisfies(rule),
           let now = current.average, let before = previous.average {
            delta = now - before
        } else {
            delta = nil
        }
    }
}

private struct Window {
    /// Day offsets from the window's first day (0..<length) for each day with a reading.
    let dayOffsets: [Int]
    let values: [Double]
    let length: Int

    /// The `length` days ending `offset` days before today (today itself is in the offset-0 window).
    init(endingBefore today: Date, offset: Int, length: Int, daily: [(day: Date, kg: Double)], calendar: Calendar) {
        self.length = length
        var offsets: [Int] = []
        var values: [Double] = []
        for (day, kg) in daily {
            guard let daysAgo = calendar.dateComponents([.day], from: day, to: today).day else { continue }
            let position = length - 1 - (daysAgo - offset)
            guard (0..<length).contains(position) else { continue }
            offsets.append(position)
            values.append(kg)
        }
        dayOffsets = offsets
        self.values = values
    }

    var average: Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    func satisfies(_ rule: TrendRequirements.Rule) -> Bool {
        guard dayOffsets.count >= rule.minimumDays else { return false }
        let segments = max(rule.segments, 1)
        let covered = Set(dayOffsets.map { $0 * segments / length })
        return covered.count == segments
    }
}

extension Array where Element == WeightSample {
    /// Mean reading per local calendar day, oldest first. Ignores readings after `now`.
    /// Sorted so sums run in the same order every time and the app and widget get identical results.
    func dailyMeans(until now: Date = .now, calendar: Calendar = .current) -> [(day: Date, kg: Double)] {
        let groups = Dictionary(grouping: filter { $0.date <= now }) { calendar.startOfDay(for: $0.date) }
        return groups
            .map { day, items in (day: day, kg: items.map(\.kg).reduce(0, +) / Double(items.count)) }
            .sorted { $0.day < $1.day }
    }
}
