import SwiftUI
import Testing
@testable import LimitBar

struct MenuBarLayoutTests {
    @Test
    func accountsSectionHeightScalesWithVisibleRows() {
        #expect(accountsSectionMaxHeight(for: 0) == 140)
        #expect(accountsSectionMaxHeight(for: 1) == 140)
        #expect(accountsSectionMaxHeight(for: 2) == 284)
        #expect(accountsSectionMaxHeight(for: 3) == 428)
        #expect(accountsSectionMaxHeight(for: 5) == 428)
    }
}
