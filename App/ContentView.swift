import SwiftUI

struct ContentView: View {
    @Environment(WeightModel.self) private var model
    @Binding var showingAdd: Bool
    @AppStorage("selectedRange") private var range: WeightRange = .month
    @State private var showingSettings = false
    @State private var selectedDate: Date?
    @State private var windowOffset = 0
    @State private var stepEdge: Edge = .leading

    var body: some View {
        let end = range.windowEnd(offset: windowOffset)
        let startKg = range.startDate(now: end).flatMap { model.samples.interpolatedKg(at: $0) }
        let endKg = model.samples.interpolatedKg(at: end)
        let inRange = model.samples.filtered(to: range, now: end)
        let points = inRange.chartPoints(for: range)

        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        SummaryHeader(range: range, end: end, isCurrent: windowOffset == 0, readings: inRange, points: points, startKg: startKg, endKg: endKg)

                        Picker("Range", selection: $range) {
                            ForEach(WeightRange.allCases) { Text($0.shortTitle).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        // The picker ignores taps on the selected segment, so catch those to jump
                        // back to the current window.
                        .overlay(alignment: .leading) {
                            if windowOffset > 0, let index = WeightRange.allCases.firstIndex(of: range) {
                                GeometryReader { geometry in
                                    let width = geometry.size.width / CGFloat(WeightRange.allCases.count)
                                    Color.clear
                                        .contentShape(.rect)
                                        .frame(width: width)
                                        .offset(x: width * CGFloat(index))
                                        .onTapGesture { step(-windowOffset) }
                                }
                            }
                        }

                        if let start = range.startDate(now: end) {
                            WindowStepper(
                                range: range,
                                offset: windowOffset,
                                start: start,
                                canGoBack: model.samples.first.map { $0.date < start } ?? false,
                                canGoForward: windowOffset > 0,
                                step: step
                            )
                        }

                        ZStack {
                            WeightChart(
                                points: points,
                                target: model.targetKg,
                                average: WeightTrend(samples: model.samples, range: range, now: end).average,
                                range: range,
                                startKg: startKg,
                                endKg: endKg,
                                selectedDate: selectedDate,
                                now: end
                            )
                            .chartXSelection(value: $selectedDate)
                            // Only a quick flick changes window; a slower drag is scrubbing the selection.
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 20).onEnded { value in
                                    guard range.period != nil else { return }
                                    let dx = value.translation.width
                                    guard abs(dx) > 50, abs(dx) > abs(value.translation.height) * 1.5,
                                          abs(value.velocity.width) > 400 else { return }
                                    selectedDate = nil
                                    step(dx > 0 ? 1 : -1)
                                }
                            )
                            .overlay {
                                if points.isEmpty && startKg == nil && endKg == nil {
                                    ContentUnavailableView("No readings", systemImage: "scalemass", description: Text("Nothing in Health for this range."))
                                }
                            }
                            // A fresh identity per window makes the chart slide like a page instead of
                            // morphing each dot from its old position to its new one.
                            .id(windowOffset)
                            .transition(.push(from: stepEdge))
                        }
                        .frame(height: 260)
                        // Clip the sideways slide but leave room above for the selection label.
                        .mask { Rectangle().padding(.vertical, -80) }
                    }
                    .padding(.vertical, 8)
                }

                if !inRange.isEmpty {
                    Section("Readings") {
                        ForEach(inRange.reversed()) { sample in
                            ReadingRow(sample: sample)
                                .deleteDisabled(!sample.isFromThisApp)
                        }
                        .onDelete { offsets in
                            let reversed = Array(inRange.reversed())
                            for index in offsets {
                                Task { await model.delete(reversed[index]) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Weight")
            .onChange(of: range) { windowOffset = 0 }
            .refreshable { await model.reload() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gearshape") { showingSettings = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Weight", systemImage: "plus") { showingAdd = true }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddWeightSheet(initialKg: model.latest?.kg)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .alert("Something went wrong", isPresented: .constant(model.errorMessage != nil)) {
                Button("OK") { model.errorMessage = nil }
            } message: {
                Text(model.errorMessage ?? "")
            }
        }
    }

    /// Positive steps go back in time.
    private func step(_ windows: Int) {
        let target = windowOffset + windows
        guard target >= 0 else { return }
        if windows > 0 {
            guard let first = model.samples.first, let start = range.startDate(now: range.windowEnd(offset: windowOffset)),
                  first.date < start else { return }
        }
        stepEdge = windows > 0 ? .leading : .trailing
        withAnimation(.snappy) { windowOffset = target }
    }
}

private struct SummaryHeader: View {
    @Environment(WeightModel.self) private var model
    let range: WeightRange
    let end: Date
    let isCurrent: Bool
    let readings: [WeightSample]
    let points: [WeightSample]
    let startKg: Double?
    let endKg: Double?

    var body: some View {
        let latest = model.latest
        let trend = WeightTrend(samples: model.samples, range: range, now: end)
        let line = WeightChart.line(points: points, range: range, startKg: startKg, endKg: endKg, now: end)

        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Current").font(.caption).foregroundStyle(.secondary)
                Text(latest.map { WeightFormat.kg($0.kg) } ?? "—")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                if let latest {
                    Text(latest.date, format: .relative(presentation: .named))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isCurrent, range == .week {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(trend.average.map { "\(range.title) · avg \(WeightFormat.kg($0))" } ?? range.title)
                        .font(.caption).foregroundStyle(.secondary)
                    if let delta = trend.delta {
                        Text(WeightFormat.delta(delta))
                            .font(.system(.title2, design: .rounded, weight: .semibold))
                            .foregroundStyle(WeightFormat.deltaColor(delta))
                        if let comparison = range.comparisonTitle {
                            Text("avg \(comparison)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if let target = model.targetKg, let average = trend.average {
                        Text("\(WeightFormat.kg(abs(average - target))) to target")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            } else if let average = trend.average {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(range.title) · avg \(WeightFormat.kg(average))")
                        .font(.caption).foregroundStyle(.secondary)
                    if line.count > 1, let first = line.first, let last = line.last {
                        let change = last.kg - first.kg
                        Text(WeightFormat.delta(change))
                            .font(.system(.title2, design: .rounded, weight: .semibold))
                            .foregroundStyle(WeightFormat.deltaColor(change))
                        Text("Change").font(.caption).foregroundStyle(.secondary)
                        if range == .all, let since = readings.first?.date {
                            Text(Self.span(since: since)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if !isCurrent, readings.isEmpty {
                        Text("Estimated").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

extension SummaryHeader {
    static func span(since: Date) -> LocalizedStringKey {
        let span = Calendar.current.dateComponents([.year, .month], from: since, to: .now)
        if let years = span.year, years > 0 {
            return "over ^[\(years) year](inflect: true)"
        }
        return "over ^[\(max(span.month ?? 0, 1)) month](inflect: true)"
    }
}

private struct WindowStepper: View {
    let range: WeightRange
    let offset: Int
    let start: Date
    let canGoBack: Bool
    let canGoForward: Bool
    let step: (Int) -> Void

    var body: some View {
        HStack {
            Button("Earlier", systemImage: "chevron.left") { step(1) }
                .disabled(!canGoBack)
            Spacer()
            Group {
                switch range {
                case .year:
                    Text(start, format: .dateTime.year())
                case .month:
                    Text(start, format: .dateTime.month(.wide).year())
                case .quarter:
                    Text("Q\((Calendar.current.component(.month, from: start) - 1) / 3 + 1) \(start, format: .dateTime.year())")
                case .week where offset == 0:
                    Text("This week")
                case .week where offset == 1:
                    Text("Last week")
                case .week where Calendar.current.isDate(start, equalTo: .now, toGranularity: .year):
                    Text("Week of \(start, format: .dateTime.day().month(.abbreviated))")
                default:
                    Text("Week of \(start, format: .dateTime.day().month(.abbreviated).year())")
                }
            }
            .font(.subheadline.weight(.medium))
            .monospacedDigit()
            Spacer()
            Button("Later", systemImage: "chevron.right") { step(-1) }
                .disabled(!canGoForward)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
    }
}

private struct ReadingRow: View {
    let sample: WeightSample

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(sample.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
                Text(sample.date, format: .dateTime.hour().minute())
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(WeightFormat.kg(sample.kg))
                .font(.system(.body, design: .rounded, weight: .medium))
                .monospacedDigit()
        }
    }
}
