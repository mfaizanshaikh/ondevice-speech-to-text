import Foundation
import AppKit
import Carbon.HIToolbox

@MainActor
class TextInsertionService {
    static let shared = TextInsertionService()

    /// Apps known to not properly support accessibility text insertion (mostly Electron apps)
    private let pasteboardOnlyApps: Set<String> = [
        "WhatsApp",
        "Slack",
        "Discord",
        "Microsoft Teams",
        "Notion",
        "Figma",
        "Visual Studio Code",
        "Code",
        "Cursor",
        "Telegram",
        "Messenger",
        "Signal",
        "Spotify"
    ]

    private init() {}

    func insertText(_ text: String) async -> Bool {
        guard !text.isEmpty else { return false }

        print("[TextInsertion] Attempting to insert text: \"\(text)\"")
        print("[TextInsertion] Accessibility trusted: \(AXIsProcessTrusted())")

        // Check if we should skip accessibility and go straight to pasteboard
        if let appName = getFocusedAppName(), pasteboardOnlyApps.contains(appName) {
            print("[TextInsertion] App '\(appName)' requires pasteboard method, skipping accessibility")
            let result = await insertViaPasteboard(text)
            print("[TextInsertion] Pasteboard result: \(result)")
            return result
        }

        if await insertViaAccessibility(text) {
            print("[TextInsertion] Successfully inserted via accessibility")
            return true
        }

        print("[TextInsertion] Accessibility insertion failed, trying pasteboard fallback")
        let result = await insertViaPasteboard(text)
        print("[TextInsertion] Pasteboard fallback result: \(result)")
        return result
    }

    private func getFocusedAppName() -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success,
              let app = focusedApp else {
            return nil
        }

        var appTitle: CFTypeRef?
        if AXUIElementCopyAttributeValue(app as! AXUIElement, kAXTitleAttribute as CFString, &appTitle) == .success {
            return appTitle as? String
        }
        return nil
    }

    private func insertViaAccessibility(_ text: String) async -> Bool {
        guard let focusedElement = getFocusedElement() else {
            print("[TextInsertion] Failed to get focused element")
            return false
        }

        print("[TextInsertion] Got focused element, attempting kAXSelectedTextAttribute")
        let value = text as CFTypeRef
        let result = AXUIElementSetAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, value)

        if result == .success {
            return true
        }
        print("[TextInsertion] kAXSelectedTextAttribute failed with: \(result.rawValue), trying kAXValueAttribute")

        if let existingValue = getAttributeValue(focusedElement, attribute: kAXValueAttribute) as? String {
            let selectedRange = getSelectedRange(focusedElement)

            var newValue: String
            if let range = selectedRange {
                let start = existingValue.index(existingValue.startIndex, offsetBy: range.location, limitedBy: existingValue.endIndex) ?? existingValue.endIndex
                let end = existingValue.index(start, offsetBy: range.length, limitedBy: existingValue.endIndex) ?? existingValue.endIndex
                newValue = existingValue.replacingCharacters(in: start..<end, with: text)
            } else {
                newValue = existingValue + text
            }

            let setResult = AXUIElementSetAttributeValue(focusedElement, kAXValueAttribute as CFString, newValue as CFTypeRef)
            print("[TextInsertion] kAXValueAttribute set result: \(setResult.rawValue)")
            return setResult == .success
        }

        print("[TextInsertion] Could not get existing value from focused element")
        return false
    }

    private func insertViaPasteboard(_ text: String) async -> Bool {
        let pasteboard = NSPasteboard.general
        let originalContents = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        simulatePaste()

        try? await Task.sleep(nanoseconds: 100_000_000)

        if let original = originalContents {
            pasteboard.clearContents()
            pasteboard.setString(original, forType: .string)
        }

        return true
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }

    private func getFocusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedApp: CFTypeRef?
        let appResult = AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp)
        guard appResult == .success, let app = focusedApp else {
            print("[TextInsertion] Failed to get focused application: \(appResult.rawValue)")
            return nil
        }

        // Try to get the app name for debugging
        var appTitle: CFTypeRef?
        if AXUIElementCopyAttributeValue(app as! AXUIElement, kAXTitleAttribute as CFString, &appTitle) == .success {
            print("[TextInsertion] Focused application: \(appTitle as? String ?? "unknown")")
        }

        var focusedElement: CFTypeRef?
        let elementResult = AXUIElementCopyAttributeValue(app as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard elementResult == .success else {
            print("[TextInsertion] Failed to get focused UI element: \(elementResult.rawValue)")
            return nil
        }

        // Try to get element role for debugging
        var role: CFTypeRef?
        if AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXRoleAttribute as CFString, &role) == .success {
            print("[TextInsertion] Focused element role: \(role as? String ?? "unknown")")
        }

        return (focusedElement as! AXUIElement)
    }

    private func getAttributeValue(_ element: AXUIElement, attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return result == .success ? value : nil
    }

    private func getSelectedRange(_ element: AXUIElement) -> NSRange? {
        guard let value = getAttributeValue(element, attribute: kAXSelectedTextRangeAttribute) else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(value as! AXValue, .cfRange, &range) else {
            return nil
        }

        return NSRange(location: range.location, length: range.length)
    }
}
