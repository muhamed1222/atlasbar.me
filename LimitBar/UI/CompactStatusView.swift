import SwiftUI

struct CompactStatusView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Text(appModel.compactLabel)
            .monospacedDigit()
    }
}
