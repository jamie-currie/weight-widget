import SwiftUI

/// Opens with the keypad up and the last weight filled in, so logging is one edit and Save.
struct AddWeightSheet: View {
    @Environment(WeightModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var date = Date.now
    @State private var saving = false
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    init(initialKg: Double?) {
        _text = State(initialValue: initialKg.map(WeightFormat.number) ?? "")
    }

    private var kg: Double? {
        let normalised = text.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalised), value > 0, value < 500 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        StepButton(systemImage: "minus") { nudge(by: -0.1) }
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            TextField("0.0", text: $text)
                                .keyboardType(.decimalPad)
                                .focused($focused)
                                .multilineTextAlignment(.trailing)
                                .font(.system(size: 52, weight: .bold, design: .rounded))
                                .fixedSize()
                            Text("kg").font(.title2).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        StepButton(systemImage: "plus") { nudge(by: 0.1) }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    DatePicker("Date", selection: $date, in: ...Date.now)
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("Add Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(kg == nil || saving)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private func nudge(by amount: Double) {
        let current = kg ?? model.latest?.kg ?? 0
        text = WeightFormat.number(max(0, current + amount))
    }

    private func save() {
        guard let kg else { return }
        saving = true
        Task {
            do {
                try await model.add(kg: kg, date: date)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                saving = false
            }
        }
    }
}

private struct StepButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.bold())
                .frame(width: 44, height: 44)
        }
        .buttonStyle(StepButtonStyle())
    }
}

/// `.bordered`'s fill renders black while the sheet animates in, so draw a plain fill instead.
private struct StepButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.tint)
            .background(Color(.tertiarySystemFill), in: .circle)
            .opacity(configuration.isPressed ? 0.5 : 1)
            .contentShape(.circle)
    }
}
