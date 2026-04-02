import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        let strings = appModel.strings

        Form {
            Section(strings.cooldown) {
                Toggle(
                    strings.cooldownReadyNotifications,
                    isOn: Binding(
                        get: { appModel.settings.cooldownNotificationsEnabled },
                        set: { appModel.setCooldownNotificationsEnabled($0) }
                    )
                )
            }

            Section {
                reminderToggle(strings.days(7), keyPath: \.days7Enabled)
                reminderToggle(strings.days(3), keyPath: \.days3Enabled)
                reminderToggle(strings.oneDay, keyPath: \.days1Enabled)
                reminderToggle(strings.sameDay, keyPath: \.sameDayEnabled)
            } header: {
                Text(strings.renewalReminders)
            } footer: {
                Text(strings.renewalRemindersFooter)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(strings.notifications)
    }

    private func reminderToggle(
        _ title: String,
        keyPath: WritableKeyPath<RenewalReminderSettings, Bool>
    ) -> some View {
        Toggle(
            title,
            isOn: Binding(
                get: { appModel.settings.renewalReminders[keyPath: keyPath] },
                set: { appModel.setRenewalReminderEnabled($0, keyPath: keyPath) }
            )
        )
    }
}
