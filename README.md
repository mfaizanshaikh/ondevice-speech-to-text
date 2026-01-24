# On Device Speech To Text

A macOS menu bar application that provides universal, on-device speech-to-text transcription powered by [OpenAI Whisper](https://github.com/openai/whisper). Transcribe speech in any application with a global hotkey, all processing happens locally on your Mac with zero data sent to the cloud.

## Features

- **100% Offline** - All transcription happens on-device using Apple's Neural Engine
- **Universal Text Insertion** - Transcribed text is automatically inserted at your cursor position in any app
- **Global Hotkey** - Start/stop recording from anywhere with Cmd+Shift+Space
- **Multiple Whisper Models** - Choose from tiny, base, small, or large-v3 based on your accuracy/speed needs
- **99 Languages Supported** - Transcribe speech in virtually any language
- **Minimal & Native** - Runs quietly in your menu bar with a native macOS UI

## Requirements

- **macOS 14 (Sonoma)** or later
- **Apple Silicon Mac** (M1, M2, M3, or M4)
- RAM requirements depend on model size:
  - Tiny/Base: 4GB minimum
  - Small: 8GB minimum
  - Large-v3: 16GB recommended

> **Note:** Intel Macs are not supported due to WhisperKit's reliance on Apple's Neural Engine for optimal performance.

## Installation

### Download Release

Download the latest release from the [Releases](../../releases) page.

### Build from Source

```bash
# Clone the repository
git clone https://github.com/mfaizanshaikh/ondevice-speech-to-text.git
cd SpeechToText/SpeechToText

# Build the project
swift build -c release

# Run the app
swift run SpeechToText
```

Or open `SpeechToText.xcodeproj` in Xcode and build directly.

## Usage

### First Launch

1. **Welcome** - Launch the app and complete the onboarding wizard
2. **Permissions** - Grant microphone access and accessibility permissions
3. **Model Download** - Select and download a Whisper model (large-v3 recommended for best accuracy)

### Recording

1. Press **Cmd+Shift+Space** to start recording
2. Speak your text
3. Press the hotkey again (or click the checkmark) to stop and transcribe
4. Text is automatically inserted at your cursor position

### Menu Bar

- **Left-click** the menu bar icon to toggle recording
- **Right-click** to access settings and quit

## Settings

Access settings via right-click menu or **Cmd+,**:

| Tab | Options |
|-----|---------|
| **General** | Hotkey configuration, language selection, launch at login |
| **Model** | Download/switch Whisper models, view model status |
| **Permissions** | Manage microphone and accessibility permissions |
| **About** | App version and information |

## Whisper Models

| Model | Download Size | RAM Usage | Speed | Accuracy |
|-------|--------------|-----------|-------|----------|
| tiny | 75 MB | ~400 MB | Fastest | Good |
| base | 142 MB | ~500 MB | Fast | Better |
| small | 466 MB | ~900 MB | Medium | Great |
| large-v3 | 2.9 GB | ~4 GB | Slower | Best |

Models are downloaded to `~/Library/Application Support/SpeechToText/Models/` and cached for future use.

## Supported Languages

The app supports **99 languages** plus auto-detection:

| | | | | |
|---|---|---|---|---|
| Afrikaans | Amharic | Arabic | Assamese | Azerbaijani |
| Bashkir | Belarusian | Bengali | Bosnian | Breton |
| Bulgarian | Cantonese | Catalan | Chinese | Croatian |
| Czech | Danish | Dutch | English | Estonian |
| Faroese | Finnish | French | Galician | Georgian |
| German | Greek | Gujarati | Haitian Creole | Hausa |
| Hawaiian | Hebrew | Hindi | Hungarian | Icelandic |
| Indonesian | Italian | Japanese | Javanese | Kannada |
| Kazakh | Khmer | Korean | Lao | Latin |
| Latvian | Lingala | Lithuanian | Luxembourgish | Macedonian |
| Malagasy | Malay | Malayalam | Maltese | Maori |
| Marathi | Mongolian | Myanmar | Nepali | Norwegian |
| Nynorsk | Occitan | Pashto | Persian | Polish |
| Portuguese | Punjabi | Romanian | Russian | Sanskrit |
| Serbian | Shona | Sindhi | Sinhala | Slovak |
| Slovenian | Somali | Spanish | Sundanese | Swahili |
| Swedish | Tagalog | Tajik | Tamil | Tatar |
| Telugu | Thai | Tibetan | Turkish | Turkmen |
| Ukrainian | Urdu | Uzbek | Vietnamese | Welsh |
| Yiddish | Yoruba | | | |

## Architecture

```
SpeechToText/
├── Application/          # App entry point and lifecycle
├── Core/
│   ├── Controllers/      # StatusBarController - main orchestrator
│   ├── Managers/         # WhisperManager, HotkeyManager, PermissionsManager
│   └── Models/           # AppState, TranscriptionResult
├── Views/                # SwiftUI views (overlay, settings, menu)
├── Extensions/           # Accessibility API helpers
└── Utilities/            # Constants and configuration
```

### Key Components

- **StatusBarController** - Manages menu bar icon, recording lifecycle, and UI windows
- **WhisperManager** - Handles audio capture (16kHz, PCM Float32) and WhisperKit transcription
- **TextInsertionService** - Inserts text via Accessibility API with clipboard fallback
- **HotkeyManager** - Global hotkey registration using Carbon events

## Permissions

The app requires the following permissions:

| Permission | Purpose |
|------------|---------|
| **Microphone** | Capture audio for transcription |
| **Accessibility** | Insert text at cursor position in any application |

If accessibility permission is denied, the app falls back to copying text to clipboard and simulating Cmd+V.

## Dependencies

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) (0.9.0+) - On-device Whisper speech recognition
- [HotKey](https://github.com/soffes/HotKey) (0.2.0+) - Global keyboard shortcut registration

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) by Argmax for the incredible on-device Whisper implementation
- [OpenAI Whisper](https://github.com/openai/whisper) for the speech recognition model