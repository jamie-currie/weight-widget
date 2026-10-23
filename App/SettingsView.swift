import SwiftUI

struct SettingsView: View {
    @Environment(WeightModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var targetText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Target weight")
                        Spacer()
                        TextField("None", text: $targetText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("kg").foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Shown as a dashed line on the graph and the widget. Leave empty to hide it.")
                }

                Section {
                    Link("Manage Health Access", destination: URL(string: "x-apple-health://")!)
                } footer: {
                    Text("All readings are stored in Apple Health. You can only delete readings that were added by this app; others can be removed in the Health app.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                targetText = model.targetKg.map(WeightFormat.number) ?? ""
            }
            .onDisappear { saveTarget() }
        }
    }

    /// Runs however the sheet closes, so swiping it away keeps what was typed too.
    private func saveTarget() {
        let newTarget = WeightFormat.parse(targetText).flatMap { $0 > 0 ? $0 : nil }
        if newTarget != model.targetKg { model.targetKg = newTarget }
    }
}
