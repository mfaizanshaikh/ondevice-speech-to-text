import SwiftUI

struct ModelDownloadView: View {
    @ObservedObject private var whisperManager = WhisperManager.shared
    @ObservedObject private var appState = AppState.shared

    @State private var downloadStartTime: Date?
    @State private var elapsedTimeText: String = ""
    @State private var elapsedTimer: Timer?

    let onComplete: () -> Void
    var showSkip: Bool = true

    var body: some View {
        VStack(spacing: 24) {
            headerSection

            modelInfoSection

            progressSection

            actionSection
        }
        .padding(32)
        .frame(width: 450, height: 400)
        .onAppear {
            autoStartDownloadIfNeeded()
        }
        .onDisappear {
            stopElapsedTimer()
        }
        .onChange(of: whisperManager.modelState) { _, newState in
            if newState.isLoading {
                startElapsedTimer()
            } else {
                stopElapsedTimer()
            }
        }
    }

    // MARK: - Auto Download

    private func autoStartDownloadIfNeeded() {
        // Only auto-load if the model is already cached on disk (no download needed)
        // For new downloads, the user must explicitly tap "Download Model" to consent
        guard !whisperManager.modelState.isReady,
              !whisperManager.modelState.isLoading,
              !isErrorState else { return }

        guard whisperManager.modelExistsOnDisk(appState.selectedModel) else { return }

        Task {
            await whisperManager.loadModel(appState.selectedModel)
        }
    }

    private var isErrorState: Bool {
        if case .error = whisperManager.modelState { return true }
        return false
    }

    // MARK: - Elapsed Time

    private func startElapsedTimer() {
        downloadStartTime = Date()
        elapsedTimeText = "0:00"
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard let start = downloadStartTime else { return }
            let elapsed = Int(Date().timeIntervalSince(start))
            let minutes = elapsed / 60
            let seconds = elapsed % 60
            elapsedTimeText = String(format: "%d:%02d", minutes, seconds)
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    // MARK: - View Sections

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Download Whisper Model")
                .font(.title2)
                .fontWeight(.bold)

            Text("Offline Speech to Text uses WhisperKit for high-accuracy, offline speech recognition.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var modelInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Model Picker
            HStack {
                Text("Select Model:")
                Spacer()
                Picker("", selection: $appState.selectedModel) {
                    ForEach(Constants.WhisperModel.availableModels, id: \.self) { model in
                        Text(modelPickerLabel(model)).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 200)
                .disabled(whisperManager.modelState.isLoading)
            }

            Divider()

            HStack {
                Text("Download Size:")
                Spacer()
                Text(modelSize)
                    .fontWeight(.medium)
            }

            HStack {
                Text("Memory Usage:")
                Spacer()
                Text(memoryUsage)
                    .fontWeight(.medium)
            }

            // Network status indicator
            if !whisperManager.isNetworkAvailable && !whisperManager.modelExistsOnDisk(appState.selectedModel) {
                HStack(spacing: 6) {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("No internet connection. Required for first-time model download.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.top, 4)
            } else if whisperManager.modelExistsOnDisk(appState.selectedModel) && !whisperManager.modelState.isLoading {
                HStack(spacing: 6) {
                    Image(systemName: "internaldrive")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Model cached on disk. No download needed.")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }

    private func modelPickerLabel(_ model: String) -> String {
        switch model {
        case "tiny": return "Tiny - Fastest"
        case "base": return "Base - Fast"
        case "small": return "Small - Balanced"
        case "large-v3": return "Large v3 - Best (Recommended)"
        default: return model
        }
    }

    private var progressSection: some View {
        VStack(spacing: 8) {
            if case .downloading = whisperManager.modelState {
                ProgressView()
                    .controlSize(.small)
                HStack(spacing: 4) {
                    Text("Downloading model...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if !elapsedTimeText.isEmpty {
                        Text("(\(elapsedTimeText) elapsed)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Text("This may take several minutes for larger models.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else if case .loadingFromCache = whisperManager.modelState {
                ProgressView()
                    .controlSize(.small)
                HStack(spacing: 4) {
                    Text("Loading model from cache...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if !elapsedTimeText.isEmpty {
                        Text("(\(elapsedTimeText) elapsed)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else if case .loading = whisperManager.modelState {
                ProgressView()
                    .controlSize(.small)
                HStack(spacing: 4) {
                    Text("Loading model into memory...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if !elapsedTimeText.isEmpty {
                        Text("(\(elapsedTimeText) elapsed)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else if case .error(let message) = whisperManager.modelState {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if case .ready = whisperManager.modelState {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Model ready!")
                        .foregroundColor(.green)
                }
            }
        }
    }

    private var actionSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                if whisperManager.modelState.isReady {
                    Button("Continue") {
                        appState.skippedModelDownload = false
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else if whisperManager.modelState.isLoading {
                    Button("Loading...") {}
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(true)
                } else if case .error = whisperManager.modelState {
                    Button("Try Again") {
                        Task {
                            await whisperManager.loadModel(appState.selectedModel)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button(whisperManager.modelExistsOnDisk(appState.selectedModel) ? "Load Model" : "Download Model") {
                        Task {
                            await whisperManager.loadModel(appState.selectedModel)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!whisperManager.isNetworkAvailable && !whisperManager.modelExistsOnDisk(appState.selectedModel))
                }
            }

            // Skip option - allows completing onboarding without model
            if showSkip && !whisperManager.modelState.isReady && !whisperManager.modelState.isLoading {
                Button("Skip for Now") {
                    whisperManager.cancelModelLoad()
                    appState.skippedModelDownload = true
                    onComplete()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }

    private var modelSize: String {
        switch appState.selectedModel {
        case "tiny": return "~75 MB"
        case "base": return "~142 MB"
        case "small": return "~466 MB"
        case "large-v3": return "~2.9 GB"
        default: return "Unknown"
        }
    }

    private var memoryUsage: String {
        switch appState.selectedModel {
        case "tiny": return "~400 MB"
        case "base": return "~500 MB"
        case "small": return "~900 MB"
        case "large-v3": return "~4 GB"
        default: return "Unknown"
        }
    }
}
