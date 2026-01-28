# On Device Speech To Text

A macOS menu bar application that provides universal, on-device speech-to-text transcription powered by [OpenAI Whisper](https://github.com/openai/whisper). Transcribe speech in any application with a global hotkey, all processing happens locally on your Mac with zero data sent to the cloud.

## Demo

[![Demo Video](https://img.youtube.com/vi/OUA0MoNb3do/0.jpg)](https://youtu.be/OUA0MoNb3do)

## Features

- **100% Offline** - All transcription happens on-device using Apple's Neural Engine
- **Universal Text Insertion** - Transcribed text is automatically inserted at your cursor position in any app
- **Global Hotkey** - Start/stop recording from anywhere with Cmd+Shift+Space
- **Multiple Whisper Models** - Choose from tiny, base, small, or large-v3 based on your accuracy/speed needs
- **99 Languages Supported** - Transcribe speech in virtually any language

## Requirements

- **macOS 14 (Sonoma)** or later
- **Apple Silicon Mac** (M1, M2, M3, or M4)

> **Note:** Intel Macs are not supported due to WhisperKit's reliance on Apple's Neural Engine for optimal performance.

## Installation

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
- **WhisperManager** - Handles audio capture and WhisperKit transcription
- **TextInsertionService** - Inserts text via Accessibility API with clipboard fallback
- **HotkeyManager** - Global hotkey registration

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) by Argmax for the incredible on-device Whisper implementation
- [OpenAI Whisper](https://github.com/openai/whisper) for the speech recognition model