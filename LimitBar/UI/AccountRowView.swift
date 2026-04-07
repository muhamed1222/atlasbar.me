import SwiftUI

struct AccountRowView: View {
    let account: Account
    let snapshot: UsageSnapshot?
    let metadata: AccountMetadata
    let isActive: Bool
    let canSwitch: Bool
    let onDelete: () -> Void
    let onSwitch: () -> Void
    let language: ResolvedAppLanguage
    @State private var isRowHovered = false
    private let detailRowHeight: CGFloat = 24
    private let detailRowSpacing: CGFloat = 3
    private let metricsBlockPadding: CGFloat = 3
    private let detailTitleWidth: CGFloat = 84

    private var metricsBlockHeight: CGFloat {
        (detailRowHeight * 3) + (detailRowSpacing * 2) + (metricsBlockPadding * 2)
    }

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
            || presentation.syncText != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerLine

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
        .padding(.horizontal, 7)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onHover { isRowHovered = $0 }
    }

    private var headerLine: some View {
        HStack(alignment: .center, spacing: 10) {
            providerMark

            Text(presentation.title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if let planLabel = presentation.planLabel {
                planBadge(planLabel)
            }

            Spacer(minLength: 8)

            if isActive {
                activeIndicator
            } else if canSwitch {
                switchButton
            }

            deleteButton
        }
    }

    private var metricsLine: some View {
        HStack(alignment: .top, spacing: 8) {
            if sessionUsage != nil || weeklyUsage != nil {
                gaugeCluster
            } else if let tokenDials = claudeTokenDials {
                claudeGaugeCluster(tokenDials)
            }

            VStack(alignment: .leading, spacing: 5) {
                timeDetailsBlock
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var claudeTokenDials: (today: Int, week: Int)? {
        guard account.provider.caseInsensitiveCompare(Provider.claude.name) == .orderedSame,
              let today = presentation.totalTokensToday,
              let week = presentation.totalTokensThisWeek,
              week > 0 else { return nil }
        return (today: today, week: week)
    }

    private func claudeGaugeCluster(_ dials: (today: Int, week: Int)) -> some View {
        HStack(alignment: .center, spacing: 6) {
            claudeTokenDialCard(
                title: strings.tokensToday,
                count: dials.today,
                arcProgress: min(1.0, Double(dials.today) / Double(dials.week))
            )
            claudeTokenDialCard(
                title: strings.tokensWeek,
                count: dials.week,
                arcProgress: 1.0,
                isMuted: true
            )
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 7)
        .frame(height: metricsBlockHeight)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.028))
        )
    }

    private func claudeTokenDialCard(title: String, count: Int, arcProgress: Double, isMuted: Bool = false) -> some View {
        VStack(spacing: 3) {
            ZStack {
                GaugeArcShape(progress: 1)
                    .stroke(
                        Color.secondary.opacity(0.16),
                        style: StrokeStyle(lineWidth: 4.0, lineCap: .round)
                    )
                if !isMuted {
                    GaugeArcShape(progress: arcProgress)
                        .stroke(
                            Color.purple.opacity(0.75),
                            style: StrokeStyle(lineWidth: 4.0, lineCap: .round)
                        )
                }
                Text(strings.formattedTokens(count))
                    .font(.system(size: 9.5, weight: .bold).monospacedDigit())
                    .foregroundStyle(isMuted ? .secondary : .primary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .frame(width: 32)
            }
            .frame(width: 40, height: 40)

            Text(title)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 54)
        .frame(minHeight: 54)
    }

    private var gaugeCluster: some View {
        HStack(alignment: .center, spacing: 6) {
            if let sessionUsage {
                usageDialCard(
                    title: strings.session,
                    remainingPercent: sessionUsage.remainingPercent,
                    tone: barColor(forRemaining: Double(sessionUsage.remainingPercent))
                )
            }

            if let weeklyUsage {
                usageDialCard(
                    title: strings.weekly,
                    remainingPercent: weeklyUsage.remainingPercent,
                    tone: barColor(forRemaining: Double(weeklyUsage.remainingPercent))
                )
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 7)
        .frame(height: metricsBlockHeight)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.028))
        )
    }

    private var timeDetailsBlock: some View {
        VStack(alignment: .leading, spacing: detailRowSpacing) {
            if sessionUsage != nil || weeklyUsage != nil {
                quotaScheduleBlock
            } else {
                if let resetAccent = presentation.resetAccent {
                    detailRow(
                        title: strings.reset,
                        value: resetAccent.countdownValue,
                        tone: resetAccent.countdownTone.color
                    )

                    detailRow(
                        title: strings.time,
                        value: resetAccent.timeText,
                        tone: .secondary
                    )
                }

                if let subscriptionValueText {
                    detailRow(
                        title: strings.subscription,
                        value: subscriptionValueText,
                        tone: presentation.subscriptionChip?.tone.color ?? .secondary
                    )
                }
            }

            if sessionUsage == nil, weeklyUsage == nil,
               let tokensToday = presentation.totalTokensToday {
                detailRow(
                    title: strings.tokensToday,
                    value: strings.formattedTokens(tokensToday),
                    tone: Color.primary
                )

                if let tokensWeek = presentation.totalTokensThisWeek {
                    detailRow(
                        title: strings.tokensWeek,
                        value: strings.formattedTokens(tokensWeek),
                        tone: Color.secondary
                    )
                }

                if let planLabel = presentation.planLabel {
                    detailRow(
                        title: strings.plan,
                        value: planLabel,
                        tone: Color.secondary
                    )
                }
            }
        }
        .padding(.horizontal, metricsBlockPadding)
        .padding(.vertical, metricsBlockPadding)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.028))
        )
    }

    private var quotaScheduleBlock: some View {
        Group {
            detailRow(
                title: strings.dailyReset,
                value: dailyResetValueText,
                tone: .secondary
            )

            detailRow(
                title: strings.weeklyReset,
                value: weeklyResetValueText,
                tone: .secondary
            )

            detailRow(
                title: strings.subscription,
                value: subscriptionValueText ?? "--",
                tone: presentation.subscriptionChip?.tone.color ?? .secondary
            )
        }
    }

    private var dailyResetValueText: String {
        guard let nextResetAt = snapshot?.nextResetAt else {
            return "--"
        }
        return localizedTimeOfDay(nextResetAt, language: language)
    }

    private var weeklyResetValueText: String {
        guard let weeklyResetAt = snapshot?.weeklyResetAt else {
            return "--"
        }
        return localizedMonthDay(weeklyResetAt, language: language)
    }

    private var subscriptionValueText: String? {
        guard let subscriptionChip = presentation.subscriptionChip else {
            return nil
        }

        let prefix = strings.expires("")
        if subscriptionChip.text.hasPrefix(prefix) {
            return String(subscriptionChip.text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        }

        return subscriptionChip.text
    }

    private var providerMark: some View {
        ProviderMarkView(provider: account.provider, size: .compact)
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
        .opacity(isRowHovered ? 1 : 0)
        .animation(.easeOut(duration: 0.15), value: isRowHovered)
    }

    private var activeIndicator: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(Color.green)
                .frame(width: 5, height: 5)
            Text(strings.activeAccountLabel)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2.5)
        .background(
            Capsule(style: .continuous)
                .fill(Color.green.opacity(0.1))
        )
    }

    private var switchButton: some View {
        Button(action: onSwitch) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.orange.opacity(0.7))
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(RowIconButtonStyle())
        .help(strings.switchAccountHelp)
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
        VStack(spacing: 3) {
            UsageDialView(
                remainingPercent: remainingPercent,
                tone: tone
            )
            .frame(width: 40, height: 40)

            Text(title)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 54)
        .frame(minHeight: 54)
    }

    private func detailRow(title: String, value: String, tone: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(width: detailTitleWidth, alignment: .leading)

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 8)
        .frame(height: detailRowHeight)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.028))
        )
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
    private let gaugeLineWidth: CGFloat = 4.0

    var body: some View {
        ZStack {
            GaugeArcShape(progress: 1)
                .stroke(
                    Color.secondary.opacity(0.16),
                    style: StrokeStyle(lineWidth: gaugeLineWidth, lineCap: .round)
                )

            GaugeArcShape(progress: Double(remainingPercent) / 100)
                .stroke(
                    tone,
                    style: StrokeStyle(lineWidth: gaugeLineWidth, lineCap: .round)
                )

            VStack(spacing: 1) {
                Text("\(remainingPercent)")
                    .font(.system(size: 11.5, weight: .bold).monospacedDigit())
                    .foregroundStyle(.primary)
                Text("%")
                    .font(.system(size: 7.5, weight: .semibold))
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
