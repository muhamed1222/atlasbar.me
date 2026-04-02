import Foundation

struct PollingCoordinator {
    private let settingsCoordinator = SettingsCoordinator()

    func interval(codexRunning: Bool, settings: AppSettingsState) -> TimeInterval {
        settingsCoordinator.pollingInterval(codexRunning: codexRunning, settings: settings)
    }
}
