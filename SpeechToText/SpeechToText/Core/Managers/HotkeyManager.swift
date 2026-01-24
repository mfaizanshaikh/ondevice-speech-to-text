import Foundation
import AppKit
import Carbon.HIToolbox
import HotKey

@MainActor
class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()

    @Published var isHotkeyRegistered = false
    @Published var currentKeyCode: UInt32 = Constants.Hotkey.defaultKeyCode
    @Published var currentModifiers: NSEvent.ModifierFlags = Constants.Hotkey.defaultModifiers

    private var hotKey: HotKey?
    private var onToggleRecording: (() -> Void)?

    private init() {
        loadSavedHotkey()
    }

    func configure(onToggleRecording: @escaping () -> Void) {
        self.onToggleRecording = onToggleRecording
        registerHotkey()
    }

    func registerHotkey() {
        unregisterHotkey()

        let key = Key(carbonKeyCode: currentKeyCode) ?? .space
        var modifiers: NSEvent.ModifierFlags = []

        if currentModifiers.contains(.command) {
            modifiers.insert(.command)
        }
        if currentModifiers.contains(.shift) {
            modifiers.insert(.shift)
        }
        if currentModifiers.contains(.option) {
            modifiers.insert(.option)
        }
        if currentModifiers.contains(.control) {
            modifiers.insert(.control)
        }

        hotKey = HotKey(key: key, modifiers: modifiers)
        hotKey?.keyDownHandler = { [weak self] in
            self?.onToggleRecording?()
        }

        isHotkeyRegistered = true
    }

    func unregisterHotkey() {
        hotKey = nil
        isHotkeyRegistered = false
    }

    func updateHotkey(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        currentKeyCode = keyCode
        currentModifiers = modifiers
        saveHotkey()
        registerHotkey()
    }

    private func loadSavedHotkey() {
        let defaults = UserDefaults.standard

        if let savedKeyCode = defaults.object(forKey: Constants.UserDefaults.hotkeyKeyCode) as? UInt32 {
            currentKeyCode = savedKeyCode
        }

        if let savedModifiers = defaults.object(forKey: Constants.UserDefaults.hotkeyModifiers) as? UInt {
            currentModifiers = NSEvent.ModifierFlags(rawValue: savedModifiers)
        }
    }

    private func saveHotkey() {
        let defaults = UserDefaults.standard
        defaults.set(currentKeyCode, forKey: Constants.UserDefaults.hotkeyKeyCode)
        defaults.set(currentModifiers.rawValue, forKey: Constants.UserDefaults.hotkeyModifiers)
    }

    var hotkeyDescription: String {
        var parts: [String] = []

        if currentModifiers.contains(.control) {
            parts.append("\u{2303}")
        }
        if currentModifiers.contains(.option) {
            parts.append("\u{2325}")
        }
        if currentModifiers.contains(.shift) {
            parts.append("\u{21E7}")
        }
        if currentModifiers.contains(.command) {
            parts.append("\u{2318}")
        }

        let keyName = keyCodeToString(currentKeyCode)
        parts.append(keyName)

        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Delete: return "Delete"
        case kVK_Escape: return "Esc"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_ANSI_0: return "0"
        default: return "Key\(keyCode)"
        }
    }
}
