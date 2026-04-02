import SwiftUI

struct AccountRowView: View {
    let account: Account
    let snapshot: UsageSnapshot?
    let metadata: AccountMetadata
    let onDelete: () -> Void

    private var presentation: AccountRowPresentation {
        makeAccountRowPresentation(account: account, snapshot: snapshot, metadata: metadata)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                statusDot
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 5) {
                    topLine
                    metaLine

                    if let snapshot, snapshot.sessionPercentUsed != nil || snapshot.weeklyPercentUsed != nil {
                        usageSection(snapshot)
                    }

                    if metadata.hasNote {
                        notePreview
                    }

                    footerLine
                }
                Spacer(minLength: 8)
                deleteButton
            }
        }
        .padding(.vertical, 6)
    }

    private var topLine: some View {
        HStack(spacing: 6) {
            Text(presentation.title)
                .font(.system(size: 12.5, weight: .semibold))
                .lineLimit(1)

            if let priorityChip = metadata.priority == .none ? nil : PresentationChip(
                text: metadata.priority.displayLabel,
                tone: .blue,
                style: .filled
            ) {
                chip(priorityChip)
            }

            Spacer(minLength: 6)

            if let usageSummary = presentation.usageSummary {
                chip(usageSummary)
            }
        }
    }

    private var metaLine: some View {
        HStack(spacing: 5) {
            ForEach(Array(presentation.chips.enumerated()), id: \.offset) { _, chip in
                self.chip(chip)
            }
        }
        .font(.caption2)
        .lineLimit(1)
    }

    private func usageSection(_ snapshot: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(presentation.usageBars, id: \.label) { bar in
                usageBar(label: bar.label, remainingPercent: bar.remainingPercent)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var notePreview: some View {
        HStack(spacing: 5) {
            Image(systemName: "note.text")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)

            Text(presentation.notePreview ?? "")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var footerLine: some View {
        Group {
            if let syncText = presentation.syncText {
                Text(syncText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "trash")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help("Delete account")
    }

    private func chip(_ chip: PresentationChip) -> some View {
        Text(chip.text)
            .font(
                chip.monospaced
                    ? .system(size: 10.5).monospacedDigit()
                    : .system(size: 10.5, weight: .medium)
            )
            .foregroundStyle(chip.style.foreground(for: chip.tone.color))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule(style: .continuous)
                    .fill(chip.style.background(for: chip.tone.color))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(chip.style.border(for: chip.tone.color), lineWidth: chip.style == .outlined ? 1 : 0)
            )
    }

    private var statusDot: some View {
        Circle()
            .fill((snapshot?.usageStatus ?? .unknown).color)
            .frame(width: 7, height: 7)
    }

    private func usageBar(label: String, remainingPercent: Int) -> some View {
        return HStack(spacing: 7) {
            Text(label)
                .font(.system(size: 10, weight: .semibold).monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 10, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.18))
                        .frame(height: 4)
                    Capsule()
                        .fill(barColor(forRemaining: Double(remainingPercent)))
                        .frame(width: geo.size.width * min(Double(remainingPercent) / 100, 1), height: 4)
                }
            }
            .frame(height: 4)

            HStack {
                Text("\(remainingPercent)%")
                    .font(.system(size: 10.5).monospacedDigit())
                    .foregroundStyle(barColor(forRemaining: Double(remainingPercent)))
            }
            .frame(width: 34, alignment: .trailing)
        }
    }

    private func barColor(forRemaining percent: Double) -> Color {
        if percent <= 10 { return .red }
        if percent <= 30 { return .yellow }
        return .green
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

private extension PresentationChipStyle {
    func foreground(for color: Color) -> Color {
        color
    }

    func background(for color: Color) -> Color {
        switch self {
        case .filled:
            return color.opacity(0.14)
        case .outlined:
            return .clear
        }
    }

    func border(for color: Color) -> Color {
        switch self {
        case .filled:
            return .clear
        case .outlined:
            return color.opacity(0.25)
        }
    }
}
