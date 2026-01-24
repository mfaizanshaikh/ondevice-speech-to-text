import SwiftUI

struct TranscriptionOverlayView: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var whisperManager = WhisperManager.shared

    var body: some View {
        VStack(spacing: 12) {
            headerView

            transcriptionView

            footerView
        }
        .padding(16)
        .frame(width: Constants.UI.overlayWidth, height: Constants.UI.overlayHeight)
        .background(backgroundView)
    }

    private var headerView: some View {
        HStack {
            recordingIndicator

            Text(appState.recordingState.statusText)
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            Button(action: {
                whisperManager.cancelRecording()
                appState.reset()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var recordingIndicator: some View {
        Circle()
            .fill(indicatorColor)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(indicatorColor.opacity(0.5), lineWidth: 2)
                    .scaleEffect(appState.isRecording ? 1.5 : 1)
                    .opacity(appState.isRecording ? 0 : 1)
                    .animation(
                        appState.isRecording ?
                            Animation.easeOut(duration: 1).repeatForever(autoreverses: false) :
                            .default,
                        value: appState.isRecording
                    )
            )
    }

    private var transcriptionView: some View {
        ScrollView {
            if appState.currentTranscription.isEmpty && appState.recordingState == .recording {
                audioVisualizationView
            } else {
                Text(displayText)
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var audioVisualizationView: some View {
        HStack(spacing: 12) {
            AudioLevelView(audioLevel: whisperManager.audioLevel)
            Text("Listening...")
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footerView: some View {
        HStack {
            Text(HotkeyManager.shared.hotkeyDescription)
                .font(.caption)
                .foregroundColor(.secondary)

            Text("to stop")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            if appState.recordingState == .processing {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
    }

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: Constants.UI.overlayCornerRadius)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: Constants.UI.overlayCornerRadius)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
    }

    private var indicatorColor: Color {
        switch appState.recordingState {
        case .recording:
            return .red
        case .processing:
            return .orange
        case .idle:
            return .green
        }
    }

    private var displayText: String {
        if appState.currentTranscription.isEmpty {
            switch appState.recordingState {
            case .recording:
                return "Listening..."
            case .processing:
                return "Processing your speech..."
            case .idle:
                return "Ready"
            }
        }
        return appState.currentTranscription
    }
}
