import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        let strings = appModel.strings

        Form {
            Section {
                Toggle(
                    strings.cooldownReadyNotifications,
                    isOn: Binding(
                        get: { appModel.settings.cooldownNotificationsEnabled },
                        set: { appModel.setCooldownNotificationsEnabled($0) }
                    )
                )
            } header: {
                Text(strings.cooldown)
            } footer: {
                Text(strings.cooldownFooter)
            }

            Section {
                if !appModel.snapshots.contains(where: { $0.subscriptionExpiresAt != nil }) {
                    Text(strings.noSubscriptionsNote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                reminderToggle(strings.days(7), keyPath: \.days7Enabled)
                reminderToggle(strings.days(3), keyPath: \.days3Enabled)
                reminderToggle(strings.oneDay, keyPath: \.days1Enabled)
                reminderToggle(strings.sameDay, keyPath: \.sameDayEnabled)
            } header: {
                Text(strings.renewalReminders)
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(strings.renewalRemindersFooter)
                    Text(strings.sameDayFooterNote)
                        .foregroundStyle(.secondary)
                }
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
