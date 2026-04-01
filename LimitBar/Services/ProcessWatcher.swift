import AppKit

struct ProcessWatcher {
    func runningCodexApp() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first {
            ($0.localizedName ?? "").localizedCaseInsensitiveContains("Codex")
                || ($0.bundleIdentifier ?? "").localizedCaseInsensitiveContains("codex")
        }
    }

    var isCodexRunning: Bool {
        runningCodexApp() != nil
    }
}
