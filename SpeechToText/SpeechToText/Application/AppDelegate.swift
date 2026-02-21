import Cocoa
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.mfaizanshaikh.speechtotext", category: "AppDelegate")

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var onboardingWindow: NSWindow?
    private var unsupportedArchWindow: NSWindow?

    /// Returns true if running on Intel (x86_64) Mac
    private var isAppleSilicon: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("applicationDidFinishLaunching called")

        // Check architecture before proceeding
        guard isAppleSilicon else {
            logger.error("Unsupported architecture: Intel Mac detected")
            showUnsupportedArchitectureWindow()
            return
        }

        setupApp()
    }

    func applicationWillTerminate(_ notification: Notification) {
        WhisperManager.shared.cancelRecording()
    }

    nonisolated func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    private func setupApp() {
        logger.info("setupApp called")
        let appState = AppState.shared
        let permissionsManager = PermissionsManager.shared

        permissionsManager.checkAllPermissions()
        logger.info("hasCompletedOnboarding: \(appState.hasCompletedOnboarding)")

        // Always setup status bar first
        logger.info("Setting up status bar")
        StatusBarController.shared.setup()

        if !appState.hasCompletedOnboarding {
            logger.info("Showing onboarding")
            showOnboarding()
        } else {
            logger.info("Onboarding already completed, skipping")
        }
    }

    private func showOnboarding() {
        logger.info("showOnboarding called")
        let onboardingView = OnboardingView { [weak self] in
            logger.info("Onboarding completed callback")
            // Update state immediately
            AppState.shared.hasCompletedOnboarding = true
            AppState.shared.onboardingStep = 0

            // Defer window cleanup to ensure SwiftUI view cleanup completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                logger.info("Closing onboarding window")
                self?.onboardingWindow?.close()
                self?.onboardingWindow = nil
            }
        }

        let hostingView = NSHostingView(rootView: onboardingView)

        onboardingWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        onboardingWindow?.contentView = hostingView
        onboardingWindow?.title = "Welcome to Offline Speech to Text"
        onboardingWindow?.isReleasedWhenClosed = false
        onboardingWindow?.center()
        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showUnsupportedArchitectureWindow() {
        let unsupportedView = UnsupportedArchitectureView()
        let hostingView = NSHostingView(rootView: unsupportedView)

        unsupportedArchWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        unsupportedArchWindow?.contentView = hostingView
        unsupportedArchWindow?.title = "Offline Speech to Text"
        unsupportedArchWindow?.center()
        unsupportedArchWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Quit app when window is closed
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: unsupportedArchWindow,
            queue: .main
        ) { _ in
            NSApp.terminate(nil)
        }
    }
}

struct UnsupportedArchitectureView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)

            Text("Incompatible Mac")
                .font(.title)
                .fontWeight(.bold)

            VStack(spacing: 12) {
                Text("Offline Speech to Text requires an Apple Silicon Mac (M1/M2/M3/M4).")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Your Mac has an Intel processor. WhisperKit's on-device speech recognition only runs on Apple Silicon.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)

            Spacer()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(30)
        .frame(width: 420, height: 320)
    }
}

struct OnboardingView: View {
    @ObservedObject private var permissionsManager = PermissionsManager.shared
    @ObservedObject private var whisperManager = WhisperManager.shared
    @ObservedObject private var appState = AppState.shared

    @State private var currentStep: Int

    let onComplete: () -> Void
    
    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        _currentStep = State(initialValue: AppState.shared.onboardingStep)
    }

    var body: some View {
        VStack(spacing: 0) {
            stepIndicator
                .padding(.top, 20)

            Spacer()

            stepContent
                .padding(.horizontal, 40)

            Spacer()

            navigationButtons
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
        }
        .frame(width: 550, height: 500)
        .onChange(of: currentStep) { _, newValue in
            AppState.shared.onboardingStep = newValue
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(index <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 10, height: 10)
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0:
            welcomeStep
        case 1:
            permissionsStep
        case 2:
            modelStep
        default:
            EmptyView()
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "mic.fill")
                .font(.system(size: 72))
                .foregroundColor(.accentColor)

            Text("Welcome to Offline Speech to Text")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Universal speech-to-text for macOS.\nPress Cmd+Shift+Space anywhere to transcribe your voice.")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "brain", text: "Powered by Whisper large-v3 AI model")
                featureRow(icon: "lock.shield", text: "100% offline - your voice never leaves your Mac")
                featureRow(icon: "globe", text: "99 languages supported")
                featureRow(icon: "bolt", text: "Optimized for Apple Silicon")
            }
            .padding()
        }
    }

    private var permissionsStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("Microphone Access")
                .font(.title)
                .fontWeight(.bold)

            Text("Offline Speech to Text needs microphone access to work properly.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 16) {
                permissionCard(
                    title: "Microphone",
                    description: "To capture your voice for transcription",
                    status: permissionsManager.microphonePermission,
                    requestAccess: {
                        Task {
                            await permissionsManager.requestMicrophonePermission()
                        }
                    },
                    openSettings: {
                        permissionsManager.openMicrophonePreferences()
                    }
                )
            }

            microphoneHelpText
        }
        .onAppear {
            // Start polling for permission changes when user is on this step
            permissionsManager.startMonitoringPermissions()
        }
        .onDisappear {
            permissionsManager.stopMonitoringPermissions()
        }
    }

    private var modelStep: some View {
        ModelDownloadView {
            onComplete()
        }
    }

    private var navigationButtons: some View {
        HStack {
            if currentStep > 0 {
                Button("Back") {
                    withAnimation {
                        currentStep -= 1
                    }
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if currentStep < 2 {
                Button("Continue") {
                    withAnimation {
                        currentStep += 1
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            Text(text)
                .font(.body)
            Spacer()
        }
    }

    private var microphoneHelpText: some View {
        Group {
            switch permissionsManager.microphonePermission {
            case .denied:
                VStack(spacing: 8) {
                    Text("Microphone access is currently denied. macOS will not show the permission prompt again.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 4) {
                        Text("Tap Continue to open System Settings, then:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("1. Privacy & Security > Microphone")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("2. Turn on Offline Speech to Text")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            case .notDetermined:
                Text("Click Allow Microphone to show the macOS permission prompt.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            case .granted:
                Text("Microphone access granted. You can continue.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            case .unknown:
                EmptyView()
            }
        }
    }

    private func permissionCard(
        title: String,
        description: String,
        status: PermissionsManager.PermissionStatus,
        requestAccess: @escaping () -> Void,
        openSettings: @escaping () -> Void
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if status.isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            } else {
                switch status {
                case .denied:
                    Button("Continue") {
                        openSettings()
                    }
                    .buttonStyle(.borderedProminent)
                default:
                    Button("Continue") {
                        requestAccess()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}
