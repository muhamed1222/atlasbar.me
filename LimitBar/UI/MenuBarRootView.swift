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
    @Environment(\.colorScheme) private var colorScheme
    @State private var accountPendingDeletion: Account?

    var body: some View {
        let strings = appModel.strings

        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                sectionDivider
                accountsSection
                sectionDivider
                actionsSection
            }
            .allowsHitTesting(accountPendingDeletion == nil)

            if accountPendingDeletion != nil {
                deleteConfirmationOverlay(strings: strings)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .frame(width: 392)
        .padding(6)
        .background(
            ZStack {
                VisualEffectBackdrop(material: colorScheme == .light ? .sidebar : .hudWindow)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(colorScheme == .light ? 0.7 : 0.5))
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .light ? 0.1 : 0.06), lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.16), value: accountPendingDeletion != nil)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                LimitBarLogoView(size: .compact)
                Text("Limit Bar")
                    .font(.system(size: 13.5, weight: .semibold))
                betaBadge
                if let lastRefreshAt = appModel.lastRefreshAt {
                    Text("· \(localizedRelativeDate(lastRefreshAt, language: appModel.resolvedLanguage))")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                headerSettingsButton
            }
            if let persistenceErrorMessage = appModel.persistenceErrorMessage, !persistenceErrorMessage.isEmpty {
                statusBanner(
                    persistenceErrorMessage,
                    systemImage: "exclamationmark.triangle.fill",
                    tone: .red
                )
            }
            if let switchErrorMessage = appModel.switchErrorMessage, !switchErrorMessage.isEmpty {
                statusBanner(
                    switchErrorMessage,
                    systemImage: "arrow.triangle.2.circlepath.circle.fill",
                    tone: .orange
                )
            }
            if let availableUpdate = appModel.availableUpdate {
                updateBanner(availableUpdate)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 7)
    }

    private var betaBadge: some View {
        Text("BETA")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.accentColor.opacity(0.24), lineWidth: 1)
            )
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

    private func statusBanner(
        _ message: String,
        systemImage: String,
        tone: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(tone)
                .frame(width: 16, height: 16)

            Text(message)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(tone.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(tone.opacity(0.14), lineWidth: 1)
        )
    }

    private func updateBanner(_ update: AppUpdateInfo) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.14))
                        .frame(width: 22, height: 22)
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(appModel.strings.updateAvailableTitle)
                        .font(.system(size: 11.5, weight: .semibold))
                    Text(appModel.strings.updateAvailableVersion(update.version))
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    appModel.dismissAvailableUpdate()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(appModel.strings.dismissUpdate)
            }

            if let releaseNotes = update.releaseNotes, !releaseNotes.isEmpty {
                Text(releaseNotes)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button(appModel.strings.downloadUpdate) {
                    appModel.openAvailableUpdate()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.accentColor.opacity(0.13), lineWidth: 1)
        )
    }

    // MARK: - Accounts

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            accountsHeader

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
    }

    private var accountsHeader: some View {
        HStack(spacing: 8) {
            Text(appModel.strings.accounts)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Text("\(appModel.sortedAccounts.count)")
                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(colorScheme == .light ? 0.08 : 0.05))
                )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
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
            Image(systemName: appModel.codexRunning ? "arrow.clockwise.circle" : "tray")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)

            Text(appModel.strings.emptyAccountsTitle)
                .font(.system(size: 12.5, weight: .semibold))

            Text(appModel.codexRunning ? appModel.strings.emptyAccountsReadingHint : appModel.strings.emptyAccountsConnectHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 18)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 0) {
            menuActionButton(appModel.strings.quit, systemImage: "power", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
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
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .buttonStyle(PopupActionButtonStyle())
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(colorScheme == .light ? 0.1 : 0.07))
            .frame(height: 0.5)
    }

    private func deleteConfirmationOverlay(strings: AppStrings) -> some View {
        ZStack {
            Color.black.opacity(colorScheme == .light ? 0.12 : 0.22)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    cancelPendingDeletion()
                }

            VStack(alignment: .leading, spacing: 14) {
                Text(strings.deleteAccountTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(accountPendingDeletion?.displayName ?? strings.account)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                HStack(spacing: 10) {
                    Button(strings.cancel) {
                        cancelPendingDeletion()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .frame(maxWidth: .infinity)

                    Button(strings.delete, role: .destructive) {
                        confirmPendingDeletion()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(width: 336)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(colorScheme == .light ? 0.995 : 0.985))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(colorScheme == .light ? 0.12 : 0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .light ? 0.12 : 0.26), radius: 20, y: 8)
        }
    }

    private func cancelPendingDeletion() {
        accountPendingDeletion = nil
    }

    private func confirmPendingDeletion() {
        guard let accountPendingDeletion else { return }
        appModel.deleteAccount(accountPendingDeletion)
        self.accountPendingDeletion = nil
    }
}

private struct VisualEffectBackdrop: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = material
        view.isEmphasized = false
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.state = .active
    }
}

private struct HeaderIconButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? (colorScheme == .light ? 0.12 : 0.1) : (colorScheme == .light ? 0.07 : 0.05)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(colorScheme == .light ? 0.11 : 0.08), lineWidth: 1)
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
    @Environment(\.colorScheme) private var colorScheme
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
        if isHovered { return colorScheme == .light ? 0.075 : 0.055 }
        return 0
    }
}
