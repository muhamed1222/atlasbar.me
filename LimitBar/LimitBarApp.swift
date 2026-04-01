import SwiftUI

@main
struct LimitBarApp: App {
    @StateObject private var appModel = AppModel()

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
