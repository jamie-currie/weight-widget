import Foundation
import SwiftUI
import Testing

struct WeightTrendTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        calendar.firstWeekday = 2
        return calendar
    }()

    /// Sunday, so the current week (Mon 9 – Sun 15 Nov) is complete up to today.
    var now: Date { date(2026, 11, 15, 12) }

    func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    func reading(_ date: Date, _ kg: Double) -> WeightSample {
        WeightSample(id: UUID(), date: date, kg: kg, isFromThisApp: false)
    }

    /// Readings default to midnight, so a reading on a window's first day sits exactly on its
    /// boundary and no edge value is interpolated there.
    func reading(_ year: Int, _ month: Int, _ day: Int, _ kg: Double, hour: Int = 0, minute: Int = 0) -> WeightSample {
        reading(date(year, month, day, hour, minute), kg)
    }

    func reading(daysAgo: Int, _ kg: Double) -> WeightSample {
        reading(calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!, kg)
    }

    func november(_ days: some Sequence<Int>, _ kg: Double, hour: Int = 0) -> [WeightSample] {
        days.map { reading(2026, 11, $0, kg, hour: hour) }
    }

    func trend(_ samples: [WeightSample], _ range: WeightRange, now: Date? = nil) -> WeightTrend {
        WeightTrend(samples: samples, range: range, now: now ?? self.now, calendar: calendar)
    }

    func close(_ a: Double?, _ b: Double, within tolerance: Double = 1e-9) -> Bool {
        guard let a else { return false }
        return abs(a - b) < tolerance
    }

    // MARK: Calendar periods

    @Test func periodsStartAtTheirCalendarBoundary() {
        #expect(WeightRange.week.startDate(now: now, calendar: calendar) == date(2026, 11, 9))
        #expect(WeightRange.month.startDate(now: now, calendar: calendar) == date(2026, 11, 1))
        #expect(WeightRange.quarter.startDate(now: now, calendar: calendar) == date(2026, 10, 1))
        #expect(WeightRange.quarter.startDate(now: date(2026, 8, 15), calendar: calendar) == date(2026, 7, 1))
        #expect(WeightRange.year.startDate(now: now, calendar: calendar) == date(2026, 1, 1))
        #expect(WeightRange.all.startDate(now: now, calendar: calendar) == nil)
    }

    @Test func weekStartsOnTheCalendarsFirstWeekday() {
        var sundayFirst = calendar
        sundayFirst.firstWeekday = 1
        #expect(WeightRange.week.startDate(now: now, calendar: sundayFirst) == date(2026, 11, 15))
    }

    @Test func earlierWindowsEndOnTheLastSecondOfTheirPeriod() {
        #expect(WeightRange.week.windowEnd(offset: 0, now: now, calendar: calendar) == now)
        #expect(WeightRange.week.windowEnd(offset: 1, now: now, calendar: calendar) == date(2026, 11, 8, 23, 59, 59))
        #expect(WeightRange.month.windowEnd(offset: 1, now: now, calendar: calendar) == date(2026, 10, 31, 23, 59, 59))
        #expect(WeightRange.quarter.windowEnd(offset: 2, now: now, calendar: calendar) == date(2026, 6, 30, 23, 59, 59))
        #expect(WeightRange.year.windowEnd(offset: 1, now: now, calendar: calendar) == date(2025, 12, 31, 23, 59, 59))

        let lastWeekEnd = WeightRange.week.windowEnd(offset: 1, now: now, calendar: calendar)
        #expect(WeightRange.week.startDate(now: lastWeekEnd, calendar: calendar) == date(2026, 11, 2))
    }

    @Test func chartRunsToTheEndOfTheCurrentPeriod() {
        #expect(WeightRange.week.chartEnd(now: now, calendar: calendar) == date(2026, 11, 15, 23, 59, 59))
        #expect(WeightRange.month.chartEnd(now: now, calendar: calendar) == date(2026, 11, 30, 23, 59, 59))
        #expect(WeightRange.quarter.chartEnd(now: now, calendar: calendar) == date(2026, 12, 31, 23, 59, 59))
        #expect(WeightRange.year.chartEnd(now: now, calendar: calendar) == date(2026, 12, 31, 23, 59, 59))
        #expect(WeightRange.all.chartEnd(now: now, calendar: calendar) == now)
    }

    @Test func weekSpanningClocksGoingBackEndsAtLocalMidnight() {
        // Sunday 25 Oct 2026 was a 25-hour day.
        let sunday = date(2026, 10, 25, 12)
        #expect(WeightRange.week.startDate(now: sunday, calendar: calendar) == date(2026, 10, 19))
        #expect(WeightRange.week.chartEnd(now: sunday, calendar: calendar) == date(2026, 10, 25, 23, 59, 59))
    }

    @Test func weekSpanningClocksGoingForwardStartsAtLocalMidnight() {
        // Sunday 29 Mar 2026 was a 23-hour day.
        let wednesday = date(2026, 4, 1, 12)
        #expect(WeightRange.week.startDate(now: wednesday, calendar: calendar) == date(2026, 3, 30))
        let lastWeekEnd = WeightRange.week.windowEnd(offset: 1, now: wednesday, calendar: calendar)
        #expect(lastWeekEnd == date(2026, 3, 29, 23, 59, 59))
        #expect(WeightRange.week.startDate(now: lastWeekEnd, calendar: calendar) == date(2026, 3, 23))
    }

    // MARK: Interpolated edges

    @Test func interpolatesAlongTheStraightLineBetweenNeighbours() {
        let samples = [reading(2026, 11, 3, 80), reading(2026, 11, 1, 90), reading(2026, 11, 4, 70)]
        #expect(close(samples.interpolatedKg(at: date(2026, 11, 2)), 85))
        #expect(close(samples.interpolatedKg(at: date(2026, 11, 3, 12)), 75))
    }

    @Test func noInterpolationWithoutReadingsOnBothSidesOrOnTheDateItself() {
        let samples = [reading(2026, 11, 1, 90), reading(2026, 11, 3, 80)]
        #expect(samples.interpolatedKg(at: date(2026, 10, 31)) == nil)
        #expect(samples.interpolatedKg(at: date(2026, 11, 4)) == nil)
        #expect(samples.interpolatedKg(at: date(2026, 11, 3)) == nil)
    }

    // MARK: Averages

    @Test func averageCoversTheCalendarWeekSoFar() {
        let samples = (9...15).map { reading(2026, 11, $0, Double(71 + $0)) }
        #expect(close(trend(samples, .week).average, 83))
    }

    @Test func readingBeforeTheWindowAddsAStartEdge() {
        // The line from 104 on 8 Nov 08:00 to 80 on 9 Nov 08:00 crosses midnight at 88.
        let samples = november(9...15, 80, hour: 8) + [reading(2026, 11, 8, 104, hour: 8)]
        #expect(close(trend(samples, .week).average, (7 * 80 + 88) / 8))
    }

    @Test func earlierWindowCountsBothEdges() {
        let samples = [reading(2026, 11, 1, 90), reading(2026, 11, 3, 80), reading(2026, 11, 9, 90)]
        let lastWeekEnd = WeightRange.week.windowEnd(offset: 1, now: now, calendar: calendar)
        let result = trend(samples, .week, now: lastWeekEnd)
        // Start edge 85 on 2 Nov; end edge a second short of 90 on 9 Nov.
        #expect(close(result.average, (80 + 85 + 90) / 3, within: 1e-4))
    }

    @Test func emptyWindowIsAveragedFromItsEdges() {
        let samples = [reading(2026, 11, 1, 80), reading(2026, 11, 10, 89)]
        let lastWeekEnd = WeightRange.week.windowEnd(offset: 1, now: now, calendar: calendar)
        let result = trend(samples, .week, now: lastWeekEnd)
        #expect(close(result.average, (81 + 88) / 2, within: 1e-4))
        // The week before averages its 1 Nov reading with the 81 edge on 2 Nov.
        #expect(close(result.delta, (81 + 88) / 2 - 80.5, within: 1e-4))
    }

    @Test func noReadingsEitherSideMeansNoAverageOrDelta() {
        let result = trend([reading(2026, 9, 1, 80)], .month)
        #expect(result.average == nil)
        #expect(result.delta == nil)
    }

    @Test func missingDaysAreSkippedNotZero() {
        let samples = [reading(2026, 11, 9, 80), reading(2026, 11, 12, 82), reading(2026, 11, 15, 84)]
        #expect(close(trend(samples, .week).average, 82))
    }

    @Test func severalReadingsOnOneDayCountOnce() {
        let samples = [
            reading(2026, 11, 15, 80, hour: 7), reading(2026, 11, 15, 82, hour: 11),
            reading(2026, 11, 14, 81), reading(2026, 11, 13, 81),
        ]
        #expect(close(trend(samples, .week).average, 81))
    }

    @Test func readingAfterNowOnlyShapesTheEndEdge() {
        // The line from 80 at 08:00 to 90 at 18:00 is at 84 at noon.
        let samples = [reading(2026, 11, 15, 80, hour: 8), reading(2026, 11, 15, 90, hour: 18)]
        #expect(close(trend(samples, .week).average, 82))
    }

    // MARK: Deltas

    @Test func deltaComparesWithTheWholePreviousWeek() {
        let samples = november(9...15, 80) + november(2...8, 81) + november(1...1, 100)
        let result = trend(samples, .week)
        #expect(close(result.average, 80))
        #expect(close(result.delta, -1))
    }

    @Test func sharedEdgeCountsInBothWindows() {
        // Both windows share the 80.33 edge at 9 Nov midnight: (7 × 80 + 80.33) / 8 shows as 80.0
        // and (7 × 81 + 80.33) / 8 as 80.9.
        let samples = november(9...15, 80, hour: 8) + november(2...8, 81, hour: 8)
        #expect(close(trend(samples, .week).delta, -0.9))
    }

    @Test func monthDeltaComparesWithTheWholePreviousMonth() {
        let current = november(stride(from: 1, through: 15, by: 2), 79)
        let previous = stride(from: 1, through: 31, by: 3).map { reading(2026, 10, $0, 80.5) }
        #expect(close(trend(current + previous, .month).delta, -1.5))
    }

    @Test func yearDeltaComparesTheYearSoFarWithTheWholeOfLastYear() {
        func weekly(from start: Date, through end: Date, _ kg: Double) -> [WeightSample] {
            stride(from: 0, to: 53, by: 1)
                .compactMap { calendar.date(byAdding: .day, value: $0 * 7, to: start) }
                .filter { $0 <= end }
                .map { reading($0, kg) }
        }
        let current = weekly(from: date(2026, 1, 1), through: now, 80)
        let previous = weekly(from: date(2025, 1, 1), through: date(2025, 12, 31), 82)
        #expect(close(trend(current + previous, .year).delta, -2))
    }

    @Test func deltaShowsEvenWithSparseReadings() {
        let samples = [reading(2026, 11, 15, 80), reading(2026, 11, 8, 81)]
        // Both windows also share the edge on 9 Nov, which cancels out.
        #expect(close(trend(samples, .week).delta, -0.5))
    }

    @Test func previousWindowWithoutReadingsIsEstimated() {
        // Last week has no readings; the line from 84 on 1 Nov to 80 on 9 Nov is at 83.5 on 2 Nov.
        let samples = november(9...15, 80) + [reading(2026, 11, 1, 84)]
        #expect(close(trend(samples, .week).delta, 80 - 83.5))
    }

    @Test func noDeltaWithNothingBeforeTheCurrentWindow() {
        let result = trend(november(9...15, 80), .week)
        #expect(close(result.average, 80))
        #expect(result.delta == nil)
    }

    @Test func deltaMatchesTheRoundedAverages() {
        // Both averages show as 80.0, so the change is 0 rather than the exact 0.08.
        let samples = november(9...15, 80.04) + november(2...8, 79.96)
        #expect(close(trend(samples, .week).delta, 0))
        let apart = november(9...15, 80.06) + november(2...8, 79.94)
        #expect(close(trend(apart, .week).delta, 0.2))
    }

    // MARK: All time

    @Test func allTimeAveragesEveryDayAndHasNoDelta() {
        let samples = [
            reading(daysAgo: 1000, 90), reading(daysAgo: 500, 85),
            reading(2026, 11, 15, 80, hour: 7), reading(2026, 11, 15, 70, hour: 11),
        ]
        let result = trend(samples, .all)
        #expect(close(result.average, (90 + 85 + 75) / 3))
        #expect(result.delta == nil)
    }

    // MARK: Calendar-day boundaries

    @Test func readingsAreSplitAtLocalMidnight() {
        let current = november(10...15, 80, hour: 8) + [reading(2026, 11, 9, 80)]
        let previous = [reading(2026, 11, 8, 82, hour: 23, minute: 59)] + november(2...7, 82, hour: 8)
        let result = trend(current + previous, .week)
        // The 9 Nov reading sits exactly on the boundary, so there's no edge to blur the split.
        #expect(close(result.average, 80))
        #expect(close(result.delta, -2))
    }

    @Test func extraHourOnClocksBackDayStaysOneDay() {
        let early = reading(date(2026, 10, 25, 0, 30), 80)
        let late = reading(date(2026, 10, 25, 23, 30), 82)
        let daily = [early, late].dailyMeans(until: now, calendar: calendar)
        #expect(daily.count == 1)
        #expect(close(daily.first?.kg, 81))
    }

    @Test func edgeAtAWindowStartAfterClocksGoForward() {
        let wednesday = date(2026, 4, 1, 12)
        let samples = [reading(date(2026, 3, 30, 0, 1), 80), reading(date(2026, 3, 29, 23, 59), 90)]
        // The line crosses Monday midnight halfway between the two readings, at 85.
        #expect(close(trend(samples, .week, now: wednesday).average, (80 + 85) / 2))
    }

    // MARK: Formatting

    @Test func formattingAndColourUseTheFlatThreshold() {
        #expect(WeightFormat.delta(0.04) == "0.0 kg")
        #expect(WeightFormat.delta(-0.049) == "0.0 kg")
        #expect(WeightFormat.delta(0.06) == "+0.1 kg")
        #expect(WeightFormat.delta(-0.26) == "−0.3 kg")
        #expect(WeightFormat.deltaColor(0.04) == .secondary)
        #expect(WeightFormat.deltaColor(-0.049) == .secondary)
        #expect(WeightFormat.deltaColor(0.06) == .orange)
        #expect(WeightFormat.deltaColor(-0.06) == .green)
    }

    // MARK: App and widget agree

    @Test(arguments: WeightRange.allCases)
    func widgetCacheGivesSameTrendAsApp(range: WeightRange) throws {
        let samples = (0..<800).map { reading(daysAgo: 799 - $0, 85 - Double($0) * 0.01 + sin(Double($0)) * 0.4) }
        let cached = try JSONDecoder().decode([WeightSample].self, from: JSONEncoder().encode(samples))
        let app = trend(samples, range)
        let widget = trend(cached, range)
        #expect(app == widget)
        #expect(app.average != nil)
        #expect((app.delta == nil) == (range == .all))
    }
}
