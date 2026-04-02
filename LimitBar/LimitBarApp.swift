import SwiftUI

@main
struct LimitBarApp: App {
    private let notificationManager: NotificationManager
    @StateObject private var appModel: AppModel

    init() {
        let notificationManager = NotificationManager()
        self.notificationManager = notificationManager
        _appModel = StateObject(
            wrappedValue: AppModel(notificationManager: notificationManager)
        )

        Task {
            _ = await notificationManager.requestAuthorization()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarRootView()
                .environmentObject(appModel)
        } label: {
            CompactStatusView()
                .environmentObject(appModel)
        }
        .menuBarExtraStyle(.window)
    }
}
