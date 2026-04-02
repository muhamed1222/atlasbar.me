import AppKit

protocol CodexRunningChecking {
    var isCodexRunning: Bool { get }
}

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

extension ProcessWatcher: CodexRunningChecking {}
