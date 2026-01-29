import Foundation
import AppKit
import Carbon.HIToolbox

enum Constants {
    enum App {
        static let name = "Offline Speech to Text"
        static let bundleIdentifier = "com.mfaizanshaikh.speechtotext"
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
            ("auto", "Auto-detect"),
            ("af", "Afrikaans"),
            ("am", "Amharic"),
            ("ar", "Arabic"),
            ("as", "Assamese"),
            ("az", "Azerbaijani"),
            ("ba", "Bashkir"),
            ("be", "Belarusian"),
            ("bg", "Bulgarian"),
            ("bn", "Bengali"),
            ("bo", "Tibetan"),
            ("br", "Breton"),
            ("bs", "Bosnian"),
            ("ca", "Catalan"),
            ("cs", "Czech"),
            ("cy", "Welsh"),
            ("da", "Danish"),
            ("de", "German"),
            ("el", "Greek"),
            ("en", "English"),
            ("es", "Spanish"),
            ("et", "Estonian"),
            ("eu", "Basque"),
            ("fa", "Persian"),
            ("fi", "Finnish"),
            ("fo", "Faroese"),
            ("fr", "French"),
            ("gl", "Galician"),
            ("gu", "Gujarati"),
            ("ha", "Hausa"),
            ("haw", "Hawaiian"),
            ("he", "Hebrew"),
            ("hi", "Hindi"),
            ("hr", "Croatian"),
            ("ht", "Haitian Creole"),
            ("hu", "Hungarian"),
            ("hy", "Armenian"),
            ("id", "Indonesian"),
            ("is", "Icelandic"),
            ("it", "Italian"),
            ("ja", "Japanese"),
            ("jw", "Javanese"),
            ("ka", "Georgian"),
            ("kk", "Kazakh"),
            ("km", "Khmer"),
            ("kn", "Kannada"),
            ("ko", "Korean"),
            ("la", "Latin"),
            ("lb", "Luxembourgish"),
            ("ln", "Lingala"),
            ("lo", "Lao"),
            ("lt", "Lithuanian"),
            ("lv", "Latvian"),
            ("mg", "Malagasy"),
            ("mi", "Maori"),
            ("mk", "Macedonian"),
            ("ml", "Malayalam"),
            ("mn", "Mongolian"),
            ("mr", "Marathi"),
            ("ms", "Malay"),
            ("mt", "Maltese"),
            ("my", "Myanmar"),
            ("ne", "Nepali"),
            ("nl", "Dutch"),
            ("nn", "Nynorsk"),
            ("no", "Norwegian"),
            ("oc", "Occitan"),
            ("pa", "Punjabi"),
            ("pl", "Polish"),
            ("ps", "Pashto"),
            ("pt", "Portuguese"),
            ("ro", "Romanian"),
            ("ru", "Russian"),
            ("sa", "Sanskrit"),
            ("sd", "Sindhi"),
            ("si", "Sinhala"),
            ("sk", "Slovak"),
            ("sl", "Slovenian"),
            ("sn", "Shona"),
            ("so", "Somali"),
            ("sq", "Albanian"),
            ("sr", "Serbian"),
            ("su", "Sundanese"),
            ("sv", "Swedish"),
            ("sw", "Swahili"),
            ("ta", "Tamil"),
            ("te", "Telugu"),
            ("tg", "Tajik"),
            ("th", "Thai"),
            ("tk", "Turkmen"),
            ("tl", "Tagalog"),
            ("tr", "Turkish"),
            ("tt", "Tatar"),
            ("uk", "Ukrainian"),
            ("ur", "Urdu"),
            ("uz", "Uzbek"),
            ("vi", "Vietnamese"),
            ("yi", "Yiddish"),
            ("yo", "Yoruba"),
            ("yue", "Cantonese"),
            ("zh", "Chinese")
        ]
    }

    enum UI {
        static let overlayWidth: CGFloat = 400
        static let overlayHeight: CGFloat = 150
        static let overlayCornerRadius: CGFloat = 12
        static let statusBarIconSize: CGFloat = 18
    }
}
