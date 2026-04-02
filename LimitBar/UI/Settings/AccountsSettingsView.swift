import SwiftUI

struct AccountsSettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var selection: UUID?

    var body: some View {
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
                        "Select an account",
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text("Choose an account from the list to edit priority and note.")
                    )
                }
            }
            .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Accounts")
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
        let metadata = appModel.metadata(for: account.id)
        let snapshot = appModel.snapshot(for: account.id)
        let presentation = makeAccountDetailPresentation(account: account, snapshot: snapshot, metadata: metadata)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                accountSummaryCard(presentation)

                Form {
                    Section("Identity") {
                        ForEach(presentation.identityRows, id: \.title) { row in
                            detailRow(row.title, value: row.value)
                        }
                    }

                    Section("Priority") {
                        Picker(
                            "Priority",
                            selection: Binding(
                                get: { appModel.metadata(for: account.id).priority },
                                set: { appModel.updatePriority($0, for: account.id) }
                            )
                        ) {
                            ForEach(AccountPriority.allCases, id: \.self) { priority in
                                Text(priority.displayLabel).tag(priority)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("Note") {
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
        let presentation = makeAccountsListRowPresentation(account: account, snapshot: snapshot, metadata: metadata)

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
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
            }
        }
        .padding(.vertical, 3)
    }

    private func accountSummaryCard(_ presentation: AccountDetailPresentation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(presentation.title)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                    Text(presentation.providerLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func settingsBadge(_ chip: PresentationChip) -> some View {
        Text(chip.text)
            .font(.system(size: 10.5, weight: .medium))
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
