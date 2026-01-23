# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build the project using Swift Package Manager
cd SpeechToText
swift build

# Build for release
swift build -c release

# Run the app (after building)
swift run SpeechToText

# Run tests
swift test
```

## Architecture Overview

SpeechToText is a macOS menu bar application that provides universal speech-to-text using WhisperKit (on-device Whisper model). The app runs as a background process (`LSUIElement=true`) with no dock icon.

### Core Components

**Application Layer** (`Application/`)
- `AppDelegate.swift` - Entry point (`@main`). Handles app lifecycle, checks onboarding status via `AppState.shared.hasCompletedOnboarding`, and shows either onboarding flow or initializes the status bar. Contains embedded `OnboardingView` struct for first-run setup.

**Controllers** (`Core/Controllers/`)
- `StatusBarController` - Singleton managing the menu bar icon, context menu, recording lifecycle, overlay window, and settings window. Left-click toggles recording; right-click shows menu.

**Managers** (`Core/Managers/`)
- `WhisperManager` - Singleton handling WhisperKit initialization, model download/loading, audio recording via `AVAudioEngine`, and transcription. Uses 16kHz sample rate with PCM Float32 format.
- `PermissionsManager` - Singleton tracking microphone (AVFoundation) and accessibility (AXIsProcessTrusted) permissions.
- `HotkeyManager` - Singleton for global hotkey registration using the HotKey library. Default: Cmd+Shift+Space.
- `TextInsertionService` - Singleton that inserts transcribed text at cursor position using Accessibility APIs, with clipboard fallback.

**Models** (`Core/Models/`)
- `AppState` - Singleton with `@Published` properties for model state, recording state, transcription, and user preferences (stored via `@AppStorage`).
- `ModelState` / `RecordingState` - Enums defining possible states with computed properties for status text and icons.
- `TranscriptionResult` - Struct holding transcription output with metadata.

### Data Flow

1. User presses global hotkey (Cmd+Shift+Space)
2. `HotkeyManager` triggers `StatusBarController.toggleRecording()`
3. `WhisperManager.startRecording()` captures audio via `AVAudioEngine`
4. On stop, audio buffers are sent to WhisperKit for transcription
5. `TextInsertionService` attempts to insert text via Accessibility API, falls back to clipboard

### Key Dependencies

- **WhisperKit** (0.9.0+) - On-device speech recognition with Whisper models
- **HotKey** (0.2.0+) - Global keyboard shortcut registration

### Entitlements

App sandbox is disabled to allow accessibility APIs. Required entitlements:
- `com.apple.security.device.audio-input` - Microphone access
- `com.apple.security.files.user-selected.read-write` - File access
- `com.apple.security.network.client` - Network for model downloads

### Configuration

User preferences stored in `UserDefaults` via keys in `Constants.UserDefaults`:
- `selectedWhisperModel` - Whisper model variant (default: "large-v3")
- `selectedLanguage` - Transcription language (default: "en")
- `hasCompletedOnboarding` - First-run flag
- `hotkeyKeyCode` / `hotkeyModifiers` - Custom hotkey settings

Available models: tiny, base, small, large-v3 (defined in `Constants.WhisperModel`)
