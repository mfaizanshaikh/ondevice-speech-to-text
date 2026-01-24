import Foundation
import AVFoundation
import AppKit

@MainActor
class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    @Published var microphonePermission: PermissionStatus = .unknown
    @Published var accessibilityPermission: PermissionStatus = .unknown

    enum PermissionStatus: Equatable {
        case unknown
        case notDetermined
        case granted
        case denied

        var isGranted: Bool {
            self == .granted
        }
    }

    private init() {
        // Don't check permissions in init to avoid triggering audio access too early
        // Permissions will be checked when checkAllPermissions() is called explicitly
    }

    func checkAllPermissions() {
        checkMicrophonePermission()
        checkAccessibilityPermission()
    }

    func checkMicrophonePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            microphonePermission = .notDetermined
        case .restricted, .denied:
            microphonePermission = .denied
        case .authorized:
            microphonePermission = .granted
        @unknown default:
            microphonePermission = .unknown
        }
    }

    func requestMicrophonePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            microphonePermission = granted ? .granted : .denied
            return granted
        }

        checkMicrophonePermission()
        return microphonePermission.isGranted
    }

    func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        accessibilityPermission = trusted ? .granted : .denied
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.checkAccessibilityPermission()
        }
    }

    func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func openMicrophonePreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }

    var allPermissionsGranted: Bool {
        microphonePermission.isGranted && accessibilityPermission.isGranted
    }

    var permissionsSummary: String {
        var items: [String] = []

        if !microphonePermission.isGranted {
            items.append("Microphone")
        }
        if !accessibilityPermission.isGranted {
            items.append("Accessibility")
        }

        if items.isEmpty {
            return "All permissions granted"
        }

        return "Missing: \(items.joined(separator: ", "))"
    }
}
