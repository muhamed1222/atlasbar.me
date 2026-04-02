import Testing
@testable import LimitBar

struct SettingsCoordinatorTests {
    @Test
    func sanitizedClampsPollingValuesAndPreservesToggles() {
        let coordinator = SettingsCoordinator()
        let settings = AppSettingsState(
            pollingWhenRunning: 1,
            pollingWhenClosed: 999,
            cooldownNotificationsEnabled: false,
            renewalReminders: RenewalReminderSettings(
                days7Enabled: false,
                days3Enabled: true,
                days1Enabled: false,
                sameDayEnabled: true
            ),
            language: .russian
        )

        let sanitized = coordinator.sanitized(settings)
        #expect(sanitized.pollingWhenRunning == 5)
        #expect(sanitized.pollingWhenClosed == 300)
        #expect(sanitized.cooldownNotificationsEnabled == false)
        #expect(sanitized.renewalReminders.days7Enabled == false)
        #expect(sanitized.renewalReminders.sameDayEnabled == true)
        #expect(sanitized.language == .russian)
    }

    @Test
    func sanitizedDropsNonPositivePollingValuesToUseDefaults() {
        let coordinator = SettingsCoordinator()
        let settings = AppSettingsState(
            pollingWhenRunning: 0,
            pollingWhenClosed: -10,
            cooldownNotificationsEnabled: true,
            renewalReminders: .default
        )

        let sanitized = coordinator.sanitized(settings)
        #expect(sanitized.pollingWhenRunning == nil)
        #expect(sanitized.pollingWhenClosed == nil)
    }
}
