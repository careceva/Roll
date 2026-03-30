import AVFoundation
import Combine
import Photos

class PermissionService: NSObject, ObservableObject {
    @Published var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    @Published var photoLibraryPermissionStatus: PHAuthorizationStatus = .notDetermined
    @Published var microphonePermissionStatus: AVAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        checkAllPermissions()
    }

    func checkAllPermissions() {
        checkCameraPermission()
        checkPhotoLibraryPermission()
        checkMicrophonePermission()
    }

    func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        DispatchQueue.main.async {
            self.cameraPermissionStatus = status
        }
    }

    func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        DispatchQueue.main.async {
            self.photoLibraryPermissionStatus = status
        }
    }

    func checkMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        DispatchQueue.main.async {
            self.microphonePermissionStatus = status
        }
    }

    func requestCameraPermission() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        DispatchQueue.main.async {
            self.checkCameraPermission()
        }
        return granted
    }

    func requestPhotoLibraryPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in
                DispatchQueue.main.async {
                    self.checkPhotoLibraryPermission()
                    continuation.resume(returning: self.photoLibraryPermissionStatus == .authorized)
                }
            }
        }
    }

    func requestMicrophonePermission() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        DispatchQueue.main.async {
            self.checkMicrophonePermission()
        }
        return granted
    }

    var hasCameraPermission: Bool {
        cameraPermissionStatus == .authorized
    }

    var hasPhotoLibraryPermission: Bool {
        photoLibraryPermissionStatus == .authorized || photoLibraryPermissionStatus == .limited
    }

    var hasMicrophonePermission: Bool {
        microphonePermissionStatus == .authorized
    }
}
