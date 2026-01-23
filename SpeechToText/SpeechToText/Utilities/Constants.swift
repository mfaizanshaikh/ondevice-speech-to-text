import Foundation
import AppKit
import Carbon.HIToolbox

enum Constants {
    enum App {
        static let name = "SpeechToText"
        static let bundleIdentifier = "com.speechtotext.app"
    }

    enum Hotkey {
        static let defaultKeyCode = UInt32(kVK_Space)
        static let defaultModifiers: NSEvent.ModifierFlags = [.command, .shift]
    }

    enum WhisperModel {
        static let defaultModel = "large-v3"
        static let availableModels = ["tiny", "base", "small", "large-v3"]

        static func modelDescription(_ model: String) -> String {
            switch model {
            case "tiny":
                return "Tiny (75MB) - Fastest, Good accuracy"
            case "base":
                return "Base (142MB) - Fast, Better accuracy"
            case "small":
                return "Small (466MB) - Medium speed, Great accuracy"
            case "large-v3":
                return "Large v3 (2.9GB) - Best accuracy (Recommended)"
            default:
                return model
            }
        }
    }

    enum UserDefaults {
        static let selectedModel = "selectedWhisperModel"
        static let selectedLanguage = "selectedLanguage"
        static let launchAtLogin = "launchAtLogin"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    enum Language {
        static let defaultLanguage = "en"
        static let availableLanguages: [(code: String, name: String)] = [
            ("en", "English"),
            ("es", "Spanish"),
            ("fr", "French"),
            ("de", "German"),
            ("it", "Italian"),
            ("pt", "Portuguese"),
            ("nl", "Dutch"),
            ("pl", "Polish"),
            ("ru", "Russian"),
            ("ja", "Japanese"),
            ("ko", "Korean"),
            ("zh", "Chinese"),
            ("ar", "Arabic"),
            ("hi", "Hindi"),
            ("auto", "Auto-detect")
        ]
    }

    enum UI {
        static let overlayWidth: CGFloat = 400
        static let overlayHeight: CGFloat = 150
        static let overlayCornerRadius: CGFloat = 12
        static let statusBarIconSize: CGFloat = 18
    }
}
