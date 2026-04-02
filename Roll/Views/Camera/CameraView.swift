import SwiftUI
import SwiftData

struct CameraView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var cameraViewModel = CameraViewModel()
    @State private var albumViewModel: AlbumViewModel?
    @State private var showGallery = false
    @State private var focusPoint: CGPoint?
    @State private var pinchScale: CGFloat = 1.0
    @State private var cameraReady = false

    var body: some View {
        ZStack {
            // ── Layer 1: Camera preview (full bleed) ─────────────────────
            GeometryReader { geo in
                CameraPreviewView(session: cameraViewModel.cameraService.captureSession)
                    .ignoresSafeArea()
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
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                    withAnimation { focusPoint = nil }
                                }
                                cameraViewModel.cameraService.focus(at: CGPoint(
                                    x: location.x / geo.size.width,
                                    y: location.y / geo.size.height
                                ))
                            }
                    )
            }
            .ignoresSafeArea()

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
                    lastPhotoThumbnail: cameraViewModel.lastCapturedImage
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
        }
        .onAppear {
            if albumViewModel == nil {
                albumViewModel = AlbumViewModel(modelContext: modelContext)
            }
            cameraViewModel.cameraService.onSessionRunning = {
                withAnimation(.easeIn(duration: 0.3)) { cameraReady = true }
            }
            cameraViewModel.cameraService.setupCamera()
        }
        .onDisappear {
            cameraViewModel.cameraService.stopSession()
        }
        .sheet(isPresented: $showGallery, onDismiss: {
            albumViewModel?.fetchAlbums()
        }) {
            GalleryView().environment(\.modelContext, modelContext)
        }
        .statusBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
    }
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

#Preview {
    CameraView()
}
