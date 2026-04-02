import Foundation

struct RenewalReminderSettings: Codable, Equatable {
    var days7Enabled: Bool
    var days3Enabled: Bool
    var days1Enabled: Bool
    var sameDayEnabled: Bool

    static let `default` = RenewalReminderSettings(
        days7Enabled: true,
        days3Enabled: true,
        days1Enabled: true,
        sameDayEnabled: true
    )
}

struct AppSettingsState: Codable, Equatable {
    var pollingWhenRunning: Double?
    var pollingWhenClosed: Double?
    var cooldownNotificationsEnabled: Bool
    var renewalReminders: RenewalReminderSettings

    static let `default` = AppSettingsState(
        pollingWhenRunning: nil,
        pollingWhenClosed: nil,
        cooldownNotificationsEnabled: true,
        renewalReminders: .default
    )
}
