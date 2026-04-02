import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        let strings = appModel.strings

        Form {
            Section(strings.polling) {
                Stepper(
                    value: runningIntervalBinding,
                    in: 5...60,
                    step: 5
                ) {
                    settingRow(
                        title: strings.whileCodexRunning,
                        value: strings.seconds(Int(runningIntervalBinding.wrappedValue))
                    )
                }

                Stepper(
                    value: closedIntervalBinding,
                    in: 30...300,
                    step: 15
                ) {
                    settingRow(
                        title: strings.whileCodexClosed,
                        value: strings.seconds(Int(closedIntervalBinding.wrappedValue))
                    )
                }
            }

            Section(strings.languageTitle) {
                Picker(
                    strings.appLanguage,
                    selection: Binding(
                        get: { appModel.settings.language },
                        set: { appModel.setLanguage($0) }
                    )
                ) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayLabel(language: appModel.resolvedLanguage)).tag(language)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(strings.general)
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
