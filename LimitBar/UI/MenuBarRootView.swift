import SwiftUI

struct MenuBarRootView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var accountPendingDeletion: Account?

    var body: some View {
        let strings = appModel.strings

        VStack(alignment: .leading, spacing: 0) {
            headerSection
            sectionDivider
            accountsSection
            sectionDivider
            actionsSection
        }
        .frame(width: 392)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.97))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .confirmationDialog(
            strings.deleteAccountTitle,
            isPresented: Binding(
                get: { accountPendingDeletion != nil },
                set: { if !$0 { accountPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(strings.delete, role: .destructive) {
                guard let accountPendingDeletion else { return }
                appModel.deleteAccount(accountPendingDeletion)
                self.accountPendingDeletion = nil
            }
            Button(strings.cancel, role: .cancel) {
                accountPendingDeletion = nil
            }
        } message: {
            Text(accountPendingDeletion?.displayName ?? strings.account)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                CodexMarkView(size: .compact)
                Text("LimitBar")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                statusIndicator
            }
            if let lastRefreshAt = appModel.lastRefreshAt {
                Text(appModel.strings.updated(localizedRelativeDate(lastRefreshAt, language: appModel.resolvedLanguage)))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 7)
    }

    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(appModel.codexRunning ? Color.green : Color.secondary)
                .frame(width: 6, height: 6)
            Text(appModel.codexRunning ? appModel.strings.codexRunning : appModel.strings.codexNotRunning)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Accounts

    private var accountsSection: some View {
        Group {
            if appModel.accounts.isEmpty {
                emptyAccountsView
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(appModel.sortedAccounts) { account in
                            let snapshot = appModel.snapshots.last { $0.accountId == account.id }
                            let metadata = appModel.metadata(for: account.id)
                            AccountRowView(
                                account: account,
                                snapshot: snapshot,
                                metadata: metadata,
                                onDelete: { accountPendingDeletion = account },
                                language: appModel.resolvedLanguage
                            )
                                .padding(.horizontal, 8)
                            if account.id != appModel.sortedAccounts.last?.id {
                                sectionDivider
                                    .padding(.horizontal, 8)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 236)
            }
        }
    }

    private var emptyAccountsView: some View {
        VStack(spacing: 8) {
            if !appModel.codexRunning {
                Label(appModel.strings.openCodexToStartTracking, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label(appModel.strings.readingUsageData, systemImage: "arrow.clockwise")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(14)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 0) {
            menuActionButton(appModel.strings.refreshNow, systemImage: "arrow.clockwise") {
                appModel.refreshNow()
            }

            menuActionButton(appModel.strings.openCodex, systemImage: "terminal") {
                appModel.openCodex()
            }

            SettingsLink {
                Label(appModel.strings.settings, systemImage: "gearshape")
                    .font(.system(size: 12.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            }
            .buttonStyle(PopupActionButtonStyle())

            sectionDivider
                .padding(.vertical, 2)

            menuActionButton(appModel.strings.quit, systemImage: "power", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func menuActionButton(
        _ title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12.5))
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .buttonStyle(PopupActionButtonStyle())
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.07))
            .frame(height: 0.5)
    }
}

private struct PopupActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PopupActionButtonBody(configuration: configuration)
    }
}

private struct PopupActionButtonBody: View {
    let configuration: PopupActionButtonStyle.Configuration
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(backgroundOpacity))
            )
            .scaleEffect(configuration.isPressed ? 0.988 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.14)) {
                    isHovered = hovering
                }
            }
    }

    private var backgroundOpacity: Double {
        if configuration.isPressed { return 0.1 }
        if isHovered { return 0.055 }
        return 0
    }
}
