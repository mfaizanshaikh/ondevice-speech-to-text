import SwiftUI

struct StatusBarMenu: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var whisperManager = WhisperManager.shared
    @ObservedObject private var hotkeyManager = HotkeyManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            statusSection

            Divider()

            recordingSection

            Divider()

            actionSection
        }
        .padding(12)
        .frame(width: 250)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(appState.modelState.statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if case .downloading(let progress) = appState.modelState {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
            }
        }
    }

    private var recordingSection: some View {
        Button(action: {
            StatusBarController.shared.toggleRecording()
        }) {
            HStack {
                Image(systemName: appState.recordingState.iconName)
                    .foregroundColor(appState.isRecording ? .red : .primary)
                Text(appState.isRecording ? "Stop Recording" : "Start Recording")
                Spacer()
                Text(hotkeyManager.hotkeyDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .disabled(!appState.modelState.isReady && !appState.isRecording)
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                StatusBarController.shared.openSettings()
            }) {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings...")
                    Spacer()
                    Text("\u{2318},")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            Divider()

            Button(action: {
                NSApp.terminate(nil)
            }) {
                HStack {
                    Image(systemName: "power")
                    Text("Quit Offline Speech to Text")
                    Spacer()
                    Text("\u{2318}Q")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var statusColor: Color {
        switch appState.modelState {
        case .ready:
            return .green
        case .downloading, .loading, .loadingFromCache:
            return .orange
        case .error:
            return .red
        case .notLoaded:
            return .gray
        }
    }
}
