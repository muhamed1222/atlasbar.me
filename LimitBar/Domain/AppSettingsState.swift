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
    var language: AppLanguage

    init(
        pollingWhenRunning: Double?,
        pollingWhenClosed: Double?,
        cooldownNotificationsEnabled: Bool,
        renewalReminders: RenewalReminderSettings,
        language: AppLanguage = .system
    ) {
        self.pollingWhenRunning = pollingWhenRunning
        self.pollingWhenClosed = pollingWhenClosed
        self.cooldownNotificationsEnabled = cooldownNotificationsEnabled
        self.renewalReminders = renewalReminders
        self.language = language
    }

    static let `default` = AppSettingsState(
        pollingWhenRunning: nil,
        pollingWhenClosed: nil,
        cooldownNotificationsEnabled: true,
        renewalReminders: .default,
        language: .system
    )
}

extension AppSettingsState {
    enum CodingKeys: String, CodingKey {
        case pollingWhenRunning
        case pollingWhenClosed
        case cooldownNotificationsEnabled
        case renewalReminders
        case language
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pollingWhenRunning = try container.decodeIfPresent(Double.self, forKey: .pollingWhenRunning)
        pollingWhenClosed = try container.decodeIfPresent(Double.self, forKey: .pollingWhenClosed)
        cooldownNotificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .cooldownNotificationsEnabled) ?? true
        renewalReminders = try container.decodeIfPresent(RenewalReminderSettings.self, forKey: .renewalReminders) ?? .default
        language = try container.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .system
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(pollingWhenRunning, forKey: .pollingWhenRunning)
        try container.encodeIfPresent(pollingWhenClosed, forKey: .pollingWhenClosed)
        try container.encode(cooldownNotificationsEnabled, forKey: .cooldownNotificationsEnabled)
        try container.encode(renewalReminders, forKey: .renewalReminders)
        try container.encode(language, forKey: .language)
    }
}
