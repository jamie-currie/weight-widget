import SwiftUI

struct ContentView: View {
    @Environment(WeightModel.self) private var model
    @Binding var showingAdd: Bool
    @AppStorage("selectedRange") private var range: WeightRange = .month
    @State private var showingSettings = false
    @State private var selectedDate: Date?

    var body: some View {
        let inRange = model.samples.filtered(to: range)
        let points = inRange.chartPoints(for: range)

        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        SummaryHeader(inRange: inRange, range: range)

                        Picker("Range", selection: $range) {
                            ForEach(WeightRange.allCases) { Text($0.shortTitle).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        WeightChart(
                            points: points,
                            target: model.targetKg,
                            range: range,
                            highlighted: nearest(to: selectedDate, in: points)
                        )
                        .chartXSelection(value: $selectedDate)
                        .frame(height: 260)
                        .overlay {
                            if points.isEmpty {
                                ContentUnavailableView("No readings", systemImage: "scalemass", description: Text("Nothing in Health for this range."))
                            }
                        }
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

    private func nearest(to date: Date?, in points: [WeightSample]) -> WeightSample? {
        guard let date else { return nil }
        return points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }
}

private struct SummaryHeader: View {
    @Environment(WeightModel.self) private var model
    let inRange: [WeightSample]
    let range: WeightRange

    var body: some View {
        let latest = model.latest
        let delta = inRange.delta

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
            VStack(alignment: .trailing, spacing: 2) {
                Text(range.title).font(.caption).foregroundStyle(.secondary)
                Text(delta.map(WeightFormat.delta) ?? "—")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .foregroundStyle(WeightFormat.deltaColor(delta, current: latest?.kg, target: model.targetKg))
                if let target = model.targetKg, let latest {
                    Text("\(WeightFormat.kg(abs(latest.kg - target))) to target")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
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
