import SwiftUI

struct CompactStatusView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        HStack(spacing: 4) {
            CodexMarkView(size: .compact)
            Circle()
                .fill(dotColor)
                .frame(width: 5, height: 5)
            Text(appModel.compactLabel)
                .monospacedDigit()
        }
    }

    private var dotColor: Color {
        switch appModel.menuBarState {
        case .available:
            return .green
        case .low:
            return .orange
        case .allCoolingDown:
            return .red
        case .noData:
            return Color.secondary.opacity(0.6)
        }
    }
}
