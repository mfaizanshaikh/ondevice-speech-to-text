import Foundation
import SwiftUI

enum ModelState: Equatable {
    case notLoaded
    case downloading(progress: Double)
    case loading
    case ready
    case error(String)

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }

    var isLoading: Bool {
        switch self {
        case .downloading, .loading:
            return true
        default:
            return false
        }
    }

    var statusText: String {
        switch self {
        case .notLoaded:
            return "Model not loaded"
        case .downloading(let progress):
            return "Downloading... \(Int(progress * 100))%"
        case .loading:
            return "Loading model..."
        case .ready:
            return "Ready"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

enum RecordingState: Equatable {
    case idle
    case recording
    case processing

    var statusText: String {
        switch self {
        case .idle:
            return "Ready"
        case .recording:
            return "Recording..."
        case .processing:
            return "Processing..."
        }
    }

    var iconName: String {
        switch self {
        case .idle:
            return "mic"
        case .recording:
            return "mic.fill"
        case .processing:
            return "waveform"
        }
    }
}

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var modelState: ModelState = .notLoaded
    @Published var recordingState: RecordingState = .idle
    @Published var currentTranscription: String = ""
    @Published var showOverlay: Bool = false
    @Published var showSettings: Bool = false
    @Published var showOnboarding: Bool = false
    @Published var showClipboardToast: Bool = false

    @AppStorage(Constants.UserDefaults.selectedModel)
    var selectedModel: String = Constants.WhisperModel.defaultModel

    @AppStorage(Constants.UserDefaults.selectedLanguage)
    var selectedLanguage: String = Constants.Language.defaultLanguage

    @AppStorage(Constants.UserDefaults.launchAtLogin)
    var launchAtLogin: Bool = false

    @AppStorage(Constants.UserDefaults.hasCompletedOnboarding)
    var hasCompletedOnboarding: Bool = false

    @AppStorage(Constants.UserDefaults.skippedModelDownload)
    var skippedModelDownload: Bool = false

    var isRecording: Bool {
        recordingState == .recording
    }

    var canRecord: Bool {
        modelState.isReady && recordingState == .idle
    }

    private init() {}

    func reset() {
        currentTranscription = ""
        recordingState = .idle
        showOverlay = false
    }
}
