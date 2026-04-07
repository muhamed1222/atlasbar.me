import SwiftUI

func accountsSectionMaxHeight(for accountCount: Int) -> CGFloat {
    let visibleRows = min(max(accountCount, 1), 3)
    // Conservative max that covers header + summary + full metrics + note
    let estimatedRowHeight: CGFloat = 140
    let estimatedSpacing: CGFloat = 4
    return (CGFloat(visibleRows) * estimatedRowHeight) + (CGFloat(max(visibleRows - 1, 0)) * estimatedSpacing)
}

struct MenuBarRootView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var accountPendingDeletion: Account?
    @State private var isShowingDeleteConfirmation = false

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
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(strings.delete, role: .destructive) {
                guard let accountPendingDeletion else { return }
                appModel.deleteAccount(accountPendingDeletion)
                self.accountPendingDeletion = nil
                isShowingDeleteConfirmation = false
            }
            Button(strings.cancel, role: .cancel) {
                accountPendingDeletion = nil
                isShowingDeleteConfirmation = false
            }
        } message: {
            Text(accountPendingDeletion?.displayName ?? strings.account)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                LimitBarLogoView(size: .compact)
                Text("Limit Bar")
                    .font(.system(size: 13, weight: .semibold))
                if let lastRefreshAt = appModel.lastRefreshAt {
                    Text("· \(localizedRelativeDate(lastRefreshAt, language: appModel.resolvedLanguage))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                headerSettingsButton
            }
            if let persistenceErrorMessage = appModel.persistenceErrorMessage, !persistenceErrorMessage.isEmpty {
                Text(persistenceErrorMessage)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let switchErrorMessage = appModel.switchErrorMessage, !switchErrorMessage.isEmpty {
                Text(switchErrorMessage)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 7)
    }

    private var headerSettingsButton: some View {
        SettingsLink {
            Image(systemName: "gearshape")
                .font(.system(size: 12.5, weight: .medium))
                .frame(width: 28, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(HeaderIconButtonStyle())
        .help(appModel.strings.settings)
    }

    // MARK: - Accounts

    private var accountsSection: some View {
        Group {
            if appModel.accounts.isEmpty {
                emptyAccountsView
            } else {
                if appModel.sortedAccounts.count <= 3 {
                    accountsRows
                        .padding(.vertical, 2)
                } else {
                    ScrollView {
                        accountsRows
                            .padding(.vertical, 2)
                    }
                    .frame(height: accountsSectionMaxHeight(for: appModel.sortedAccounts.count))
                }
            }
        }
    }

    private var accountsRows: some View {
        LazyVStack(alignment: .leading, spacing: 6) {
            ForEach(appModel.sortedAccounts) { account in
                let snapshot = appModel.snapshots.last { $0.accountId == account.id }
                let metadata = appModel.metadata(for: account.id)
                AccountRowView(
                    account: account,
                    snapshot: snapshot,
                    metadata: metadata,
                    isActive: appModel.isActiveAccount(account),
                    canSwitch: appModel.canSwitch(to: account),
                    onDelete: {
                        accountPendingDeletion = account
                        isShowingDeleteConfirmation = true
                    },
                    onSwitch: { appModel.switchToAccount(account) },
                    language: appModel.resolvedLanguage
                )
                .padding(.horizontal, 8)
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

private struct HeaderIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.1 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
