import Foundation
import SwiftUI
import Testing

struct WeightTrendTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    /// Monday after UK clocks went back (Sunday 25 Oct 2026 was a 25-hour day).
    var now: Date { date(2026, 10, 26, 12) }

    func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 9, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func reading(daysAgo: Int, _ kg: Double, hour: Int = 8, minute: Int = 0) -> WeightSample {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
        let time = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
        return WeightSample(id: UUID(), date: time, kg: kg, isFromThisApp: false)
    }

    func trend(_ samples: [WeightSample], _ range: WeightRange, requirements: TrendRequirements = .standard) -> WeightTrend {
        WeightTrend(samples: samples, range: range, now: now, calendar: calendar, requirements: requirements)
    }

    func close(_ a: Double?, _ b: Double) -> Bool {
        guard let a else { return false }
        return abs(a - b) < 1e-9
    }

    // MARK: Rolling averages

    @Test func weekAverageUsesLastSevenDaysIncludingToday() {
        let samples = (0..<7).map { reading(daysAgo: $0, 80 + Double($0)) } + [reading(daysAgo: 7, 200)]
        #expect(close(trend(samples, .week).average, 83))
    }

    @Test(arguments: [(WeightRange.month, 30), (.threeMonths, 90), (.sixMonths, 180), (.year, 365)])
    func windowLengthMatchesRange(range: WeightRange, days: Int) {
        let samples = [reading(daysAgo: days - 1, 70), reading(daysAgo: days, 90)]
        #expect(close(trend(samples, range).average, 70))
        #expect(range.days == days)
    }

    @Test func deltaComparesConsecutiveNonOverlappingWindows() {
        let current = (0..<7).map { reading(daysAgo: $0, 80) }
        let previous = (7..<14).map { reading(daysAgo: $0, 81) }
        let older = (14..<21).map { reading(daysAgo: $0, 100) }
        let result = trend(current + previous + older, .week)
        #expect(close(result.average, 80))
        #expect(close(result.delta, -1))
    }

    @Test func monthDeltaUsesThirtyDayWindows() {
        let current = stride(from: 0, to: 30, by: 3).map { reading(daysAgo: $0, 79) }
        let previous = stride(from: 30, to: 60, by: 3).map { reading(daysAgo: $0, 80.5) }
        #expect(close(trend(current + previous, .month).delta, -1.5))
    }

    // MARK: Missing, sparse and repeated readings

    @Test func missingDaysAreSkippedNotZero() {
        let samples = [reading(daysAgo: 0, 80), reading(daysAgo: 3, 82), reading(daysAgo: 6, 84)]
        #expect(close(trend(samples, .week).average, 82))
    }

    @Test func severalReadingsOnOneDayCountOnce() {
        let samples = [
            reading(daysAgo: 0, 80, hour: 7), reading(daysAgo: 0, 82, hour: 11),
            reading(daysAgo: 1, 81), reading(daysAgo: 2, 81),
        ]
        #expect(close(trend(samples, .week).average, 81))
    }

    @Test func noDeltaWhenPreviousWindowHasTooFewDays() {
        let current = (0..<7).map { reading(daysAgo: $0, 80) }
        let previous = [reading(daysAgo: 8, 81), reading(daysAgo: 12, 81)]
        let result = trend(current + previous, .week)
        #expect(result.delta == nil)
        #expect(close(result.average, 80))
    }

    @Test func noDeltaWhenCurrentWindowHasTooFewDays() {
        let current = [reading(daysAgo: 0, 80), reading(daysAgo: 5, 80)]
        let previous = (7..<14).map { reading(daysAgo: $0, 81) }
        #expect(trend(current + previous, .week).delta == nil)
    }

    @Test func noDeltaWhenReadingsAreBunchedAtOneEnd() {
        let current = (0..<7).map { reading(daysAgo: $0, 80) }
        let bunched = (11..<14).map { reading(daysAgo: $0, 81) }
        #expect(trend(current + bunched, .week).delta == nil)

        let spread = [9, 11, 13].map { reading(daysAgo: $0, 81) }
        #expect(close(trend(current + spread, .week).delta, -1))
    }

    @Test func requirementsAreConfigurable() {
        let samples = [reading(daysAgo: 0, 80), reading(daysAgo: 7, 81)]
        #expect(trend(samples, .week).delta == nil)
        let relaxed = TrendRequirements(rules: [.week: .init(minimumDays: 1, segments: 1)])
        #expect(close(trend(samples, .week, requirements: relaxed).delta, -1))
    }

    @Test func noReadingsMeansNoAverageOrDelta() {
        let result = trend([reading(daysAgo: 40, 80)], .month)
        #expect(result.average == nil)
        #expect(result.delta == nil)
    }

    // MARK: All time

    @Test func allTimeAveragesEveryDayAndHasNoDelta() {
        let samples = [
            reading(daysAgo: 1000, 90), reading(daysAgo: 500, 85),
            reading(daysAgo: 0, 80, hour: 7), reading(daysAgo: 0, 70, hour: 11),
        ]
        let result = trend(samples, .all)
        #expect(close(result.average, (90 + 85 + 75) / 3))
        #expect(result.delta == nil)
        #expect(WeightRange.all.startDate(now: now, calendar: calendar) == nil)
    }

    // MARK: Precision and rounding

    @Test func deltaKeepsFullPrecision() {
        let current = (0..<7).map { reading(daysAgo: $0, 80.04) }
        let previous = (7..<14).map { reading(daysAgo: $0, 79.96) }
        // Rounding the averages first would give 80.0 - 80.0 = 0.
        #expect(close(trend(current + previous, .week).delta, 0.08))
    }

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

    // MARK: Calendar-day boundaries

    @Test func readingsAreSplitAtLocalMidnight() {
        let current = (0..<6).map { reading(daysAgo: $0, 80) } + [reading(daysAgo: 6, 80, hour: 0, minute: 0)]
        let previous = [reading(daysAgo: 7, 82, hour: 23, minute: 59)] + (8..<14).map { reading(daysAgo: $0, 82) }
        let result = trend(current + previous, .week)
        #expect(close(result.average, 80))
        #expect(close(result.delta, -2))
    }

    @Test func windowStartIsLocalMidnightAcrossDaylightSaving() {
        // The week spans the 25-hour day when clocks went back.
        #expect(WeightRange.week.startDate(now: now, calendar: calendar) == date(2026, 10, 20, 0))
        let samples = [
            WeightSample(id: UUID(), date: date(2026, 10, 20, 0, 1), kg: 80, isFromThisApp: false),
            WeightSample(id: UUID(), date: date(2026, 10, 19, 23, 59), kg: 90, isFromThisApp: false),
        ]
        #expect(close(trend(samples, .week).average, 80))
    }

    @Test func extraHourOnClocksBackDayStaysOneDay() {
        let early = WeightSample(id: UUID(), date: date(2026, 10, 25, 0, 30), kg: 80, isFromThisApp: false)
        let late = WeightSample(id: UUID(), date: date(2026, 10, 25, 23, 30), kg: 82, isFromThisApp: false)
        let daily = [early, late].dailyMeans(until: now, calendar: calendar)
        #expect(daily.count == 1)
        #expect(close(daily.first?.kg, 81))
    }

    @Test func springForwardWindowsStayAligned() {
        // UK clocks went forward on 29 Mar 2026 (a 23-hour day).
        let springNow = date(2026, 4, 1, 12)
        #expect(WeightRange.week.startDate(now: springNow, calendar: calendar) == date(2026, 3, 26, 0))
        let samples = [
            WeightSample(id: UUID(), date: date(2026, 3, 26, 0, 1), kg: 80, isFromThisApp: false),
            WeightSample(id: UUID(), date: date(2026, 3, 25, 23, 59), kg: 90, isFromThisApp: false),
        ]
        let result = WeightTrend(samples: samples, range: .week, now: springNow, calendar: calendar)
        #expect(close(result.average, 80))
    }

    @Test func readingsAfterNowAreIgnored() {
        let samples = [reading(daysAgo: 0, 80, hour: 8), reading(daysAgo: 0, 90, hour: 18)]
        #expect(close(trend(samples, .week).average, 80))
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
