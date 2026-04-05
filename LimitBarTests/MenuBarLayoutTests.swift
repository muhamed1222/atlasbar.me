import SwiftUI
import Testing
@testable import LimitBar

struct MenuBarLayoutTests {
    @Test
    func accountsSectionHeightScalesWithVisibleRows() {
        #expect(accountsSectionMaxHeight(for: 0) == 112)
        #expect(accountsSectionMaxHeight(for: 1) == 112)
        #expect(accountsSectionMaxHeight(for: 2) == 228)
        #expect(accountsSectionMaxHeight(for: 3) == 344)
        #expect(accountsSectionMaxHeight(for: 5) == 344)
    }
}
