import Foundation

/// Average weight over the calendar period so far (week, month, quarter or year), and its change
/// from the whole of the preceding period. Shared by the app and the widget.
///
/// Readings are first averaged per local calendar day, so several weigh-ins on one day count
/// once. Days without readings are skipped, never filled in, but each window also counts the
/// chart line's value at its start and end (see `interpolatedKg(at:)`) as one reading each.
/// A window with no readings of its own is averaged from its edges alone.
struct WeightTrend: Equatable, Sendable {
    /// Mean of the daily means and edge values in the current window; nil if it has neither.
    let average: Double?
    /// Current average minus the preceding window's, estimated from edges if that window has no
    /// readings; nil for All Time or when either window has no average. Both averages are rounded
    /// to the 0.1 kg they're shown at first, so the change always matches the averages on screen.
    let delta: Double?

    init(samples: [WeightSample], range: WeightRange, now: Date = .now, calendar: Calendar = .current) {
        let daily = samples.dailyMeans(until: now, calendar: calendar)

        guard let currentStart = range.startDate(now: now, calendar: calendar) else {
            average = daily.isEmpty ? nil : daily.map(\.kg).reduce(0, +) / Double(daily.count)
            delta = nil
            return
        }

        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let previousStart = range.startDate(now: currentStart.addingTimeInterval(-1), calendar: calendar) ?? currentStart
        let current = Self.average(
            from: currentStart, to: tomorrow, daily: daily, calendar: calendar,
            edges: [samples.interpolatedKg(at: currentStart), samples.interpolatedKg(at: now)]
        )
        let previous = Self.average(
            from: previousStart, to: currentStart, daily: daily, calendar: calendar,
            edges: [samples.interpolatedKg(at: previousStart), samples.interpolatedKg(at: currentStart)]
        )
        average = current
        if let current, let previous {
            delta = Self.rounded(current) - Self.rounded(previous)
        } else {
            delta = nil
        }
    }

    private static func rounded(_ kg: Double) -> Double {
        (kg * 10).rounded() / 10
    }

    /// Mean of the daily means from `start` up to but not including `end` (both local midnights),
    /// plus the edge values.
    private static func average(from start: Date, to end: Date, daily: [(day: Date, kg: Double)], calendar: Calendar, edges: [Double?]) -> Double? {
        let values = daily.filter { $0.day >= start && $0.day < end }.map(\.kg) + edges.compactMap { $0 }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
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
