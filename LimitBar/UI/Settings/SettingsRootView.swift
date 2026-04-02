import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case notifications
    case accounts

    var id: String { rawValue }

    func title(language: ResolvedAppLanguage) -> String {
        let strings = AppStrings(language: language)
        switch self {
        case .general:
            return strings.general
        case .notifications:
            return strings.notifications
        case .accounts:
            return strings.accounts
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            return "slider.horizontal.3"
        case .notifications:
            return "bell.badge"
        case .accounts:
            return "person.2"
        }
    }
}

struct SettingsRootView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var selection: SettingsSection? = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(section.title(language: appModel.resolvedLanguage), systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .listStyle(.sidebar)
        } detail: {
            Group {
                switch selection ?? .general {
                case .general:
                    GeneralSettingsView()
                case .notifications:
                    NotificationSettingsView()
                case .accounts:
                    AccountsSettingsView()
                }
            }
            .environmentObject(appModel)
        }
        .frame(minWidth: 760, minHeight: 460)
    }
}
