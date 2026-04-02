import SwiftUI

struct AccountRowView: View {
    let account: Account
    let snapshot: UsageSnapshot?
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                statusDot
                VStack(alignment: .leading, spacing: 1) {
                    Text(account.displayName)
                        .font(.system(size: 12.5, weight: .semibold))
                        .lineLimit(1)
                    metaLine
                }
                Spacer()
                if let snapshot {
                    Text(shortUsageLabel(snapshot: snapshot))
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
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

            if let snapshot {
                if snapshot.sessionPercentUsed != nil || snapshot.weeklyPercentUsed != nil {
                    VStack(alignment: .leading, spacing: 4) {
                        if let session = snapshot.sessionPercentUsed {
                            usageBar(label: "S", usedPercent: session)
                        }
                        if let weekly = snapshot.weeklyPercentUsed {
                            usageBar(label: "W", usedPercent: weekly)
                        }
                    }
                }

                if let freshness = freshnessLabel(for: snapshot) {
                    Text(freshness)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
    }

    @ViewBuilder
    private var metaLine: some View {
        if let snapshot {
            HStack(spacing: 4) {
                if let plan = account.note {
                    Text(plan.capitalized)
                }
                Text(snapshot.usageStatus.displayLabel)
                    .foregroundStyle(snapshot.usageStatus.color)
                if let nextResetAt = snapshot.nextResetAt, snapshot.usageStatus == .coolingDown {
                    Text("· \(countdownString(until: nextResetAt))")
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption2)
            .lineLimit(1)
        } else if let plan = account.note {
            Text(plan.capitalized)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var statusDot: some View {
        Circle()
            .fill((snapshot?.usageStatus ?? .unknown).color)
            .frame(width: 7, height: 7)
    }

    private func usageBar(label: String, usedPercent: Double) -> some View {
        let remaining = remainingPercent(from: usedPercent)

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
                        .fill(barColor(forRemaining: remaining))
                        .frame(width: geo.size.width * min(remaining / 100, 1), height: 4)
                }
            }
            .frame(height: 4)

            HStack {
                Text("\(Int(remaining))%")
                    .font(.system(size: 10.5).monospacedDigit())
                    .foregroundStyle(barColor(forRemaining: remaining))
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
