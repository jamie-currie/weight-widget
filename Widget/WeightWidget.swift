import SwiftUI
import WidgetKit

struct WeightEntry: TimelineEntry {
    let date: Date
    let range: WeightRange
    let samples: [WeightSample]
    let target: Double?

    var inRange: [WeightSample] { samples.filtered(to: range, now: date) }
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WeightEntry {
        .preview(range: .month)
    }

    func snapshot(for configuration: RangeIntent, in context: Context) async -> WeightEntry {
        context.isPreview ? .preview(range: configuration.range) : await entry(for: configuration.range)
    }

    func timeline(for configuration: RangeIntent, in context: Context) async -> Timeline<WeightEntry> {
        let entry = await entry(for: configuration.range)
        // The window slides with the date, so redraw just after midnight. The app also
        // reloads the widget whenever a reading is added or Health changes.
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))!
        return Timeline(entries: [entry], policy: .after(tomorrow.addingTimeInterval(60)))
    }

    private func entry(for range: WeightRange) async -> WeightEntry {
        WeightEntry(date: .now, range: range, samples: await loadSamples(), target: TargetWeight.kg)
    }

    /// Health first; it can't be read while the phone is locked, so fall back to the app's cache.
    /// An empty result is real (readings deleted or access turned off), not a reason to fall back.
    private func loadSamples() async -> [WeightSample] {
        do {
            return try await HealthStore.shared.fetch()
        } catch {
            return SampleCache.load()
        }
    }
}

struct WeightWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: AppConfig.widgetKind, intent: RangeIntent.self, provider: Provider()) { entry in
            WeightWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Weight")
        .description("Your weight trend from Apple Health.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WeightWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WeightEntry

    var body: some View {
        let inRange = entry.inRange
        let latest = entry.samples.last
        let trend = WeightTrend(samples: entry.samples, range: entry.range, now: entry.date)
        let chart = WeightChart(
            points: inRange.chartPoints(for: entry.range),
            target: entry.target,
            average: trend.average,
            range: entry.range,
            startKg: WeightChart.start(samples: entry.samples, range: entry.range, now: entry.date)?.kg,
            compact: true,
            now: entry.date
        )

        if latest == nil {
            VStack(spacing: 6) {
                Image(systemName: "scalemass").font(.title2)
                Text("No readings").font(.headline)
                Text("Open the app to add your weight").font(.caption).foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        } else {
            switch family {
            case .systemMedium:
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        RangeLabel(range: entry.range, average: trend.average)
                        WeightValue(latest: latest)
                        if let delta = trend.delta {
                            DeltaText(delta: delta)
                            if let comparison = entry.range.comparisonTitle {
                                Text(comparison)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                        if let target = entry.target, let average = trend.average {
                            Text("\(WeightFormat.kg(abs(average - target))) to go")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    // A bit of extra room above and below the graph on top of the widget's margin.
                    chart.padding(.vertical, 8)
                }
            default:
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        WeightValue(latest: latest)
                        Spacer(minLength: 0)
                    }
                    HStack {
                        if let delta = trend.delta {
                            DeltaText(delta: delta)
                        }
                        Spacer(minLength: 0)
                        if trend.delta != nil, let comparison = entry.range.comparisonTitle {
                            Text(comparison.uppercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        } else {
                            RangeLabel(range: entry.range)
                        }
                    }
                    chart.padding(.top, 4)
                }
            }
        }
    }
}

private struct RangeLabel: View {
    let range: WeightRange
    var average: Double?
    var body: some View {
        Text(average.map { "\(range.title.uppercased()) AVG \(WeightFormat.number($0))" } ?? range.title.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

private struct WeightValue: View {
    let latest: WeightSample?
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(latest.map { WeightFormat.number($0.kg) } ?? "—")
                .font(.system(.title, design: .rounded, weight: .bold))
            Text("kg").font(.caption).foregroundStyle(.secondary)
        }
        .minimumScaleFactor(0.6)
        .lineLimit(1)
    }
}

private struct DeltaText: View {
    let delta: Double
    var body: some View {
        Text(WeightFormat.delta(delta))
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(WeightFormat.deltaColor(delta))
    }
}

extension WeightEntry {
    static func preview(range: WeightRange) -> WeightEntry {
        let now = Date.now
        let samples = (0..<200).reversed().map { daysAgo in
            WeightSample(
                id: UUID(),
                date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!,
                kg: 84 - Double(200 - daysAgo) * 0.02 + sin(Double(daysAgo)) * 0.3,
                isFromThisApp: false
            )
        }
        return WeightEntry(date: now, range: range, samples: samples, target: 78)
    }
}

#Preview(as: .systemSmall) {
    WeightWidget()
} timeline: {
    WeightEntry.preview(range: .month)
}

#Preview(as: .systemMedium) {
    WeightWidget()
} timeline: {
    WeightEntry.preview(range: .quarter)
}
