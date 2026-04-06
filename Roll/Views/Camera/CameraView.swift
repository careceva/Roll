import SwiftUI
import SwiftData
import Photos
import AVFoundation
import MediaPlayer

struct CameraView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var cameraViewModel = CameraViewModel()
    @State private var albumViewModel: AlbumViewModel?
    @State private var showGallery = false
    @State private var focusPoint: CGPoint?
    @State private var pinchScale: CGFloat = 1.0
    @State private var cameraReady = false
    @State private var showLastCapture = false
    @State private var isVideoMode = false
    @State private var currentCaptureMode: CaptureMode = .photo
    @State private var volumeObserver: NSKeyValueObservation?
    @State private var lastVolume: Float = 0
    @State private var isVolumeRecording = false
    @State private var exposureBias: Float = 0.0
    @State private var showExposureSlider = false
    @State private var exposureSliderTimer: Timer?

    // MARK: - Volume Button Shutter

    private func setupVolumeButtonObserver() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(true)
        lastVolume = audioSession.outputVolume

        volumeObserver = audioSession.observe(\.outputVolume, options: [.new, .old]) { session, change in
            guard let newVal = change.newValue, let oldVal = change.oldValue, newVal != oldVal else { return }
            DispatchQueue.main.async {
                handleVolumeButtonPress()
                resetSystemVolume(to: oldVal)
            }
        }
    }

    private func handleVolumeButtonPress() {
        guard let albumVM = albumViewModel, let album = albumVM.selectedAlbum else { return }

        switch currentCaptureMode {
        case .photo, .portrait:
            cameraViewModel.capturePhoto(toAlbum: album, modelContext: modelContext)
        case .video:
            if isVolumeRecording {
                isVolumeRecording = false
                cameraViewModel.stopVideoRecording(toAlbum: album, modelContext: modelContext) {}
            } else {
                isVolumeRecording = true
                cameraViewModel.startVideoRecording(toAlbum: album, modelContext: modelContext)
            }
        }
    }

    private func resetSystemVolume(to value: Float) {
        // Find the hidden MPVolumeView slider and reset volume to prevent drift
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first {
            findVolumeSlider(in: window)?.value = value
        }
    }

    private func resetExposureSliderTimer() {
        exposureSliderTimer?.invalidate()
        exposureSliderTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            DispatchQueue.main.async {
                withAnimation {
                    showExposureSlider = false
                    focusPoint = nil
                }
            }
        }
    }

    private func findVolumeSlider(in view: UIView) -> UISlider? {
        for subview in view.subviews {
            if let slider = subview as? UISlider {
                return slider
            }
            if let found = findVolumeSlider(in: subview) {
                return found
            }
        }
        return nil
    }

    private func refreshThumbnailFromAlbum() {
        albumViewModel?.loadAlbumThumbnail()
    }

    @ViewBuilder
    private var lastCaptureSheetContent: some View {
        let albumName = albumViewModel?.selectedAlbum?.name ?? ""
        let assets = PhotoLibraryService.shared.fetchPhotosForAlbum(named: albumName)
        if let firstAsset = assets.first {
            PhotoDetailView(assets: assets, initialAsset: firstAsset, onBackToAlbum: {
                showLastCapture = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showGallery = true
                }
            })
        } else {
            Color.black.ignoresSafeArea().onAppear { showLastCapture = false }
        }
    }

    private func toggleMode() {
        let isMovingToVideo = currentCaptureMode == .video

        // 1. Start the UI animation immediately
        withAnimation(.easeInOut(duration: 0.45)) {
            isVideoMode = isMovingToVideo
            // This handles the scaleEffect (1.0 -> 1.12) and bar heights
        }

        // 2. Delay the hardware "hiccup"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if currentCaptureMode != .portrait {
                cameraViewModel.cameraService.switchSessionPreset(forVideo: isMovingToVideo)
            }
        }
    }

    var body: some View {
        ZStack {
            // ── Layer 1: Camera preview (full bleed, scales for video crop) ─
            GeometryReader { geo in
                CameraPreviewView(session: cameraViewModel.cameraService.captureSession)
                    .ignoresSafeArea()
                    .scaleEffect(isVideoMode ? 1.15 : 1.0)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { scale in
                                cameraViewModel.cameraService.setZoom(pinchScale * scale)
                            }
                            .onEnded { _ in
                                pinchScale = cameraViewModel.cameraService.zoomLevel
                            }
                    )
                    .simultaneousGesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                let location = value.location
                                withAnimation(.easeInOut(duration: 0.3)) { focusPoint = location }

                                // Show exposure slider
                                showExposureSlider = true
                                exposureBias = 0.0
                                cameraViewModel.cameraService.setExposureBias(0.0)
                                resetExposureSliderTimer()

                                cameraViewModel.cameraService.focus(at: CGPoint(
                                    x: location.x / geo.size.width,
                                    y: location.y / geo.size.height
                                ))
                            }
                    )
            }
            .ignoresSafeArea()

            // ── Layer 1.5: Framing bars ───────────────────────────────────
            // Photo: taller bars (4:3 crop), Video: shorter bars (16:9 crop)
            GeometryReader { geo in
                let fullH = geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
                let fullW = geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing
                let photoBarH = max(0.0, (fullH - fullW * 4.0 / 3.0) / 2.0)
                let videoBarH = max(0.0, (fullH - fullW * 16.0 / 9.0) / 2.0)

                VStack(spacing: 0) {
                    Color.black
                        .opacity(isVideoMode ? 1.0 : 0.2)
                        .frame(height: isVideoMode ? videoBarH : photoBarH)
                    Spacer()
                    Color.black
                        .opacity(isVideoMode ? 1.0 : 0.2)
                        .frame(height: isVideoMode ? videoBarH : photoBarH)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // ── Layer 2: Controls (full screen, black bars top & bottom) ──
            if let albumVM = albumViewModel {
                CameraControlsView(
                    cameraService: cameraViewModel.cameraService,
                    albumViewModel: albumVM,
                    onPhotoTaken: {
                        if let album = albumVM.selectedAlbum {
                            cameraViewModel.capturePhoto(toAlbum: album, modelContext: modelContext)
                        }
                    },
                    onVideoStart: {
                        if let album = albumVM.selectedAlbum {
                            cameraViewModel.startVideoRecording(toAlbum: album, modelContext: modelContext)
                        }
                    },
                    onVideoEnd: {
                        if let album = albumVM.selectedAlbum {
                            cameraViewModel.stopVideoRecording(toAlbum: album, modelContext: modelContext) {}
                        }
                    },
                    onCameraSwitch: { cameraViewModel.cameraService.switchCamera() },
                    onGalleryTap: { showGallery = true },
                    onLastCaptureTap: { showLastCapture = true },
                    onModeChanged: { mode in
                        let wasPortrait = currentCaptureMode == .portrait
                        currentCaptureMode = mode

                        if mode == .portrait {
                            cameraViewModel.cameraService.switchToPortraitMode(true)
                        } else if wasPortrait {
                            cameraViewModel.cameraService.switchToPortraitMode(false)
                        }

                        toggleMode()
                    },
                )
                .ignoresSafeArea()
            }

            // ── Layer 3: Zoom indicator (floating above bottom bar) ───────
            if cameraViewModel.cameraService.zoomLevel > 1.05 {
                VStack {
                    Spacer()
                    Text(String(format: "%.1f×", cameraViewModel.cameraService.zoomLevel))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .glassEffect(in: Capsule())
                        .padding(.bottom, 180)
                        .transition(.opacity.combined(with: .scale(0.85)))
                }
                .allowsHitTesting(false)
            }

            // ── Layer 4: Focus square ─────────────────────────────────────
            if let focusPoint = focusPoint {
                FocusSquare(position: focusPoint)
            }

            // ── Layer 4.5: Exposure slider ──────────────────────────────
            if showExposureSlider, let fp = focusPoint {
                ExposureSliderView(
                    bias: $exposureBias,
                    position: fp,
                    onChange: { newBias in
                        cameraViewModel.cameraService.setExposureBias(newBias)
                        resetExposureSliderTimer()
                    }
                )
                .transition(.opacity)
            }

            // ── Layer 5: Shutter blink ────────────────────────────────────
            if cameraViewModel.showPhotoSaved {
                Color.black
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity.animation(.easeIn(duration: 0.04)))
            }

            // ── Layer 6: Launch animation ─────────────────────────────────
            if !cameraReady {
                Color.black
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // ── Hidden MPVolumeView to suppress system volume HUD ────────
            MPVolumeViewRepresentable()
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)
        }
        .onAppear {
            if albumViewModel == nil {
                albumViewModel = AlbumViewModel(modelContext: modelContext)
            }
            if cameraViewModel.cameraService.isCameraReady {
                // Camera already configured — just restart the stopped session
                cameraViewModel.cameraService.restartSession {
                    withAnimation(.easeIn(duration: 0.3)) { cameraReady = true }
                }
            } else {
                cameraViewModel.cameraService.onSessionRunning = {
                    withAnimation(.easeIn(duration: 0.3)) { cameraReady = true }
                }
                cameraViewModel.cameraService.setupCamera()
            }
            setupVolumeButtonObserver()
        }
        .onDisappear {
            cameraReady = false
            cameraViewModel.cameraService.stopSession()
            volumeObserver?.invalidate()
            volumeObserver = nil
        }
        .onChange(of: albumViewModel?.selectedAlbum?.id) {
            albumViewModel?.loadAlbumThumbnail()
        }
        .onChange(of: cameraViewModel.lastCapturedImage) {
            // Photo just captured — use it as the thumbnail immediately
            if let img = cameraViewModel.lastCapturedImage {
                albumViewModel?.albumThumbnail = img
            }
        }
        .sheet(isPresented: $showGallery, onDismiss: {
            albumViewModel?.fetchAlbums()
        }) {
            GalleryView().environment(\.modelContext, modelContext)
        }
        .sheet(isPresented: $showLastCapture, onDismiss: {
            // Small delay to let Photos framework finish processing any deletion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                refreshThumbnailFromAlbum()
            }
        }) {
            lastCaptureSheetContent
        }
        .statusBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
    }
}

// MARK: - MPVolumeView Representable

struct MPVolumeViewRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
        view.clipsToBounds = true
        view.alpha = 0.01
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}

// MARK: - Focus Square

struct FocusSquare: View {
    let position: CGPoint
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(Color.yellow, lineWidth: 1.5)
                .frame(width: 60, height: 60)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(Color.yellow.opacity(0.45), lineWidth: 1)
                .frame(width: 60, height: 60)
                .scaleEffect(isAnimating ? 1.28 : 1.0)
                .opacity(isAnimating ? 0 : 0.9)
        }
        .position(position)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) { isAnimating = true }
        }
    }
}

// MARK: - Exposure Slider

struct ExposureSliderView: View {
    @Binding var bias: Float
    let position: CGPoint
    let onChange: (Float) -> Void

    var body: some View {
        // Vertical slider to the right of the focus point
        VStack(spacing: 8) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 14))
                .foregroundStyle(.yellow)

            // Vertical drag area
            GeometryReader { geo in
                ZStack {
                    // Track
                    Capsule()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 2)

                    // Thumb position: bias ranges from -2 to +2, map to 0...height
                    let normalizedY = CGFloat(1.0 - (bias + 2.0) / 4.0) * geo.size.height
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 16, height: 16)
                        .position(x: geo.size.width / 2, y: normalizedY)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let fraction = value.location.y / geo.size.height
                            let clamped = max(0, min(1, fraction))
                            let newBias = Float((1.0 - clamped) * 4.0 - 2.0)
                            bias = newBias
                            onChange(newBias)
                        }
                )
            }
            .frame(width: 30, height: 120)

            Image(systemName: "sun.min.fill")
                .font(.system(size: 10))
                .foregroundStyle(.yellow.opacity(0.6))
        }
        .position(x: position.x + 50, y: position.y)
    }
}

#Preview {
    CameraView()
}
