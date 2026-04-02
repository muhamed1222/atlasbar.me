import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Form {
            Section("Polling") {
                Stepper(
                    value: runningIntervalBinding,
                    in: 5...60,
                    step: 5
                ) {
                    settingRow(
                        title: "While Codex is running",
                        value: "\(Int(runningIntervalBinding.wrappedValue)) seconds"
                    )
                }

                Stepper(
                    value: closedIntervalBinding,
                    in: 30...300,
                    step: 15
                ) {
                    settingRow(
                        title: "While Codex is closed",
                        value: "\(Int(closedIntervalBinding.wrappedValue)) seconds"
                    )
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }

    private var runningIntervalBinding: Binding<Double> {
        Binding(
            get: { appModel.settings.pollingWhenRunning ?? 15 },
            set: { appModel.updatePollingInterval($0, codexRunning: true) }
        )
    }

    private var closedIntervalBinding: Binding<Double> {
        Binding(
            get: { appModel.settings.pollingWhenClosed ?? 60 },
            set: { appModel.updatePollingInterval($0, codexRunning: false) }
        )
    }

    private func settingRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
