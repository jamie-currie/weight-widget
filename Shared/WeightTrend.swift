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
        .quarter: Rule(minimumDays: 10, segments: 3),
        .year: Rule(minimumDays: 20, segments: 4),
    ])
}

/// Average weight over the calendar period so far (week, month, quarter or year), and its change
/// from the whole of the preceding period. Shared by the app and the widget.
///
/// Readings are first averaged per local calendar day, so several weigh-ins on one day count
/// once. Days without readings are skipped, never filled in, but each window also counts the
/// chart line's value at its start and end (see `interpolatedKg(at:)`) as one reading each.
/// A window with no readings of its own is averaged from its edges alone. The edges don't count
/// towards the requirements.
struct WeightTrend: Equatable, Sendable {
    /// Mean of the daily means and edge values in the current window; nil if it has neither.
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
        let daily = samples.dailyMeans(until: now, calendar: calendar)

        guard let currentStart = range.startDate(now: now, calendar: calendar) else {
            average = daily.isEmpty ? nil : daily.map(\.kg).reduce(0, +) / Double(daily.count)
            delta = nil
            return
        }

        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let previousStart = range.startDate(now: currentStart.addingTimeInterval(-1), calendar: calendar) ?? currentStart
        let current = Window(
            from: currentStart, to: tomorrow, daily: daily, calendar: calendar,
            edges: [samples.interpolatedKg(at: currentStart), samples.interpolatedKg(at: now)]
        )
        let previous = Window(
            from: previousStart, to: currentStart, daily: daily, calendar: calendar,
            edges: [samples.interpolatedKg(at: previousStart), samples.interpolatedKg(at: currentStart)]
        )
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
    let edges: [Double]
    let length: Int

    /// The days from `start` up to but not including `end`, both local midnights.
    init(from start: Date, to end: Date, daily: [(day: Date, kg: Double)], calendar: Calendar, edges: [Double?]) {
        let length = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        self.length = length
        self.edges = edges.compactMap { $0 }
        var offsets: [Int] = []
        var values: [Double] = []
        for (day, kg) in daily {
            guard let position = calendar.dateComponents([.day], from: start, to: day).day,
                  (0..<length).contains(position) else { continue }
            offsets.append(position)
            values.append(kg)
        }
        dayOffsets = offsets
        self.values = values
    }

    var average: Double? {
        let all = values + edges
        guard !all.isEmpty else { return nil }
        return all.reduce(0, +) / Double(all.count)
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
