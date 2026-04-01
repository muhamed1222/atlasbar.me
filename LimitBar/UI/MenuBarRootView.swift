import SwiftUI

struct MenuBarRootView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var accountPendingDeletion: Account?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider()
            accountsSection
            Divider()
            actionsSection
        }
        .frame(width: 292)
        .confirmationDialog(
            "Delete this account from LimitBar?",
            isPresented: Binding(
                get: { accountPendingDeletion != nil },
                set: { if !$0 { accountPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let accountPendingDeletion else { return }
                appModel.deleteAccount(accountPendingDeletion)
                self.accountPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                accountPendingDeletion = nil
            }
        } message: {
            Text(accountPendingDeletion?.displayName ?? "Account")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: "gauge.medium")
                    .font(.system(size: 14, weight: .semibold))
                Text("LimitBar")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                statusIndicator
            }
            if let lastRefreshAt = appModel.lastRefreshAt {
                Text("Updated \(lastRefreshAt.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(appModel.codexRunning ? Color.green : Color.secondary)
                .frame(width: 6, height: 6)
            Text(appModel.codexRunning ? "Codex running" : "Codex not running")
                .font(.system(size: 11))
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
                        ForEach(appModel.accounts) { account in
                            let snapshot = appModel.snapshots.last { $0.accountId == account.id }
                            AccountRowView(
                                account: account,
                                snapshot: snapshot,
                                onDelete: { accountPendingDeletion = account }
                            )
                                .padding(.horizontal, 10)
                            if account.id != appModel.accounts.last?.id {
                                Divider().padding(.horizontal, 10)
                            }
                        }
                    }
                }
                .frame(maxHeight: 208)
            }
        }
    }

    private var emptyAccountsView: some View {
        VStack(spacing: 8) {
            if !appModel.codexRunning {
                Label("Open Codex to start tracking", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label("Reading usage data…", systemImage: "arrow.clockwise")
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
            menuActionButton("Refresh now", systemImage: "arrow.clockwise") {
                appModel.refreshNow()
            }

            menuActionButton("Open Codex", systemImage: "terminal") {
                appModel.openCodex()
            }

            Divider()

            menuActionButton("Quit", systemImage: "power", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.vertical, 1)
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
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderless)
    }
}
