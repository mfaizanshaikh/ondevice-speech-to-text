import SwiftUI

struct TranscriptionOverlayView: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var whisperManager = WhisperManager.shared
    @AppStorage(Constants.UserDefaults.autoCloseOverlay) private var autoCloseOverlay: Bool = false
    @State private var elapsedSeconds: Int = 0
    @State private var recordingTimer: Timer?
    @State private var autoCloseCountdown: Int = 0
    @State private var autoCloseTimer: Timer?
    @State private var isVisible: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            headerView
                .overlay {
                    clipboardToast
                }

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
            startRecordingTimer()
            withAnimation {
                isVisible = true
            }
        }
        .onDisappear {
            stopRecordingTimer()
            stopAutoCloseTimer()
            isVisible = false
        }
        .onChange(of: appState.recordingState) { _, newState in
            if newState == .recording {
                elapsedSeconds = 0
                startRecordingTimer()
                stopAutoCloseTimer()
                appState.showClipboardToast = false
            } else if newState == .idle {
                stopRecordingTimer()
                if autoCloseOverlay && !appState.lastTranscriptionWasEmpty {
                    startAutoCloseCountdown()
                }
            } else {
                stopRecordingTimer()
            }
        }
        .onChange(of: autoCloseOverlay) { _, isOn in
            if isOn {
                if appState.recordingState == .idle && !appState.lastTranscriptionWasEmpty {
                    startAutoCloseCountdown()
                }
            } else {
                stopAutoCloseTimer()
            }
        }
    }

    // MARK: - Timers

    private func startRecordingTimer() {
        stopRecordingTimer()
        elapsedSeconds = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedSeconds += 1
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    private func startAutoCloseCountdown() {
        stopAutoCloseTimer()
        autoCloseCountdown = 6
        autoCloseTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                if autoCloseCountdown > 1 {
                    autoCloseCountdown -= 1
                } else {
                    stopAutoCloseTimer()
                    Task { @MainActor in
                        StatusBarController.shared.closeOverlay()
                    }
                }
            }
        }
    }

    private func stopAutoCloseTimer() {
        autoCloseTimer?.invalidate()
        autoCloseTimer = nil
        autoCloseCountdown = 0
    }

    // MARK: - Subviews

    private var formattedElapsedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var headerView: some View {
        HStack {
            if appState.recordingState != .idle {
                Text(appState.recordingState.statusText)
                    .font(.headline)
                    .foregroundColor(.primary)
            }

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
                        .font(.system(size: 20))
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                .help("Stop and transcribe")
            }

            if appState.recordingState == .idle {
                Button(action: {
                    stopAutoCloseTimer()
                    StatusBarController.shared.toggleRecording()
                }) {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .help("Start new recording")
            }

            Button(action: {
                if appState.recordingState == .idle {
                    stopAutoCloseTimer()
                    StatusBarController.shared.closeOverlay()
                } else {
                    StatusBarController.shared.cancelRecording()
                }
            }) {
                if autoCloseCountdown > 0 {
                    Text("\(autoCloseCountdown)")
                        .font(.system(size: 11).monospacedDigit())
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color.primary.opacity(0.1)))
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .help(appState.recordingState == .idle ? "Close" : "Cancel recording")
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
        Group {
            if appState.recordingState == .recording {
                audioVisualizationView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appState.recordingState == .processing {
                Text("Transcribing your speech...")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                // idle — only this state needs scrolling for long text
                ScrollView {
                    if appState.lastTranscriptionWasEmpty {
                        Text("You didn't speak, so there's nothing to transcribe.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if !appState.currentTranscription.isEmpty {
                        Text(appState.currentTranscription)
                            .font(.body)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                }
                .scrollIndicators(.automatic)
                .frame(maxHeight: .infinity)
            }
        }
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
        HStack(spacing: 6) {
            Text(HotkeyManager.shared.hotkeyDescription)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(appState.recordingState == .recording ? "to stop" : "to record")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            if appState.recordingState == .processing {
                ProgressView()
                    .scaleEffect(0.7)
            }

            autoCloseToggle

            languageIndicator
        }
    }

    private var autoCloseToggle: some View {
        HStack(spacing: 4) {
            Text("Auto-close")
                .font(.caption)
                .foregroundColor(.secondary)
            Toggle("", isOn: $autoCloseOverlay)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
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
            .fill(Color(NSColor.controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: Constants.UI.overlayCornerRadius)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
    }

    private var clipboardToast: some View {
        Group {
            if appState.showClipboardToast {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.caption)
                    Text("Copied to clipboard — paste with Cmd+V")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                )
                .frame(maxWidth: .infinity, alignment: .center)
                .transition(.opacity)
                .animation(.easeOut(duration: 0.2), value: appState.showClipboardToast)
            }
        }
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
}
