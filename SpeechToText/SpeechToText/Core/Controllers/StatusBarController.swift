import Foundation
import AppKit
import SwiftUI
import UserNotifications

@MainActor
class StatusBarController: ObservableObject {
    static let shared = StatusBarController()

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var overlayWindow: NSWindow?
    private var settingsWindow: NSWindow?

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
        requestNotificationAuthorization()

        Task {
            await loadModelIfNeeded()
        }
    }

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Error requesting notification authorization: \(error.localizedDescription)")
            }
            if !granted {
                print("Notification authorization not granted")
            }
        }
    }

    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "SpeechToText")
            button.image?.size = NSSize(width: Constants.UI.statusBarIconSize, height: Constants.UI.statusBarIconSize)
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

        menu?.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu?.addItem(settingsItem)

        menu?.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit SpeechToText", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu?.addItem(quitItem)
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            updateMenuItems()
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            toggleRecording()
        }
    }

    private func updateMenuItems() {
        if let statusItem = menu?.item(withTag: 100) {
            statusItem.title = "Status: \(appState.modelState.statusText)"
        }

        if let recordItem = menu?.item(withTag: 101) {
            recordItem.title = appState.isRecording ? "Stop Recording" : "Start Recording"
            recordItem.isEnabled = appState.modelState.isReady || appState.isRecording
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

    private func startRecording() async {
        guard appState.modelState.isReady else {
            print("Model not ready: \(appState.modelState)")
            showNotification(title: "Model Not Ready", body: "Please wait for the model to load.")
            return
        }

        guard permissionsManager.microphonePermission.isGranted else {
            let granted = await permissionsManager.requestMicrophonePermission()
            guard granted else {
                showNotification(title: "Microphone Access Required", body: "Please grant microphone access in System Settings.")
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

        hideOverlay()

        print("[StatusBarController] Transcription result: '\(result.text)', isEmpty: \(result.isEmpty)")

        if !result.isEmpty {
            print("[StatusBarController] Attempting to insert text...")
            let inserted = await textInsertionService.insertText(result.text)
            print("[StatusBarController] Text insertion result: \(inserted)")
            if !inserted {
                showNotification(title: "Text Copied", body: "Text has been copied to clipboard. Paste with Cmd+V.")
            }
        } else {
            print("[StatusBarController] Empty transcription, nothing to insert")
        }

        appState.recordingState = .idle
        updateStatusIcon()
    }

    private func updateStatusIcon() {
        guard let button = statusItem?.button else { return }

        let iconName = appState.recordingState.iconName
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "SpeechToText")
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

            overlayWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: Constants.UI.overlayWidth, height: Constants.UI.overlayHeight),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )

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
            settingsWindow?.title = "SpeechToText Settings"
            settingsWindow?.center()
            settingsWindow?.isReleasedWhenClosed = false
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        whisperManager.cancelRecording()
        NSApp.terminate(nil)
    }

    private func loadModelIfNeeded() async {
        if !appState.modelState.isReady {
            await whisperManager.loadModel(appState.selectedModel)
        }
    }

    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // nil trigger means deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error delivering notification: \(error.localizedDescription)")
            }
        }
    }
}
