import Charts
import SwiftUI

/// Line graph of weight over a range with a dashed target line and a dotted range-average line.
/// Used by the app and the widget.
struct WeightChart: View {
    let points: [WeightSample]
    let target: Double?
    var average: Double?
    let range: WeightRange
    /// Where the line crosses the left and right edges, so it doesn't start or stop mid-chart.
    var startKg: Double?
    var endKg: Double?
    var compact = false
    /// The reading or edge point nearest this date gets a label with its value.
    var selectedDate: Date?
    var now: Date = .now
    @Environment(\.colorScheme) private var colorScheme

    /// `.primary` doesn't follow dark mode inside chart axes (labels came out black, lines
    /// tinted), so pick the colour explicitly.
    private var ink: Color { colorScheme == .dark ? .white : .black }

    var body: some View {
        Chart {
            ForEach(linePoints) { point in
                LineMark(x: .value("Date", point.date), y: .value("Weight", point.kg))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: compact ? 2 : 2.5, lineCap: .round))
                    .foregroundStyle(Color.accentColor)
            }

            ForEach(plotted) { point in
                if plotted.count <= 40 {
                    PointMark(x: .value("Date", point.date), y: .value("Weight", point.kg))
                        .symbolSize(compact ? 14 : 18)
                        .foregroundStyle(Color.accentColor)
                }
            }

            if !compact {
                ForEach(linePoints.filter(isEdge)) { point in
                    PointMark(x: .value("Date", point.date), y: .value("Weight", point.kg))
                        .symbol {
                            Circle()
                                .strokeBorder(Color.accentColor, lineWidth: 1.5)
                                .frame(width: 7, height: 7)
                        }
                }
            }

            if let last = plotted.last {
                PointMark(x: .value("Date", last.date), y: .value("Weight", last.kg))
                    .symbolSize(compact ? 30 : 50)
                    .foregroundStyle(Color.accentColor)
            }

            if let target {
                RuleMark(y: .value("Target", target))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.green)
                    .annotation(position: .top, alignment: .leading, spacing: 2) {
                        if !compact {
                            Text("Target \(WeightFormat.number(target))")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
            }

            if let average, !linePoints.isEmpty {
                RuleMark(y: .value("Average", average))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [1, 4]))
                    .foregroundStyle(ink.opacity(0.6))
                    .annotation(position: .top, alignment: .trailing, spacing: 2) {
                        if !compact {
                            Text("Avg \(WeightFormat.number(average))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
            }

            if let highlighted {
                RuleMark(x: .value("Selected", highlighted.date))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(spacing: 0) {
                            Text(WeightFormat.kg(highlighted.kg)).font(.caption.bold())
                            if isEdge(highlighted) {
                                Text("Estimated").font(.caption2).foregroundStyle(.secondary)
                            }
                            Text(highlighted.date, format: .dateTime.day().month(.abbreviated).year(.twoDigits))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.regularMaterial, in: .rect(cornerRadius: 6))
                    }
                PointMark(x: .value("Date", highlighted.date), y: .value("Weight", highlighted.kg))
                    .symbolSize(70)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: yDomain)
        .chartXAxis(compact ? .hidden : .automatic)
        .chartYAxis {
            if compact {
                // Labels sit level with their gridline on the left: "88 kg ------".
                AxisMarks(position: .leading, values: gridValues) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                        .foregroundStyle(ink.opacity(0.2))
                    AxisValueLabel {
                        if let kg = value.as(Double.self) {
                            Text("\(kg.formatted(.number.precision(.fractionLength(0)))) kg")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(ink)
                        }
                    }
                }
                // The goal's label goes in the same column; its line is the dashed RuleMark.
                AxisMarks(position: .leading, values: target.map { [$0] } ?? []) { value in
                    AxisValueLabel {
                        if let kg = value.as(Double.self) {
                            Text("\(kg.formatted(.number.precision(.fractionLength(0...1)))) kg")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.green)
                        }
                    }
                }
            } else {
                AxisMarks(position: .trailing)
            }
        }
    }

    private static let startID = UUID()
    private static let endID = UUID()

    private func isEdge(_ point: WeightSample) -> Bool {
        point.id == Self.startID || point.id == Self.endID
    }

    private var highlighted: WeightSample? {
        guard let selectedDate else { return nil }
        return linePoints.min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }

    private var linePoints: [WeightSample] {
        var line = plotted
        let domain = xDomain
        if let startKg, line.first?.date != domain.lowerBound {
            line.insert(WeightSample(id: Self.startID, date: domain.lowerBound, kg: startKg, isFromThisApp: false), at: 0)
        }
        if let endKg, line.last?.date != domain.upperBound {
            line.append(WeightSample(id: Self.endID, date: domain.upperBound, kg: endKg, isFromThisApp: false))
        }
        return line
    }

    /// `points` with a reading on the first or last day (or chart bucket) moved onto the chart's edge,
    /// so the line starts and ends flush instead of a few hours in.
    private var plotted: [WeightSample] {
        var plotted = points
        let domain = xDomain
        if let first = plotted.first, isSamePlot(first.date, domain.lowerBound) {
            plotted[0].date = domain.lowerBound
        }
        if let last = plotted.last, isSamePlot(last.date, domain.upperBound) {
            plotted[plotted.count - 1].date = domain.upperBound
        }
        return plotted
    }

    private func isSamePlot(_ date: Date, _ edge: Date) -> Bool {
        Calendar.current.isDate(date, equalTo: edge, toGranularity: range.chartBucket ?? .day)
    }

    private var xDomain: ClosedRange<Date> {
        let start = range.startDate(now: now) ?? points.first?.date ?? now.addingTimeInterval(-86_400 * 7)
        return start...max(range.chartEnd(now: now), start.addingTimeInterval(3600))
    }

    /// A gridline every whole kg. None where the goal line already sits.
    private var gridValues: [Double] {
        Array(stride(from: yDomain.lowerBound.rounded(.up), through: yDomain.upperBound, by: 1))
            .filter { $0 != target }
    }

    private var yDomain: ClosedRange<Double> {
        var values = linePoints.map(\.kg)
        if let target { values.append(target) }
        if let average, !linePoints.isEmpty { values.append(average) }
        guard let low = values.min(), let high = values.max() else { return 0...100 }
        guard compact else {
            let padding = max((high - low) * 0.1, 0.5)
            return (low - padding)...(high + padding)
        }
        // The widget has a gridline per kg: the goal is the bottom line (unless readings dip
        // below it) and the top edge is the next whole kg above the highest reading.
        let lowestReading = linePoints.map(\.kg).min() ?? low
        let bottom = target.map { min($0, lowestReading.rounded(.down)) } ?? lowestReading.rounded(.down)
        return bottom...(high.rounded(.down) + 1)
    }
}
