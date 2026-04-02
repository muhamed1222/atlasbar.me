import SwiftUI

struct AccountRowView: View {
    let account: Account
    let snapshot: UsageSnapshot?
    let metadata: AccountMetadata
    let onDelete: () -> Void
    let language: ResolvedAppLanguage
    @State private var isHovered = false

    private var presentation: AccountRowPresentation {
        makeAccountRowPresentation(
            account: account,
            snapshot: snapshot,
            metadata: metadata,
            language: language
        )
    }

    private var strings: AppStrings {
        AppStrings(language: language)
    }

    private var sessionUsage: UsageBarPresentation? {
        presentation.usageBars.first(where: { $0.label == "S" })
    }

    private var weeklyUsage: UsageBarPresentation? {
        presentation.usageBars.first(where: { $0.label == "W" })
    }

    private var hasMetricsContent: Bool {
        sessionUsage != nil
            || weeklyUsage != nil
            || presentation.resetAccent != nil
            || presentation.subscriptionChip != nil
            || presentation.statusChip != nil
            || presentation.syncText != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerLine

            if presentation.statusChip != nil || presentation.subscriptionChip != nil {
                summaryLine
            }

            if hasMetricsContent {
                metricsLine
            }

            if let notePreview = presentation.notePreview {
                Text(notePreview)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(isHovered ? 0.045 : 0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(isHovered ? 0.06 : 0), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHovered = hovering
            }
        }
    }

    private var headerLine: some View {
        HStack(alignment: .center, spacing: 10) {
            codexMark

            Text(presentation.title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 8)

            if let planLabel = presentation.planLabel {
                planBadge(planLabel)
            }

            deleteButton
        }
    }

    private var summaryLine: some View {
        HStack(spacing: 5) {
            if let statusChip = presentation.statusChip {
                chip(statusChip, softened: presentation.resetAccent != nil)
            }

            if let subscriptionChip = presentation.subscriptionChip {
                chip(subscriptionChip, softened: presentation.resetAccent != nil)
            }
        }
    }

    private var metricsLine: some View {
        HStack(alignment: .top, spacing: 8) {
            if let sessionUsage {
                usageDialCard(
                    title: strings.session,
                    remainingPercent: sessionUsage.remainingPercent,
                    tone: barColor(forRemaining: Double(sessionUsage.remainingPercent))
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                if let weeklyUsage {
                    weeklyStatRow(weeklyUsage)
                }

                infoStrip

                if let syncText = presentation.syncText {
                    Text(syncText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var infoStrip: some View {
        Group {
            if let resetAccent = presentation.resetAccent {
                resetStrip(resetAccent)
            } else if let subscriptionChip = presentation.subscriptionChip {
                summaryStrip(
                    title: strings.subscription,
                    value: subscriptionChip.text,
                    tone: subscriptionChip.tone.color
                )
            } else if let statusChip = presentation.statusChip {
                summaryStrip(
                    title: strings.account,
                    value: statusChip.text,
                    tone: statusChip.tone.color
                )
            } else {
                EmptyView()
            }
        }
    }

    private var codexMark: some View {
        CodexMarkView(size: .compact)
    }

    private func planBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(Color.blue)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.blue.opacity(0.08))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.blue.opacity(0.12), lineWidth: 1)
            )
    }

    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "trash")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary.opacity(0.5))
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(RowIconButtonStyle())
        .help(strings.deleteAccountHelp)
    }

    private func chip(_ chip: PresentationChip, softened: Bool = false) -> some View {
        Text(chip.text)
            .font(
                chip.monospaced
                    ? .system(size: softened ? 9 : 9.5).monospacedDigit()
                    : .system(size: softened ? 9 : 9.5, weight: .medium)
            )
            .foregroundStyle(chip.style.foreground(for: chip.tone.color))
            .padding(.horizontal, softened ? 4.5 : 5)
            .padding(.vertical, 2)
            .background(
                Capsule(style: .continuous)
                    .fill(chip.style.background(for: chip.tone.color))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(chip.style.border(for: chip.tone.color), lineWidth: chip.style == .outlined ? 1 : 0)
            )
            .opacity(softened ? 0.76 : 1)
    }

    private func usageDialCard(title: String, remainingPercent: Int, tone: Color) -> some View {
        VStack(spacing: 4) {
            UsageDialView(
                remainingPercent: remainingPercent,
                tone: tone
            )
            .frame(width: 46, height: 46)

            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 62)
        .frame(minHeight: 62)
    }

    private func weeklyStatRow(_ usage: UsageBarPresentation) -> some View {
        HStack(spacing: 8) {
            Text(strings.weekly)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Text("\(usage.remainingPercent)%")
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                .foregroundStyle(barColor(forRemaining: Double(usage.remainingPercent)))
        }
        .padding(.top, 1)
    }

    private func resetStrip(_ accent: ResetAccentPresentation) -> some View {
        HStack(spacing: 8) {
            Text(accent.countdownText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.orange)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 0)

            Text(accent.timeText)
                .font(.system(size: 9.5, weight: .semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.orange.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.orange.opacity(0.1), lineWidth: 1)
        )
    }

    private func summaryStrip(title: String, value: String, tone: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.top, 1)
    }

    private func barColor(forRemaining percent: Double) -> Color {
        if percent <= 10 { return .red }
        if percent <= 30 { return .yellow }
        return .green
    }
}

private struct UsageDialView: View {
    let remainingPercent: Int
    let tone: Color

    var body: some View {
        ZStack {
            GaugeArcShape(progress: 1)
                .stroke(Color.secondary.opacity(0.16), style: StrokeStyle(lineWidth: 7, lineCap: .round))

            GaugeArcShape(progress: Double(remainingPercent) / 100)
                .stroke(
                    tone,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )

            VStack(spacing: 1) {
                Text("\(remainingPercent)")
                    .font(.system(size: 15, weight: .bold).monospacedDigit())
                    .foregroundStyle(.primary)
                Text("%")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct GaugeArcShape: Shape {
    var progress: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - 4.5
        let startAngle = Angle(degrees: 150)
        let endAngle = Angle(degrees: 390)
        let span = endAngle.degrees - startAngle.degrees
        let clamped = max(0, min(progress, 1))
        let currentAngle = Angle(degrees: startAngle.degrees + span * clamped)

        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: currentAngle,
            clockwise: false
        )
        return path
    }
}

private struct RowIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        RowIconButtonBody(configuration: configuration)
    }
}

private struct RowIconButtonBody: View {
    let configuration: RowIconButtonStyle.Configuration
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(backgroundOpacity))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.14)) {
                    isHovered = hovering
                }
            }
    }

    private var backgroundOpacity: Double {
        if configuration.isPressed { return 0.1 }
        if isHovered { return 0.06 }
        return 0
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
    func background(for color: Color) -> Color {
        switch self {
        case .filled:
            return color.opacity(0.12)
        case .outlined:
            return Color.clear
        }
    }

    func foreground(for color: Color) -> Color {
        switch self {
        case .filled, .outlined:
            return color
        }
    }

    func border(for color: Color) -> Color {
        switch self {
        case .filled:
            return .clear
        case .outlined:
            return color.opacity(0.22)
        }
    }
}
