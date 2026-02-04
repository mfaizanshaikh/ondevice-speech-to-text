import Foundation
import AppKit

@MainActor
class TextInsertionService {
    static let shared = TextInsertionService()

    private init() {}

    func insertText(_ text: String) async -> Bool {
        guard !text.isEmpty else { return false }

        print("[TextInsertion] Copying text to pasteboard: \"\(text)\"")
        await copyToPasteboard(text)
        // Return false so the caller can notify the user to paste manually.
        return false
    }

    private func copyToPasteboard(_ text: String) async {
        let pasteboard = NSPasteboard.general

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
