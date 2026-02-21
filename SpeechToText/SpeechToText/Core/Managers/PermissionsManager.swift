import Foundation
import AVFoundation
import AppKit
import Combine

@MainActor
class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    @Published var microphonePermission: PermissionStatus = .unknown

    private var permissionCheckTimer: Timer?

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

    /// Start polling for permission changes (useful during onboarding)
    func startMonitoringPermissions() {
        stopMonitoringPermissions()
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkMicrophonePermission()
            }
        }
    }

    /// Stop polling for permission changes
    func stopMonitoringPermissions() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
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

    func openMicrophonePreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }

    var allPermissionsGranted: Bool {
        microphonePermission.isGranted
    }

    var permissionsSummary: String {
        microphonePermission.isGranted ? "All permissions granted" : "Missing: Microphone"
    }
}
