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

        if !appState.hasCompletedOnboarding {
            logger.info("Showing onboarding")
            showOnboarding()
        } else {
            logger.info("Setting up status bar")
            StatusBarController.shared.setup()
        }
    }

    private func showOnboarding() {
        let onboardingView = OnboardingView {
            Task { @MainActor in
                AppState.shared.hasCompletedOnboarding = true
                self.onboardingWindow?.close()
                self.onboardingWindow = nil
                StatusBarController.shared.setup()
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

    @State private var currentStep = 0

    let onComplete: () -> Void

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
                    isGranted: permissionsManager.microphonePermission.isGranted,
                    action: {
                        Task {
                            await permissionsManager.requestMicrophonePermission()
                        }
                    }
                )
            }
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
                .disabled(currentStep == 1 && !permissionsManager.microphonePermission.isGranted)
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

    private func permissionCard(
        title: String,
        description: String,
        isGranted: Bool,
        action: @escaping () -> Void
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

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            } else {
                Button("Continue") {
                    action()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}
