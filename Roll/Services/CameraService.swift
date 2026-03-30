@preconcurrency import AVFoundation
import Combine
import Photos
import UIKit

// Camera service manages AVCaptureSession on a dedicated queue.
// We opt out of default MainActor isolation since capture work must
// happen off the main thread. @Published updates are dispatched to main.
@preconcurrency @MainActor
class CameraService: NSObject, ObservableObject {
    @Published var isCameraReady = false
    @Published var isRecording = false
    @Published var cameraPosition: AVCaptureDevice.Position = .back
    @Published var flashMode: AVCaptureDevice.FlashMode = .auto
    @Published var zoomLevel: CGFloat = 1.0
    @Published var focusPoint: CGPoint?

    // Public so CameraPreviewView can bind its layer to the session
    nonisolated let captureSession = AVCaptureSession()

    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var currentVideoFileURL: URL?
    private nonisolated(unsafe) var photoCompletionHandler: ((UIImage?) -> Void)?
    private nonisolated(unsafe) var videoCompletionHandler: ((URL?) -> Void)?

    private nonisolated let sessionQueue = DispatchQueue(label: "com.roll.camera.session", qos: .userInitiated)

    override init() {
        super.init()
    }

    func setupCamera() {
        guard !isCameraReady else { return }
        sessionQueue.async {
            self.configureSession()
        }
    }

    private nonisolated func configureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

        // Video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            captureSession.commitConfiguration()
            return
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }

        // Audio input
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           captureSession.canAddInput(audioInput) {
            captureSession.addInput(audioInput)
        }

        // Photo output
        let photoOut = AVCapturePhotoOutput()
        if captureSession.canAddOutput(photoOut) {
            captureSession.addOutput(photoOut)
            photoOut.maxPhotoQualityPrioritization = .speed
        }

        // Video file output
        let videoOut = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(videoOut) {
            captureSession.addOutput(videoOut)
        }

        captureSession.commitConfiguration()
        captureSession.startRunning()

        DispatchQueue.main.async {
            self.photoOutput = photoOut
            self.videoOutput = videoOut
            self.isCameraReady = true
        }
    }

    func startSession() {
        sessionQueue.async { [captureSession] in
            if !captureSession.isRunning {
                captureSession.startRunning()
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [captureSession] in
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        guard let photoOutput else { return }

        photoCompletionHandler = completion
        let flash = flashMode
        let session = captureSession

        sessionQueue.async { [weak self] in
            guard let self else { return }
            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .speed

            // Only set flash if the current device supports it
            if let device = (session.inputs.first(where: {
                ($0 as? AVCaptureDeviceInput)?.device.hasMediaType(.video) == true
            }) as? AVCaptureDeviceInput)?.device,
               device.hasFlash {
                settings.flashMode = flash
            }

            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func startVideoRecording() {
        guard let videoOutput else { return }

        let fileName = UUID().uuidString
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent("\(fileName).mov")

        currentVideoFileURL = fileURL

        sessionQueue.async { [weak self] in
            guard let self else { return }
            videoOutput.startRecording(to: fileURL, recordingDelegate: self)
            DispatchQueue.main.async {
                self.isRecording = true
            }
        }
    }

    func stopVideoRecording(completion: @escaping (URL?) -> Void) {
        guard let videoOutput else { return }

        videoCompletionHandler = completion
        sessionQueue.async {
            videoOutput.stopRecording()
        }
    }

    func switchCamera() {
        let newPosition: AVCaptureDevice.Position = cameraPosition == .back ? .front : .back
        let session = captureSession

        sessionQueue.async {
            session.beginConfiguration()

            // Remove existing video input only
            for input in session.inputs {
                if let deviceInput = input as? AVCaptureDeviceInput,
                   deviceInput.device.hasMediaType(.video) {
                    session.removeInput(deviceInput)
                }
            }

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                session.commitConfiguration()
                return
            }

            if session.canAddInput(input) {
                session.addInput(input)
            }
            session.commitConfiguration()

            DispatchQueue.main.async {
                self.cameraPosition = newPosition
                self.zoomLevel = 1.0
            }
        }
    }

    func setFlashMode(_ mode: AVCaptureDevice.FlashMode) {
        flashMode = mode
    }

    func setZoom(_ level: CGFloat) {
        let clamped = max(1.0, min(level, 5.0))
        zoomLevel = clamped

        let session = captureSession
        sessionQueue.async {
            guard let device = (session.inputs.first(where: {
                ($0 as? AVCaptureDeviceInput)?.device.hasMediaType(.video) == true
            }) as? AVCaptureDeviceInput)?.device else { return }

            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
            } catch {
                print("Error setting zoom: \(error)")
            }
        }
    }

    func focus(at point: CGPoint) {
        focusPoint = point
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.focusPoint = nil
        }

        let session = captureSession
        sessionQueue.async {
            guard let device = (session.inputs.first(where: {
                ($0 as? AVCaptureDeviceInput)?.device.hasMediaType(.video) == true
            }) as? AVCaptureDeviceInput)?.device else { return }

            do {
                try device.lockForConfiguration()

                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }

                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                }

                device.unlockForConfiguration()
            } catch {
                print("Error setting focus: \(error)")
            }
        }
    }

    deinit {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
}

// MARK: - AVCapture Delegates
extension CameraService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            print("Photo capture error: \(error)")
            DispatchQueue.main.async {
                self.photoCompletionHandler?(nil)
                self.photoCompletionHandler = nil
            }
            return
        }

        guard let imageData = photo.fileDataRepresentation() else {
            DispatchQueue.main.async {
                self.photoCompletionHandler?(nil)
                self.photoCompletionHandler = nil
            }
            return
        }

        let image = UIImage(data: imageData)
        DispatchQueue.main.async {
            self.photoCompletionHandler?(image)
            self.photoCompletionHandler = nil
        }
    }
}

extension CameraService: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        if let error {
            print("Video recording error: \(error)")
        }
        DispatchQueue.main.async {
            self.isRecording = false
            self.videoCompletionHandler?(outputFileURL)
            self.videoCompletionHandler = nil
        }
    }
}
