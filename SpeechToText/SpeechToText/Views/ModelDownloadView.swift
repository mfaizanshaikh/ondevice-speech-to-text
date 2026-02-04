import SwiftUI

struct ModelDownloadView: View {
    @ObservedObject private var whisperManager = WhisperManager.shared
    @ObservedObject private var appState = AppState.shared

    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            headerSection

            modelInfoSection

            progressSection

            actionSection
        }
        .padding(32)
        .frame(width: 450, height: 350)
    }

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
        }
    }

    private var modelInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Selected Model:")
                Spacer()
                Text(Constants.WhisperModel.modelDescription(appState.selectedModel))
                    .fontWeight(.medium)
            }

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
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }

    private var progressSection: some View {
        VStack(spacing: 8) {
            if case .downloading(let progress) = whisperManager.modelState {
                ProgressView(value: progress) {
                    HStack {
                        Text("Downloading...")
                        Spacer()
                        Text("\(Int(progress * 100))%")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            } else if case .loading = whisperManager.modelState {
                ProgressView()
                Text("Loading model...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if case .error(let message) = whisperManager.modelState {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.red)
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
        HStack(spacing: 16) {
            if whisperManager.modelState.isReady {
                Button("Continue") {
                    appState.skippedModelDownload = false
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else if whisperManager.modelState.isLoading {
                Button("Downloading...") {}
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(true)
            } else {
                Button("Download Model") {
                    appState.skippedModelDownload = false
                    Task {
                        await whisperManager.loadModel(appState.selectedModel)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Skip for Now") {
                    appState.skippedModelDownload = true
                    onComplete()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
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
