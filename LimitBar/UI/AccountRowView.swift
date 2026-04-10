import SwiftUI

struct AccountRowView: View {
    @Environment(\.colorScheme) private var colorScheme
    let account: Account
    let snapshot: UsageSnapshot?
    let metadata: AccountMetadata
    let isActive: Bool
    let canSwitch: Bool
    let onDelete: () -> Void
    let onSwitch: () -> Void
    let language: ResolvedAppLanguage
    @State private var isRowHovered = false
    @State private var isActivePulseVisible = false
    private let detailRowHeight: CGFloat = 24
    private let detailRowSpacing: CGFloat = 3
    private let metricsBlockPadding: CGFloat = 3
    private let detailTitleWidth: CGFloat = 76

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

    private var quotaDisplayMode: AccountQuotaDisplayMode {
        accountQuotaDisplayMode(snapshot: snapshot)
    }

    private var displayedUsageBars: [UsageBarPresentation] {
        visibleUsageBars(snapshot: snapshot, usageBars: presentation.usageBars)
    }

    private var sessionUsage: UsageBarPresentation? {
        displayedUsageBars.first(where: { $0.label == "S" })
    }

    private var weeklyUsage: UsageBarPresentation? {
        displayedUsageBars.first(where: { $0.label == "W" })
    }

    private var hasMetricsContent: Bool {
        sessionUsage != nil
            || weeklyUsage != nil
            || hasClaudeTokenDetails
            || presentation.resetAccent != nil
            || presentation.subscriptionChip != nil
            || presentation.syncText != nil
    }

    private var hasClaudeTokenDetails: Bool {
        account.provider.isClaude
            && sessionUsage == nil
            && weeklyUsage == nil
            && (presentation.totalTokensToday != nil || presentation.totalTokensThisWeek != nil)
    }

    private var rowFillColor: Color {
        if colorScheme == .light {
            if isActive {
                return Color.green.opacity(0.075)
            }
            return Color.black.opacity(isRowHovered ? 0.07 : 0.05)
        }
        if isActive {
            return Color.green.opacity(0.06)
        }
        return Color.primary.opacity(isRowHovered ? 0.06 : 0.04)
    }

    private var rowStrokeColor: Color {
        if colorScheme == .light {
            if isActive {
                return Color.green.opacity(0.2)
            }
            return Color.black.opacity(isRowHovered ? 0.12 : 0.08)
        }
        if isActive {
            return Color.green.opacity(0.18)
        }
        return Color.primary.opacity(isRowHovered ? 0.09 : 0.04)
    }

    private var clusterSurfaceFill: Color {
        colorScheme == .light ? Color.black.opacity(0.042) : Color.primary.opacity(0.022)
    }

    private var detailBlockSurfaceFill: Color {
        colorScheme == .light ? Color.black.opacity(0.04) : Color.primary.opacity(0.022)
    }

    private var detailRowSurfaceFill: Color {
        colorScheme == .light ? Color.black.opacity(0.05) : Color.primary.opacity(0.028)
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
                    .padding(.top, 1)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(rowFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(rowStrokeColor, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onHover { isRowHovered = $0 }
        .onAppear {
            isActivePulseVisible = isActive
        }
        .onChange(of: isActive) { _, newValue in
            isActivePulseVisible = newValue
        }
    }

    private var headerLine: some View {
        HStack(alignment: .center, spacing: 10) {
            providerMark

            Text(presentation.title)
                .font(.system(size: 12.5, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if let planLabel = presentation.planLabel {
                planBadge(planLabel)
            }

            Spacer(minLength: 8)

            HStack(spacing: 2) {
                if isActive {
                    activeIndicator
                } else if canSwitch {
                    switchButton
                }

                deleteButton
            }
        }
    }

    private var metricsLine: some View {
        HStack(alignment: .top, spacing: 8) {
            if quotaDisplayMode != .subscriptionExpired,
               sessionUsage != nil || weeklyUsage != nil {
                gaugeCluster
            }

            VStack(alignment: .leading, spacing: 5) {
                timeDetailsBlock
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
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
                .fill(clusterSurfaceFill)
        )
    }

    private var timeDetailsBlock: some View {
        VStack(alignment: .leading, spacing: detailRowSpacing) {
            switch quotaDisplayMode {
            case .subscriptionExpired:
                subscriptionExpiredBlock
            case .normal where sessionUsage != nil || weeklyUsage != nil:
                quotaScheduleBlock
            case .normal where hasClaudeTokenDetails:
                claudeTokenDetailsBlock
            case .sessionCooldown:
                sessionCooldownBlock
            case .weeklyLock:
                weeklyLockBlock
            case .normal:
                if let resetAccent = presentation.resetAccent {
                    accentDetailRow(
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

        }
        .padding(.horizontal, metricsBlockPadding)
        .padding(.vertical, metricsBlockPadding)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(detailBlockSurfaceFill)
        )
    }

    private var subscriptionExpiredBlock: some View {
        Group {
            detailRow(
                title: strings.subscription,
                value: subscriptionValueText ?? strings.expired,
                tone: presentation.subscriptionChip?.tone.color ?? .secondary
            )
        }
    }

    private var sessionCooldownBlock: some View {
        Group {
            if let resetAccent = presentation.resetAccent {
                accentDetailRow(
                    title: resetAccent.title,
                    value: resetAccent.countdownValue,
                    tone: resetAccent.countdownTone.color
                )
            }

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

    private var weeklyLockBlock: some View {
        Group {
            if let resetAccent = presentation.resetAccent {
                accentDetailRow(
                    title: resetAccent.title,
                    value: resetAccent.countdownValue,
                    tone: resetAccent.countdownTone.color
                )
            }

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

    private var claudeTokenDetailsBlock: some View {
        Group {
            if let tokensTodayValueText {
                detailRow(
                    title: strings.tokensToday,
                    value: tokensTodayValueText,
                    tone: .secondary
                )
            }

            if let tokensWeekValueText {
                detailRow(
                    title: strings.tokensWeek,
                    value: tokensWeekValueText,
                    tone: .secondary
                )
            }

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

    private var tokensTodayValueText: String? {
        guard let count = presentation.totalTokensToday else {
            return nil
        }
        return strings.formattedTokens(count)
    }

    private var tokensWeekValueText: String? {
        guard let count = presentation.totalTokensThisWeek else {
            return nil
        }
        return strings.formattedTokens(count)
    }

    private var providerMark: some View {
        ProviderMarkView(provider: account.provider, size: .compact, style: .accountList)
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
        ZStack {
            Circle()
                .fill(Color.green)
                .frame(width: 7, height: 7)

            Circle()
                .stroke(Color.green.opacity(0.35), lineWidth: 1.5)
                .frame(width: 13, height: 13)
                .scaleEffect(isActivePulseVisible ? 1.16 : 0.86)
                .opacity(isActivePulseVisible ? 0.15 : 0.42)
                .animation(
                    .easeInOut(duration: 1.15).repeatForever(autoreverses: true),
                    value: isActivePulseVisible
                )
        }
        .frame(width: 16, height: 16)
        .help(strings.activeAccountLabel)
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
                .fill(detailRowSurfaceFill)
        )
    }

    private func accentDetailRow(title: String, value: String, tone: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(tone.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(width: detailTitleWidth, alignment: .leading)

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 8)
        .frame(height: detailRowHeight)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tone.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tone.opacity(0.18), lineWidth: 1)
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
                    .font(.system(size: 9.5, weight: .bold).monospacedDigit())
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
