import Foundation
import AppKit
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.mfaizanshaikh.speechtotext", category: "StatusBarController")

@MainActor
class StatusBarController: ObservableObject {
    static let shared = StatusBarController()

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var overlayWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var modelDownloadWindow: NSWindow?

    private let appState = AppState.shared
    private let whisperManager = WhisperManager.shared
    private let hotkeyManager = HotkeyManager.shared
    private let permissionsManager = PermissionsManager.shared
    private let textInsertionService = TextInsertionService.shared

    private init() {}

    func setup() {
        createStatusItem()
        setupHotkey()
        updateStatusIcon()

        Task {
            await loadModelIfNeeded()
        }
    }

    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            let image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Offline Speech to Text")
            button.image = image
            button.image?.size = NSSize(width: Constants.UI.statusBarIconSize, height: Constants.UI.statusBarIconSize)
            if image == nil {
                button.title = "STT"
            }
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        createMenu()
    }

    private func createMenu() {
        menu = NSMenu()

        let statusMenuItem = NSMenuItem(title: "Status: Initializing...", action: nil, keyEquivalent: "")
        statusMenuItem.tag = 100
        menu?.addItem(statusMenuItem)

        menu?.addItem(NSMenuItem.separator())

        let recordItem = NSMenuItem(title: "Start Recording", action: #selector(toggleRecording), keyEquivalent: "")
        recordItem.target = self
        recordItem.tag = 101
        menu?.addItem(recordItem)

        // Dynamic action item (retry/download) - hidden by default
        let actionItem = NSMenuItem(title: "Download Model", action: #selector(retryModelDownload), keyEquivalent: "")
        actionItem.target = self
        actionItem.tag = 102
        actionItem.isHidden = true
        menu?.addItem(actionItem)

        menu?.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu?.addItem(settingsItem)

        menu?.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Offline Speech to Text", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu?.addItem(quitItem)
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        updateMenuItems()
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    private func updateMenuItems() {
        if let statusItem = menu?.item(withTag: 100) {
            statusItem.title = "Status: \(appState.modelState.statusText)"
        }

        if let recordItem = menu?.item(withTag: 101) {
            recordItem.title = appState.isRecording ? "Stop Recording" : "Start Recording"
            recordItem.isEnabled = appState.modelState.isReady || appState.isRecording
        }

        // Show/hide the action item based on model state
        if let actionItem = menu?.item(withTag: 102) {
            switch appState.modelState {
            case .error:
                actionItem.title = "Retry Model Download"
                actionItem.isHidden = false
            case .notLoaded:
                actionItem.title = "Download Model"
                actionItem.isHidden = false
            default:
                actionItem.isHidden = true
            }
        }
    }

    @objc private func retryModelDownload() {
        logger.info("User triggered model download/retry from menu")
        appState.skippedModelDownload = false
        Task {
            await whisperManager.loadModel(appState.selectedModel)
        }
    }

    private func setupHotkey() {
        hotkeyManager.configure { [weak self] in
            Task { @MainActor in
                self?.toggleRecording()
            }
        }
    }

    @objc func toggleRecording() {
        Task {
            if appState.isRecording {
                await stopRecording()
            } else {
                await startRecording()
            }
        }
    }

    func cancelRecording() {
        whisperManager.cancelRecording()
        hideOverlay()
        appState.recordingState = .idle
        appState.currentTranscription = ""
        updateStatusIcon()
    }

    private func startRecording() async {
        guard appState.modelState.isReady else {
            logger.warning("Model not ready: \(self.appState.modelState.statusText)")
            if case .error = appState.modelState {
                showModelDownloadWindow()
            } else if case .notLoaded = appState.modelState {
                showModelDownloadWindow()
            }
            // If model is still loading, do nothing — status bar icon already reflects this
            return
        }

        guard permissionsManager.microphonePermission.isGranted else {
            let granted = await permissionsManager.requestMicrophonePermission()
            guard granted else {
                showMicrophoneAlert()
                return
            }
            // Permission was just granted, continue
            return await startRecording()
        }

        appState.recordingState = .recording
        appState.currentTranscription = ""
        updateStatusIcon()
        showOverlay()

        await whisperManager.startRecording()
    }

    private func stopRecording() async {
        appState.recordingState = .processing
        updateStatusIcon()

        let result = await whisperManager.stopRecording()
        appState.currentTranscription = result.text

        logger.info("Transcription result: '\(result.text)', isEmpty: \(result.isEmpty), tooShort: \(result.tooShort)")

        if result.tooShort {
            hideOverlay()
            showRecordingTooShortAlert()
        } else if !result.isEmpty {
            let inserted = await textInsertionService.insertText(result.text)
            logger.info("Text insertion result: \(inserted)")
            if !inserted {
                appState.showClipboardToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    guard let self = self else { return }
                    self.appState.showClipboardToast = false
                    self.hideOverlay()
                }
            } else {
                hideOverlay()
            }
        } else {
            logger.info("Empty transcription, nothing to insert")
            hideOverlay()
        }

        appState.recordingState = .idle
        updateStatusIcon()
    }

    private func updateStatusIcon() {
        guard let button = statusItem?.button else { return }

        let iconName = appState.recordingState.iconName
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Offline Speech to Text")
        button.image?.size = NSSize(width: Constants.UI.statusBarIconSize, height: Constants.UI.statusBarIconSize)

        if appState.isRecording {
            button.image?.isTemplate = false
            button.contentTintColor = .systemRed
        } else {
            button.image?.isTemplate = true
            button.contentTintColor = nil
        }
    }

    private func showOverlay() {
        if overlayWindow == nil {
            let overlayView = TranscriptionOverlayView()
            let hostingView = NSHostingView(rootView: overlayView)

            // Use NSPanel with nonactivatingPanel to prevent stealing focus
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: Constants.UI.overlayWidth, height: Constants.UI.overlayHeight),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.becomesKeyOnlyIfNeeded = true
            panel.hidesOnDeactivate = false
            overlayWindow = panel

            overlayWindow?.contentView = hostingView
            overlayWindow?.isOpaque = false
            overlayWindow?.backgroundColor = .clear
            overlayWindow?.level = .floating
            overlayWindow?.collectionBehavior = [.canJoinAllSpaces, .stationary]
            overlayWindow?.hasShadow = true
        }

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - Constants.UI.overlayWidth / 2
            let y = screenFrame.maxY - Constants.UI.overlayHeight - 100
            overlayWindow?.setFrameOrigin(NSPoint(x: x, y: y))
        }

        overlayWindow?.orderFront(nil)
        appState.showOverlay = true
    }

    private func hideOverlay() {
        overlayWindow?.orderOut(nil)
        appState.showOverlay = false
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            let hostingView = NSHostingView(rootView: settingsView)

            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 450),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )

            settingsWindow?.contentView = hostingView
            settingsWindow?.title = "Offline Speech to Text Settings"
            settingsWindow?.center()
            settingsWindow?.isReleasedWhenClosed = false
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Show a standalone model download window (used post-onboarding when model isn't ready)
    func showModelDownloadWindow() {
        if modelDownloadWindow == nil {
            let downloadView = ModelDownloadView(onComplete: { [weak self] in
                self?.modelDownloadWindow?.close()
                self?.modelDownloadWindow = nil
            }, showSkip: false)
            let hostingView = NSHostingView(rootView: downloadView)

            modelDownloadWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 420),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )

            modelDownloadWindow?.contentView = hostingView
            modelDownloadWindow?.title = "Download Speech Recognition Model"
            modelDownloadWindow?.center()
            modelDownloadWindow?.isReleasedWhenClosed = false
        }

        modelDownloadWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        whisperManager.cancelRecording()
        NSApp.terminate(nil)
    }

    private func loadModelIfNeeded() async {
        // Don't auto-load during onboarding - user will manually trigger download
        guard appState.hasCompletedOnboarding else { return }

        if !appState.modelState.isReady && !appState.skippedModelDownload {
            logger.info("Auto-loading model '\(self.appState.selectedModel)' on launch")
            await whisperManager.loadModel(appState.selectedModel)

            // If model failed to load, show recovery UI
            if !appState.modelState.isReady {
                logger.warning("Model failed to load on startup, showing recovery UI")
                showModelDownloadWindow()
            }
        }
    }

    private func showRecordingTooShortAlert() {
        let alert = NSAlert()
        alert.messageText = "Recording Too Short"
        alert.informativeText = "Please hold the hotkey for at least 2 seconds while speaking."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showMicrophoneAlert() {
        let alert = NSAlert()
        alert.messageText = "Microphone Access Required"
        alert.informativeText = "Offline Speech to Text needs microphone access to record speech.\n\nGo to System Settings > Privacy & Security > Microphone and enable access for this app."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            permissionsManager.openMicrophonePreferences()
        }
    }
}
