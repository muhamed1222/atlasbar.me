import Foundation

enum MenuBarState: Equatable {
    /// At least one account is available with good headroom (>30% remaining)
    case available
    /// At least one account is available, but all have low remaining (≤30%)
    case low
    /// All accounts are cooling down — carries the soonest reset time
    case allCoolingDown(nextResetAt: Date?)
    /// No data yet or everything is stale/unknown
    case noData
}
