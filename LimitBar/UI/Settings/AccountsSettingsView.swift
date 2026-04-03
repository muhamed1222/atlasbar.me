import SwiftUI

struct AccountsSettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var selection: UUID?

    var body: some View {
        let strings = appModel.strings

        HSplitView {
            List(appModel.sortedAccounts, selection: $selection) { account in
                accountListRow(account)
                .tag(account.id)
            }
            .frame(minWidth: 240)

            Group {
                if let selectedAccount {
                    accountDetail(selectedAccount)
                } else {
                    ContentUnavailableView(
                        strings.selectAccount,
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text(strings.selectAccountDescription)
                    )
                }
            }
            .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(strings.accounts)
        .onAppear {
            if selection == nil {
                selection = appModel.sortedAccounts.first?.id
            }
        }
        .onChange(of: appModel.sortedAccounts.map(\.id)) { _, ids in
            if let selection, ids.contains(selection) {
                return
            }
            self.selection = ids.first
        }
    }

    private var selectedAccount: Account? {
        guard let selection else {
            return nil
        }
        return appModel.sortedAccounts.first(where: { $0.id == selection })
    }

    @ViewBuilder
    private func accountDetail(_ account: Account) -> some View {
        let strings = appModel.strings
        let metadata = appModel.metadata(for: account.id)
        let snapshot = appModel.snapshot(for: account.id)
        let presentation = makeAccountDetailPresentation(
            account: account,
            snapshot: snapshot,
            metadata: metadata,
            language: appModel.resolvedLanguage
        )

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                accountSummaryCard(account: account, presentation: presentation)

                Form {
                    Section(strings.identity) {
                        ForEach(presentation.identityRows, id: \.title) { row in
                            detailRow(row.title, value: row.value)
                        }

                        if account.provider == "Claude" {
                            HStack {
                                Text(strings.emailLabel)
                                Spacer()
                                TextField(
                                    strings.emailPlaceholder,
                                    text: Binding(
                                        get: { account.email ?? "" },
                                        set: { appModel.updateAccountEmail($0, for: account.id) }
                                    )
                                )
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: 220)
                            }
                        }
                    }

                    Section(strings.priority) {
                        Picker(
                            strings.priority,
                            selection: Binding(
                                get: { appModel.metadata(for: account.id).priority },
                                set: { appModel.updatePriority($0, for: account.id) }
                            )
                        ) {
                            ForEach(AccountPriority.allCases, id: \.self) { priority in
                                Text(priority.displayLabel(language: appModel.resolvedLanguage)).tag(priority)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section(strings.note) {
                        VStack(alignment: .leading, spacing: 8) {
                            TextEditor(
                                text: Binding(
                                    get: { appModel.metadata(for: account.id).note },
                                    set: { appModel.updateNote($0, for: account.id) }
                                )
                            )
                            .font(.body)
                            .frame(minHeight: 140)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(NSColor.textBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                            )

                            HStack {
                                Text(presentation.noteFooter)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(presentation.noteCharacterCount)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .formStyle(.grouped)
            }
        }
        .padding(.top, 8)
    }

    private func detailRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func accountListRow(_ account: Account) -> some View {
        let metadata = appModel.metadata(for: account.id)
        let snapshot = appModel.snapshot(for: account.id)
        let presentation = makeAccountsListRowPresentation(
            account: account,
            snapshot: snapshot,
            metadata: metadata,
            language: appModel.resolvedLanguage
        )

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                ProviderMarkView(provider: account.provider, size: .regular, style: .elevated)
                Text(presentation.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                if let priorityChip = presentation.priorityChip {
                    settingsBadge(priorityChip)
                }
            }

            HStack(spacing: 5) {
                ForEach(Array(presentation.chips.enumerated()), id: \.offset) { _, chip in
                    settingsBadge(chip)
                }
            }

            if let notePreview = presentation.notePreview {
                Text(notePreview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else if let resetAccent = presentation.resetAccent {
                Label(resetAccent.countdownText, systemImage: "timer")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
    }

    private func accountSummaryCard(account: Account, presentation: AccountDetailPresentation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                HStack(alignment: .top, spacing: 10) {
                    ProviderMarkView(provider: account.provider, size: .prominent, style: .elevated)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(presentation.title)
                            .font(.title3.weight(.semibold))
                            .lineLimit(1)
                        Text(presentation.providerLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let priorityChip = presentation.priorityChip {
                    settingsBadge(priorityChip)
                }
            }

            HStack(spacing: 6) {
                ForEach(Array(presentation.summaryChips.enumerated()), id: \.offset) { _, chip in
                    settingsBadge(chip)
                }
            }

            if let resetAccent = presentation.resetAccent {
                nextResetCard(resetAccent)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func nextResetCard(_ accent: ResetAccentPresentation) -> some View {
        let strings = appModel.strings

        return HStack(alignment: .center, spacing: 12) {
            Image(systemName: "timer")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(Color.orange.opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(strings.nextReset)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(accent.countdownText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)

                Text(accent.summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(accent.timeText)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(NSColor.windowBackgroundColor).opacity(0.9))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.orange.opacity(0.18), lineWidth: 1)
                )
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.orange.opacity(0.16), lineWidth: 1)
        )
    }

    private func settingsBadge(_ chip: PresentationChip) -> some View {
        Text(chip.text)
            .font(
                chip.monospaced
                    ? .system(size: 10.5, weight: .medium).monospacedDigit()
                    : .system(size: 10.5, weight: .medium)
            )
            .foregroundStyle(chip.tone.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(chip.style == .filled ? chip.tone.color.opacity(0.14) : .clear)
            )
            .overlay(
                Capsule()
                    .stroke(chip.style == .outlined ? chip.tone.color.opacity(0.25) : .clear, lineWidth: 1)
            )
    }
}

private extension PresentationTone {
    var color: Color {
        switch self {
        case .secondary:
            return .secondary
        case .blue:
            return .blue
        case .green:
            return .green
        case .orange:
            return .orange
        case .red:
            return .red
        }
    }
}
