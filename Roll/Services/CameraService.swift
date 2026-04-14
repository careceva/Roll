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
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var zoomLevel: CGFloat = 1.0
    @Published var focusPoint: CGPoint?
    @Published var exposureBias: Float = 0.0
    @Published var isPortraitMode = false

    // Public so CameraPreviewView can bind its layer to the session
    nonisolated let captureSession = AVCaptureSession()

    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var currentVideoFileURL: URL?

    // Use an array to support overlapping captures (rapid fire)
    private nonisolated(unsafe) var pendingPhotoHandlers: [Int64: (portrait: Bool, handler: (UIImage?) -> Void)] = [:]
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

        // Ensure default zoom factor matches native iOS Camera (1x wide)
        do {
            try videoDevice.lockForConfiguration()
            videoDevice.videoZoomFactor = 1.0
            videoDevice.unlockForConfiguration()
        } catch {
            print("Error setting initial zoom: \(error)")
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

    /// Restarts a previously configured session and fires `onRunning` when the first frame arrives.
    func restartSession(onRunning: @escaping () -> Void) {
        runningObservation?.invalidate()
        runningObservation = captureSession.observe(\.isRunning, options: [.new]) { [weak self] _, change in
            if change.newValue == true {
                DispatchQueue.main.async { onRunning() }
                self?.runningObservation?.invalidate()
                self?.runningObservation = nil
            }
        }
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
        let portrait = isPortraitMode

        // Build settings on the calling thread (no queue hop needed)
        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = .speed

        if portrait && photoOutput.isDepthDataDeliveryEnabled {
            settings.isDepthDataDeliveryEnabled = true
        }

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
        pendingPhotoHandlers[uniqueID] = (portrait: portrait, handler: completion)
        handlersLock.unlock()

        // Dispatch only the actual capture call to session queue
        sessionQueue.async {
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    // MARK: - Video Recording

    func startVideoRecording() {
        guard let videoOutput, !videoOutput.isRecording else { return }

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

    func switchSessionPreset(forVideo: Bool, completion: (() -> Void)? = nil) {
        let targetPreset: AVCaptureSession.Preset = forVideo ? .hd1920x1080 : .photo
        guard captureSession.sessionPreset != targetPreset else {
            completion?()
            return
        }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.captureSession.beginConfiguration()
            if self.captureSession.canSetSessionPreset(targetPreset) {
                self.captureSession.sessionPreset = targetPreset
            }
            self.captureSession.commitConfiguration()
            if let completion {
                DispatchQueue.main.async { completion() }
            }
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

    func switchToPortraitMode(_ enabled: Bool, completion: (() -> Void)? = nil) {
        isPortraitMode = enabled
        let photoOut = self.photoOutput
        let position = self.cameraPosition

        sessionQueue.async { [weak self, captureSession] in
            // Phase 1: Swap camera input
            captureSession.beginConfiguration()

            for input in captureSession.inputs {
                if let devInput = input as? AVCaptureDeviceInput,
                   devInput.device.hasMediaType(.video) {
                    captureSession.removeInput(devInput)
                }
            }

            let preferred: AVCaptureDevice.DeviceType = enabled ? .builtInDualWideCamera : .builtInWideAngleCamera
            let device = AVCaptureDevice.default(preferred, for: .video, position: position)
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)

            if let device, let newInput = try? AVCaptureDeviceInput(device: device),
               captureSession.canAddInput(newInput) {
                captureSession.addInput(newInput)

                // Set zoom to 2x for portrait (matches iOS Camera), 1x otherwise
                let targetZoom: CGFloat = enabled ? 2.0 : 1.0
                try? device.lockForConfiguration()
                device.videoZoomFactor = targetZoom
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self?.zoomLevel = targetZoom
                }
            }

            if captureSession.canSetSessionPreset(.photo) {
                captureSession.sessionPreset = .photo
            }

            captureSession.commitConfiguration()

            // Phase 2: Enable depth delivery AFTER input is committed
            if let photoOut {
                captureSession.beginConfiguration()
                photoOut.isDepthDataDeliveryEnabled = enabled && photoOut.isDepthDataDeliverySupported
                captureSession.commitConfiguration()
            }

            if let completion {
                DispatchQueue.main.async { completion() }
            }
        }
    }

    func setExposureBias(_ bias: Float) {
        exposureBias = bias
        let session = captureSession
        sessionQueue.async {
            guard let device = (session.inputs.first(where: {
                ($0 as? AVCaptureDeviceInput)?.device.hasMediaType(.video) == true
            }) as? AVCaptureDeviceInput)?.device else { return }

            let clamped = max(device.minExposureTargetBias, min(bias, device.maxExposureTargetBias))
            do {
                try device.lockForConfiguration()
                device.setExposureTargetBias(clamped, completionHandler: nil)
                device.unlockForConfiguration()
            } catch {
                print("Error setting exposure bias: \(error)")
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
        let entry = pendingPhotoHandlers.removeValue(forKey: uniqueID)
        handlersLock.unlock()

        guard let entry else { return }
        let handler = entry.handler

        if let error {
            print("Photo capture error: \(error)")
            DispatchQueue.main.async { handler(nil) }
            return
        }

        // Process image on background queue to keep session queue free for next capture
        DispatchQueue.global(qos: .userInitiated).async {
            guard let imageData = photo.fileDataRepresentation() else {
                DispatchQueue.main.async { handler(nil) }
                return
            }
            let image = UIImage(data: imageData)
            DispatchQueue.main.async { handler(image) }
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
        let url: URL? = error == nil ? outputFileURL : nil
        if let error {
            print("Video recording error: \(error)")
        }
        DispatchQueue.main.async {
            self.isRecording = false
            self.videoCompletionHandler?(url)
            self.videoCompletionHandler = nil
        }
    }
}
