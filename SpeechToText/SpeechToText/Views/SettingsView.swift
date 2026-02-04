import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var whisperManager = WhisperManager.shared
    @ObservedObject private var permissionsManager = PermissionsManager.shared
    @ObservedObject private var hotkeyManager = HotkeyManager.shared

    @State private var selectedTab = 0

    // Languages sorted alphabetically with Auto-detect first
    private var sortedLanguages: [(code: String, name: String)] {
        Constants.Language.availableLanguages.sorted { first, second in
            if first.code == "auto" { return true }
            if second.code == "auto" { return false }
            return first.name < second.name
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(0)

            modelTab
                .tabItem {
                    Label("Model", systemImage: "brain")
                }
                .tag(1)

            permissionsTab
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }
                .tag(2)

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(3)
        }
        .padding(20)
        .frame(width: 500, height: 400)
    }

    private var generalTab: some View {
        Form {
            Section("Hotkey") {
                HStack {
                    Text("Current Hotkey:")
                    Spacer()
                    Text(hotkeyManager.hotkeyDescription)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(6)
                }

                Text("Press Cmd+Shift+Space to start/stop recording")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Language") {
                Picker("Transcription Language:", selection: $appState.selectedLanguage) {
                    ForEach(sortedLanguages, id: \.code) { language in
                        Text(language.name).tag(language.code)
                    }
                }
            }

            Section("Startup") {
                Toggle("Launch at Login", isOn: $appState.launchAtLogin)
                    .onChange(of: appState.launchAtLogin) { _, newValue in
                        updateLaunchAtLogin(newValue)
                    }
            }
        }
        .formStyle(.grouped)
    }

    private var modelTab: some View {
        Form {
            Section("Whisper Model") {
                Picker("Model:", selection: $appState.selectedModel) {
                    ForEach(Constants.WhisperModel.availableModels, id: \.self) { model in
                        Text(Constants.WhisperModel.modelDescription(model))
                            .tag(model)
                    }
                }

                HStack {
                    Text("Status:")
                    Spacer()
                    statusBadge
                }

                if case .downloading(let progress) = whisperManager.modelState {
                    ProgressView(value: progress) {
                        Text("Downloading: \(Int(progress * 100))%")
                    }
                }
            }

            Section {
                Button(action: {
                    appState.skippedModelDownload = false
                    Task {
                        await whisperManager.loadModel(appState.selectedModel)
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text("Download / Load Model")
                    }
                }
                .disabled(whisperManager.modelState.isLoading)
            }

            Section("About Models") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Models are downloaded from Hugging Face and cached locally.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("large-v3 is recommended for best accuracy on M4 Max.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("All processing happens locally - no data is sent to the cloud.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var permissionsTab: some View {
        Form {
            Section("Required Permissions") {
                permissionRow(
                    title: "Microphone",
                    description: "Required to capture your voice for transcription",
                    isGranted: permissionsManager.microphonePermission.isGranted,
                    action: {
                        Task {
                            await permissionsManager.requestMicrophonePermission()
                        }
                    },
                    openSettings: permissionsManager.openMicrophonePreferences
                )
            }

            Section {
                Button("Refresh Permissions") {
                    permissionsManager.checkAllPermissions()
                }
            }
        }
        .formStyle(.grouped)
    }

    private var aboutTab: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("Offline Speech to Text")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Universal speech-to-text for macOS")
                    .font(.headline)

                Text("Powered by WhisperKit with Whisper large-v3 model")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("100% offline - all processing happens on your device")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()

            Spacer()

            VStack(spacing: 4) {
                Text("Developed by Faizan Shaikh")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\u{00A9} 2026 Faizan Shaikh. All rights reserved.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(whisperManager.modelState.statusText)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.2))
        .cornerRadius(8)
    }

    private var statusColor: Color {
        switch whisperManager.modelState {
        case .ready:
            return .green
        case .downloading, .loading:
            return .orange
        case .error:
            return .red
        case .notLoaded:
            return .gray
        }
    }

    private func permissionRow(
        title: String,
        description: String,
        isGranted: Bool,
        action: @escaping () -> Void,
        openSettings: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.headline)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Button("Continue") {
                        action()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }

            if !isGranted {
                Button("Open System Settings") {
                    openSettings()
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }
}
