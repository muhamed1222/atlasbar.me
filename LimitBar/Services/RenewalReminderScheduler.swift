import Foundation

struct RenewalReminderRequest: Equatable {
    var identifier: String
    var fireDate: Date
    var title: String
    var body: String
}

protocol RenewalNotificationScheduling: Sendable {
    func scheduleRenewalReminder(identifier: String, accountName: String, at date: Date)
    func cancelNotifications(withIdentifiers identifiers: [String])
}

struct RenewalReminderScheduler {
    private enum ReminderOffset: CaseIterable {
        case days7
        case days3
        case days1
        case sameDay

        var identifierSuffix: String {
            switch self {
            case .days7:
                return "7d"
            case .days3:
                return "3d"
            case .days1:
                return "1d"
            case .sameDay:
                return "0d"
            }
        }

        var timeInterval: TimeInterval {
            switch self {
            case .days7:
                return 7 * 24 * 60 * 60
            case .days3:
                return 3 * 24 * 60 * 60
            case .days1:
                return 24 * 60 * 60
            case .sameDay:
                return 0
            }
        }

        var settingsKeyPath: KeyPath<RenewalReminderSettings, Bool> {
            switch self {
            case .days7:
                return \.days7Enabled
            case .days3:
                return \.days3Enabled
            case .days1:
                return \.days1Enabled
            case .sameDay:
                return \.sameDayEnabled
            }
        }
    }

    func reconcile(
        account: Account,
        snapshot: UsageSnapshot?,
        settings: AppSettingsState,
        notificationManager: RenewalNotificationScheduling,
        now: Date = .now
    ) {
        let identifiers = reminderIdentifiers(for: account.id)
        notificationManager.cancelNotifications(withIdentifiers: identifiers)

        for request in desiredRequests(account: account, snapshot: snapshot, settings: settings, now: now) {
            notificationManager.scheduleRenewalReminder(
                identifier: request.identifier,
                accountName: account.displayName,
                at: request.fireDate
            )
        }
    }

    func desiredRequests(
        account: Account,
        snapshot: UsageSnapshot?,
        settings: AppSettingsState,
        now: Date = .now
    ) -> [RenewalReminderRequest] {
        guard let expiryDate = snapshot?.subscriptionExpiresAt else {
            return []
        }

        let derivedState = SubscriptionDerivedState.from(expiryDate: expiryDate, now: now)
        guard derivedState != .expired, derivedState != .unknown else {
            return []
        }

        return ReminderOffset.allCases.compactMap { offset in
            guard settings.renewalReminders[keyPath: offset.settingsKeyPath] else {
                return nil
            }

            let fireDate = expiryDate.addingTimeInterval(-offset.timeInterval)
            guard fireDate > now else {
                return nil
            }

            return RenewalReminderRequest(
                identifier: "renewal-\(account.id.uuidString)-\(offset.identifierSuffix)",
                fireDate: fireDate,
                title: "Subscription renewal reminder",
                body: "\(account.displayName) expires \(expiryDate.formatted(.dateTime.month(.abbreviated).day()))"
            )
        }
        .sorted { $0.fireDate < $1.fireDate }
    }

    func reminderIdentifiers(for accountId: UUID) -> [String] {
        ReminderOffset.allCases.map { "renewal-\(accountId.uuidString)-\($0.identifierSuffix)" }
    }
}
