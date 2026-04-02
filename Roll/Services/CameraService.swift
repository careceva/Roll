@preconcurrency import AVFoundation
import Combine
import Photos
import UIKit

// Camera service manages AVCaptureSession on a dedicated queue.
// Optimized for fastest possible launch, shutter, and rapid-fire capture.
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

    // Use an array to support overlapping captures (rapid fire)
    private nonisolated(unsafe) var pendingPhotoHandlers: [Int64: (UIImage?) -> Void] = [:]
    private nonisolated let handlersLock = NSLock()

    private nonisolated(unsafe) var videoCompletionHandler: ((URL?) -> Void)?

    private nonisolated let sessionQueue = DispatchQueue(label: "com.roll.camera.session", qos: .userInitiated)

    // KVO observation for session running state
    private nonisolated(unsafe) var runningObservation: NSKeyValueObservation?

    /// Callback fired once on main thread when session first starts running.
    var onSessionRunning: (() -> Void)?

    override init() {
        super.init()
    }

    func setupCamera() {
        guard !isCameraReady else { return }
        sessionQueue.async {
            self.configureSession()
        }
    }

    // MARK: - Session Configuration (optimized for speed)

    private nonisolated func configureSession() {
        // KVO: observe isRunning so CameraView gets notified instantly (no polling)
        runningObservation = captureSession.observe(\.isRunning, options: [.new]) { [weak self] session, change in
            if change.newValue == true {
                DispatchQueue.main.async {
                    self?.onSessionRunning?()
                    self?.onSessionRunning = nil // fire once
                }
                self?.runningObservation?.invalidate()
                self?.runningObservation = nil
            }
        }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

        // --- VIDEO INPUT ONLY (audio deferred for fast launch) ---
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            captureSession.commitConfiguration()
            return
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }

        // Photo output with speed priority + responsive capture
        let photoOut = AVCapturePhotoOutput()
        if captureSession.canAddOutput(photoOut) {
            captureSession.addOutput(photoOut)
            photoOut.maxPhotoQualityPrioritization = .speed

            // iOS 17+: Enable responsive capture for near-zero shutter lag
            if #available(iOS 17.0, *) {
                if photoOut.isResponsiveCaptureSupported {
                    photoOut.isResponsiveCaptureEnabled = true
                }
                if photoOut.isFastCapturePrioritizationSupported {
                    photoOut.isFastCapturePrioritizationEnabled = true
                }
            }
        }

        // Video file output
        let videoOut = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(videoOut) {
            captureSession.addOutput(videoOut)
        }

        captureSession.commitConfiguration()

        // START session immediately (video-only = fast)
        captureSession.startRunning()

        DispatchQueue.main.async {
            self.photoOutput = photoOut
            self.videoOutput = videoOut
            self.isCameraReady = true
        }

        // --- DEFERRED: add audio input AFTER session is running ---
        // Audio device init is ~200-400ms and would block camera preview.
        self.addAudioInputDeferred()
    }

    /// Adds audio input on the session queue without stopping the running session.
    private nonisolated func addAudioInputDeferred() {
        // Small yield to let the session fully start before reconfiguring
        sessionQueue.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            self.captureSession.beginConfiguration()
            if let audioDevice = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
               self.captureSession.canAddInput(audioInput) {
                self.captureSession.addInput(audioInput)
            }
            self.captureSession.commitConfiguration()
        }
    }

    // MARK: - Session Lifecycle

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

    // MARK: - Photo Capture (optimized for <100ms shutter + rapid fire)

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        guard let photoOutput else { return }

        let flash = flashMode
        let session = captureSession

        // Build settings on the calling thread (no queue hop needed)
        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = .speed

        // Check flash support
        if let device = (session.inputs.first(where: {
            ($0 as? AVCaptureDeviceInput)?.device.hasMediaType(.video) == true
        }) as? AVCaptureDeviceInput)?.device,
           device.hasFlash {
            settings.flashMode = flash
        }

        // Store handler keyed by uniqueID for overlapping captures
        let uniqueID = settings.uniqueID
        handlersLock.lock()
        pendingPhotoHandlers[uniqueID] = completion
        handlersLock.unlock()

        // Dispatch only the actual capture call to session queue
        sessionQueue.async {
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    // MARK: - Video Recording

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

    // MARK: - Camera Controls

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
        runningObservation?.invalidate()
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
        let uniqueID = photo.resolvedSettings.uniqueID

        // Retrieve the handler for this specific capture
        handlersLock.lock()
        let handler = pendingPhotoHandlers.removeValue(forKey: uniqueID)
        handlersLock.unlock()

        if let error {
            print("Photo capture error: \(error)")
            DispatchQueue.main.async { handler?(nil) }
            return
        }

        // Process image on background queue to keep session queue free for next capture
        DispatchQueue.global(qos: .userInitiated).async {
            guard let imageData = photo.fileDataRepresentation() else {
                DispatchQueue.main.async { handler?(nil) }
                return
            }
            let image = UIImage(data: imageData)
            DispatchQueue.main.async { handler?(image) }
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
