import SwiftUI
import SwiftData

struct CameraView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var cameraViewModel = CameraViewModel()
    @State private var albumViewModel: AlbumViewModel?
    @State private var showGallery = false
    @State private var focusPoint: CGPoint?
    @State private var pinchScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Camera preview — always show, session starts async
            GeometryReader { geo in
                CameraPreviewView(session: cameraViewModel.cameraService.captureSession)
                    .ignoresSafeArea()
                    .gesture(
                        MagnificationGesture()
                            .onChanged { scale in
                                let newZoom = pinchScale * scale
                                cameraViewModel.cameraService.setZoom(newZoom)
                            }
                            .onEnded { _ in
                                pinchScale = cameraViewModel.cameraService.zoomLevel
                            }
                    )
                    .simultaneousGesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                let location = value.location
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    focusPoint = location
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                    withAnimation {
                                        focusPoint = nil
                                    }
                                }
                                let normalizedPoint = CGPoint(
                                    x: location.x / geo.size.width,
                                    y: location.y / geo.size.height
                                )
                                cameraViewModel.cameraService.focus(at: normalizedPoint)
                            }
                    )
            }
            .ignoresSafeArea()

            // Album selector at top + zoom indicator
            if let albumVM = albumViewModel {
                VStack {
                    AlbumSelectorOverlay(albumViewModel: albumVM)
                    Spacer()
                    if cameraViewModel.cameraService.zoomLevel > 1.05 {
                        Text(String(format: "%.1fx", cameraViewModel.cameraService.zoomLevel))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(10)
                            .padding(.bottom, 8)
                    }
                }
            }

            // Focus square
            if let focusPoint = focusPoint {
                FocusSquare(position: focusPoint)
            }

            // Photo saved flash
            if cameraViewModel.showPhotoSaved {
                Color.white
                    .ignoresSafeArea()
                    .opacity(0.3)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // Bottom controls
            if let albumVM = albumViewModel {
                VStack {
                    Spacer()

                    CameraControlsView(
                        cameraService: cameraViewModel.cameraService,
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
                        onCameraSwitch: {
                            cameraViewModel.cameraService.switchCamera()
                        },
                        onGalleryTap: {
                            showGallery = true
                        },
                        lastPhotoThumbnail: cameraViewModel.lastCapturedImage
                    )
                }
            }
        }
        .onAppear {
            if albumViewModel == nil {
                albumViewModel = AlbumViewModel(modelContext: modelContext)
            }
            cameraViewModel.cameraService.setupCamera()
        }
        .onDisappear {
            cameraViewModel.cameraService.stopSession()
        }
        .sheet(isPresented: $showGallery) {
            GalleryView()
                .environment(\.modelContext, modelContext)
        }
        .statusBarHidden(true)
    }
}

struct FocusSquare: View {
    let position: CGPoint
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Rectangle()
                .stroke(Color.yellow, lineWidth: 1.5)
                .frame(width: 60, height: 60)

            Rectangle()
                .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
                .frame(width: 60, height: 60)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .opacity(isAnimating ? 0 : 1)
        }
        .position(position)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    CameraView()
}
