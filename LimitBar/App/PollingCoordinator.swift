import Foundation

struct PollingCoordinator {
    func interval(codexRunning: Bool) -> TimeInterval {
        if codexRunning {
            let stored = UserDefaults.standard.double(forKey: "pollingWhenRunning")
            return stored > 0 ? stored.clamped(to: 5...60) : 15
        } else {
            let stored = UserDefaults.standard.double(forKey: "pollingWhenClosed")
            return stored > 0 ? stored.clamped(to: 30...300) : 60
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
