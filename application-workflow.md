SpeechToText Application Workflow
This is a macOS menu bar app for universal speech-to-text using WhisperKit (on-device AI). Here's the complete workflow:

1. Application Startup

AppDelegate (@main entry point)
    │
    ├── Check hasCompletedOnboarding flag
    │
    ├── [FIRST RUN] → Show Onboarding Window
    │   ├── Step 1: Welcome screen
    │   ├── Step 2: Request permissions (Microphone + Accessibility)
    │   └── Step 3: Download Whisper model
    │
    └── [NORMAL RUN] → StatusBarController.setup()
        ├── Create menu bar icon
        ├── Configure global hotkey (Cmd+Shift+Space)
        └── Load Whisper model via WhisperManager
2. Core Components
Component	Location	Role
AppState	AppState.swift	Central state hub with @Published properties
StatusBarController	StatusBarController.swift	Orchestrates UI, recording, and overlay
WhisperManager	WhisperManager.swift	Audio capture + WhisperKit transcription
HotkeyManager	HotkeyManager.swift	Global keyboard shortcut handling
TextInsertionService	TextInsertionService.swift	Insert text at cursor via Accessibility API
PermissionsManager	PermissionsManager.swift	Track microphone & accessibility permissions
3. Recording & Transcription Flow

User presses Cmd+Shift+Space
        │
        ▼
HotkeyManager → StatusBarController.toggleRecording()
        │
        ├── [START RECORDING]
        │   ├── AppState.recordingState = .recording
        │   ├── Show overlay window (TranscriptionOverlayView)
        │   └── WhisperManager.startRecording()
        │       ├── Create AVAudioEngine
        │       ├── Configure: 16kHz, PCM Float32, mono
        │       └── Accumulate audio samples in buffer
        │
        └── [STOP RECORDING] (press hotkey again)
            ├── AppState.recordingState = .processing
            ├── WhisperManager.stopRecording()
            │   ├── Stop audio engine
            │   └── transcribeAudio() → WhisperKit.transcribe()
            │       └── Returns TranscriptionResult
            │
            ├── TextInsertionService.insertText()
            │   ├── Try: Accessibility API (AXUIElement)
            │   └── Fallback: Clipboard + Cmd+V simulation
            │
            ├── Hide overlay
            └── AppState.recordingState = .idle
4. State Machine
Model States (ModelState enum):


notLoaded → downloading(progress) → loading → ready
                                          ↘ error(message)
Recording States (RecordingState enum):


idle ⟷ recording → processing → idle
5. Component Interaction Diagram

┌─────────────────────────────────────────────────────────────┐
│                        AppDelegate                          │
│                     (Entry Point @main)                     │
└─────────────────────────┬───────────────────────────────────┘
                          │ setup()
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                   StatusBarController                        │
│         (Orchestrator - Menu Bar + Recording Flow)          │
├─────────────────────────────────────────────────────────────┤
│  - Creates menu bar icon                                     │
│  - Handles left-click (toggle recording)                     │
│  - Handles right-click (show menu)                           │
│  - Manages overlay window                                    │
└────┬─────────────────┬─────────────────┬────────────────────┘
     │                 │                 │
     ▼                 ▼                 ▼
┌──────────┐    ┌─────────────┐    ┌──────────────────┐
│ Hotkey   │    │  Whisper    │    │ TextInsertion    │
│ Manager  │    │  Manager    │    │ Service          │
├──────────┤    ├─────────────┤    ├──────────────────┤
│ Global   │    │ AVAudio     │    │ Accessibility    │
│ shortcut │    │ Engine +    │    │ API or Clipboard │
│ Cmd+Shift│    │ WhisperKit  │    │ fallback         │
│ +Space   │    │ transcribe  │    │                  │
└──────────┘    └─────────────┘    └──────────────────┘
     │                 │                 ▲
     │                 │                 │
     └────────┬────────┴─────────────────┘
              ▼
┌─────────────────────────────────────────────────────────────┐
│                        AppState                              │
│              (Central Observable State Hub)                  │
├─────────────────────────────────────────────────────────────┤
│  @Published modelState, recordingState, currentTranscription │
│  @AppStorage selectedModel, selectedLanguage, etc.          │
└─────────────────────────────────────────────────────────────┘
              ▲
              │ SwiftUI binding
              ▼
┌─────────────────────────────────────────────────────────────┐
│                         Views                                │
│  StatusBarMenu │ TranscriptionOverlay │ SettingsView        │
└─────────────────────────────────────────────────────────────┘
6. Key Files
Purpose	File
Entry point	AppDelegate.swift
Main orchestrator	StatusBarController.swift
Speech recognition	WhisperManager.swift
Central state	AppState.swift
Config constants	Constants.swift
The architecture follows a clean singleton pattern with centralized state management via AppState, making it easy to track and debug the application flow.