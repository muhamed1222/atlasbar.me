import Foundation

struct SettingsCoordinator {
    let runningRange: ClosedRange<Double> = 5...60
    let closedRange: ClosedRange<Double> = 30...300
    let defaultRunningInterval: Double = 15
    let defaultClosedInterval: Double = 60

    func sanitized(_ settings: AppSettingsState) -> AppSettingsState {
        AppSettingsState(
            pollingWhenRunning: sanitize(settings.pollingWhenRunning, in: runningRange),
            pollingWhenClosed: sanitize(settings.pollingWhenClosed, in: closedRange),
            cooldownNotificationsEnabled: settings.cooldownNotificationsEnabled,
            renewalReminders: settings.renewalReminders
        )
    }

    func pollingInterval(codexRunning: Bool, settings: AppSettingsState) -> TimeInterval {
        let sanitizedSettings = sanitized(settings)
        if codexRunning {
            return sanitizedSettings.pollingWhenRunning ?? defaultRunningInterval
        }
        return sanitizedSettings.pollingWhenClosed ?? defaultClosedInterval
    }

    private func sanitize(_ value: Double?, in range: ClosedRange<Double>) -> Double? {
        guard let value, value > 0 else {
            return nil
        }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}
