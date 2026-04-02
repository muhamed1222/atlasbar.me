import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Form {
            Section("Cooldown") {
                Toggle(
                    "Cooldown ready notifications",
                    isOn: Binding(
                        get: { appModel.settings.cooldownNotificationsEnabled },
                        set: { appModel.setCooldownNotificationsEnabled($0) }
                    )
                )
            }

            Section {
                reminderToggle("7 days", keyPath: \.days7Enabled)
                reminderToggle("3 days", keyPath: \.days3Enabled)
                reminderToggle("1 day", keyPath: \.days1Enabled)
                reminderToggle("Same day", keyPath: \.sameDayEnabled)
            } header: {
                Text("Renewal reminders")
            } footer: {
                Text("Renewal reminders are scheduled automatically from the latest subscription expiry and update when these toggles change.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Notifications")
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
