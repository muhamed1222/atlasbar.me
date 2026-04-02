import SwiftUI

struct CompactStatusView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        HStack(spacing: 5) {
            CodexMarkView(size: .compact)
            Text(appModel.compactLabel)
                .monospacedDigit()
        }
    }
}
