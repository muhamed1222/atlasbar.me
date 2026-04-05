import SwiftUI

@main
struct LimitBarApp: App {
    private let notificationManager: NotificationManager
    @StateObject private var appModel: AppModel

    init() {
        let notificationManager = NotificationManager()
        let claudeCookieStore = ClaudeSessionCookieStore()
        let claudeWebSessionController = ClaudeWebSessionController()
        let claudeUsagePipeline = ClaudeUsagePipeline(
            webProvider: ClaudeWebViewUsageProvider(
                sessionController: claudeWebSessionController,
                fallbackWebProvider: ClaudeWebUsageProvider(cookieStore: claudeCookieStore)
            ),
            webSessionController: claudeWebSessionController
        )
        self.notificationManager = notificationManager
        _appModel = StateObject(
            wrappedValue: AppModel(
                notificationManager: notificationManager,
                claudeUsagePipeline: claudeUsagePipeline,
                claudeSessionCookieStore: claudeCookieStore,
                claudeWebSessionController: claudeWebSessionController
            )
        )

        Task {
            _ = await notificationManager.requestAuthorization()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarRootView()
                .environmentObject(appModel)
                .environment(\.locale, appModel.appLocale)
        } label: {
            CompactStatusView()
                .environmentObject(appModel)
                .environment(\.locale, appModel.appLocale)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsRootView()
                .environmentObject(appModel)
                .environment(\.locale, appModel.appLocale)
        }
    }
}
