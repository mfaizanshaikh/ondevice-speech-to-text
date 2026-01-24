import SwiftUI

struct TranscriptionOverlayView: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var whisperManager = WhisperManager.shared
    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer?
    @State private var isVisible: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            headerView

            transcriptionView

            footerView
        }
        .padding(16)
        .frame(width: Constants.UI.overlayWidth, height: Constants.UI.overlayHeight)
        .background(backgroundView)
        .scaleEffect(isVisible ? 1.0 : 0.9)
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.spring(duration: 0.25, bounce: 0.2), value: isVisible)
        .onAppear {
            startTimer()
            withAnimation {
                isVisible = true
            }
        }
        .onDisappear {
            stopTimer()
            isVisible = false
        }
        .onChange(of: appState.recordingState) { _, newState in
            if newState == .recording {
                elapsedSeconds = 0
                startTimer()
            } else {
                stopTimer()
            }
        }
    }

    private func startTimer() {
        stopTimer()
        elapsedSeconds = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedSeconds += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private var formattedElapsedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var headerView: some View {
        HStack {
            recordingIndicator

            Text(appState.recordingState.statusText)
                .font(.headline)
                .foregroundColor(.primary)

            if appState.recordingState == .recording {
                Text(formattedElapsedTime)
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            if appState.recordingState == .recording {
                Button(action: {
                    StatusBarController.shared.toggleRecording()
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                .help("Stop and transcribe")
            }

            Button(action: {
                StatusBarController.shared.cancelRecording()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Cancel recording")
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
        VStack(spacing: 8) {
            AudioLevelView(audioLevel: whisperManager.audioLevel)
                .frame(maxWidth: .infinity)
            Text("Listening...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
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

            languageIndicator
        }
    }

    private var languageIndicator: some View {
        Text(appState.selectedLanguage.uppercased())
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.1))
            )
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
