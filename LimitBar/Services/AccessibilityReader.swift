import ApplicationServices
import AppKit

struct AccessibilityReader {
    private let maxDepth = 50
    private let maxNodes = 2000

    func hasPermission() -> Bool {
        AXIsProcessTrusted()
    }

    func promptForPermissionIfNeeded() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    // Runs on a background thread — does not block the main actor
    func extractStrings(from app: NSRunningApplication) async -> [String] {
        let pid = app.processIdentifier
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let appElement = AXUIElementCreateApplication(pid)
                var counter = 0
                let strings = collectStrings(from: appElement, depth: 0, counter: &counter)
                continuation.resume(returning: strings)
            }
        }
    }

    private func collectStrings(from element: AXUIElement, depth: Int, counter: inout Int) -> [String] {
        guard depth < maxDepth, counter < maxNodes else { return [] }
        counter += 1

        var results: [String] = []

        for attribute in [kAXValueAttribute, kAXTitleAttribute, kAXDescriptionAttribute, kAXPlaceholderValueAttribute] {
            if let value = copyStringAttribute(element, attribute: attribute) {
                results.append(value)
            }
        }

        if let children = copyChildren(element) {
            for child in children {
                results.append(contentsOf: collectStrings(from: child, depth: depth + 1, counter: &counter))
            }
        }

        return results.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func copyStringAttribute(_ element: AXUIElement, attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func copyChildren(_ element: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success else { return nil }
        return value as? [AXUIElement]
    }
}
