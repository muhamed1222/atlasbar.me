import Foundation
import AppKit

enum CodexSessionSwitchError: Error, LocalizedError {
    case appNotFound
    case terminationTimedOut
    case launchTimedOut
    case activeIdentityMismatch(expected: String, actual: String?)

    var errorDescription: String? {
        switch self {
        case .appNotFound:
            return "Codex app could not be found."
        case .terminationTimedOut:
            return "Codex did not terminate in time."
        case .launchTimedOut:
            return "Codex did not launch in time."
        case .activeIdentityMismatch(let expected, let actual):
            return "Active account mismatch. Expected \(expected), got \(actual ?? "none")."
        }
    }
}

@MainActor
protocol CodexAppControlling {
    func terminateCodex()
    func waitUntilTerminated(timeout: TimeInterval) async -> Bool
    func launchCodex() throws
    func waitUntilRunning(timeout: TimeInterval) async -> Bool
}

@MainActor
protocol CodexSessionSwitching {
    func switchTo(email: String) async throws -> String
}

@MainActor
struct CodexAppController: CodexAppControlling {
    private let bundleIds = [
        "com.openai.codex",
        "com.openai.Codex",
        "openai.codex",
        "com.todesktop.230313mzl4w4u92"
    ]

    func terminateCodex() {
        for app in NSWorkspace.shared.runningApplications where bundleIds.contains(app.bundleIdentifier ?? "") {
            app.terminate()
            return
        }
    }

    func waitUntilTerminated(timeout: TimeInterval) async -> Bool {
        await waitUntil(timeout: timeout) {
            !isRunning
        }
    }

    func launchCodex() throws {
        for bundleId in bundleIds {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                NSWorkspace.shared.openApplication(at: url, configuration: .init())
                return
            }
        }

        let paths = [
            "/Applications/Codex.app",
            "\(NSHomeDirectory())/Applications/Codex.app"
        ]

        if let url = paths
            .map({ URL(fileURLWithPath: $0) })
            .first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
            return
        }

        throw CodexSessionSwitchError.appNotFound
    }

    func waitUntilRunning(timeout: TimeInterval) async -> Bool {
        await waitUntil(timeout: timeout) {
            isRunning
        }
    }

    private var isRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { bundleIds.contains($0.bundleIdentifier ?? "") }
    }

    private func waitUntil(timeout: TimeInterval, condition: @escaping () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        return condition()
    }
}

@MainActor
struct CodexSessionSwitcher: CodexSessionSwitching {
    private let vault: any AccountVaulting
    private let appController: any CodexAppControlling
    private let authReader: any CodexAuthReading

    init(
        vault: any AccountVaulting,
        appController: any CodexAppControlling = CodexAppController(),
        authReader: any CodexAuthReading = CodexAuthReader()
    ) {
        self.vault = vault
        self.appController = appController
        self.authReader = authReader
    }

    func switchTo(email: String) async throws -> String {
        try vault.switchTo(email: email)
        appController.terminateCodex()

        guard await appController.waitUntilTerminated(timeout: 8) else {
            throw CodexSessionSwitchError.terminationTimedOut
        }

        try appController.launchCodex()

        guard await appController.waitUntilRunning(timeout: 8) else {
            throw CodexSessionSwitchError.launchTimedOut
        }

        let confirmedEmail = await waitUntilActiveEmailMatches(email, timeout: 10)
        guard let confirmedEmail else {
            throw CodexSessionSwitchError.activeIdentityMismatch(
                expected: email,
                actual: authReader.readAccountInfo()?.email
            )
        }

        return confirmedEmail
    }

    private func waitUntilActiveEmailMatches(_ email: String, timeout: TimeInterval) async -> String? {
        let expected = email.lowercased()
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if let active = authReader.readAccountInfo()?.email, active.lowercased() == expected {
                return active
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }

        if let active = authReader.readAccountInfo()?.email, active.lowercased() == expected {
            return active
        }
        return nil
    }
}
