import SwiftUI
import AVFoundation

// MARK: - Capture Mode

enum CaptureMode: String, CaseIterable {
    case photo = "PHOTO"
    case video = "VIDEO"
}

// MARK: - CameraControlsView

struct CameraControlsView: View {
    @ObservedObject var cameraService: CameraService
    @ObservedObject var albumViewModel: AlbumViewModel

    var onPhotoTaken: () -> Void
    var onVideoStart: () -> Void
    var onVideoEnd: () -> Void
    var onCameraSwitch: () -> Void
    var onGalleryTap: (() -> Void)?
    var lastPhotoThumbnail: UIImage?

    @State private var captureMode: CaptureMode = .photo
    @State private var isRecording = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?

    // Album pill animation state
    @State private var albumNameOffset: CGFloat = 0
    @State private var albumNameOpacity: Double = 1.0
    @State private var hasCycledAlbum = false
    @State private var isShowingAlbumPicker = false
    @State private var pillShakeOffset: CGFloat = 0
    @State private var isShowingCreateAlbum = false

    private var isVideoMode: Bool { captureMode == .video }

    var body: some View {
        VStack(spacing: 0) {

            // ═══════════════════════════════════════════════════
            // TOP BAR — semi-transparent (photo only)
            // ═══════════════════════════════════════════════════
            if !isVideoMode {
                HStack {
                    Button(action: cycleFlash) {
                        Image(systemName: flashIconName)
                            .font(.system(size: 20))
                            .foregroundStyle(cameraService.flashMode == .on ? Color.yellow : Color.white)
                            .frame(width: 52, height: 44)
                            .contentShape(Rectangle())
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.45))
            }

            // ═══════════════════════════════════════════════════
            // ALBUM PILL — glass capsule, vertical swipe
            // Consistent top margin in BOTH modes
            // ═══════════════════════════════════════════════════
            if !isRecording {
                albumPill
                    .padding(.top, isVideoMode ? 56 : 12)
                    .transition(.opacity)
            }

            // ═══════════════════════════════════════════════════
            // RECORDING INDICATOR (video mode only)
            // ═══════════════════════════════════════════════════
            if isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text(formatDuration(recordingDuration))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.5))
                .clipShape(Capsule())
                .padding(.top, 60)
                .transition(.opacity)
            }

            Spacer()

            // ═══════════════════════════════════════════════════
            // BOTTOM SECTION — single continuous block
            // Shutter row + toggle row, no gaps between them
            // ═══════════════════════════════════════════════════
            VStack(spacing: 0) {
                bottomBar
                modeToggle
                    .padding(.top, 10)
                    .padding(.bottom, 24)
            }
            .background(Color.black.opacity(0.45))
        }
        .animation(.easeInOut(duration: 0.3), value: isVideoMode)
        .animation(.easeInOut(duration: 0.2), value: isRecording)
    }

    // MARK: - Album Pill (glass capsule, vertical swipe)

    private var albumPill: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 13, weight: .medium))
                    Text(albumViewModel.selectedAlbum?.name ?? "No Album")
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                // Use .primary so text auto-adapts: black on bright glass, white on dark glass
                .foregroundStyle(.primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .glassEffect(in: Capsule())
                .offset(x: pillShakeOffset, y: albumNameOffset)
                .opacity(albumNameOpacity)

                Spacer()
            }
        }
        .frame(height: 60)
        .contentShape(Rectangle())
        .onTapGesture { isShowingAlbumPicker = true }
        .gesture(
            DragGesture(minimumDistance: 12)
                .onChanged { value in
                    guard !hasCycledAlbum,
                          abs(value.translation.height) > 20 else { return }
                    hasCycledAlbum = true

                    if albumViewModel.albums.isEmpty {
                        isShowingCreateAlbum = true
                        return
                    }

                    guard albumViewModel.albums.count > 1 else {
                        wigglePill()
                        return
                    }

                    let goingDown = value.translation.height > 0
                    withAnimation(.easeIn(duration: 0.1)) {
                        albumNameOffset = goingDown ? 16 : -16
                        albumNameOpacity = 0
                    }
                    if goingDown { albumViewModel.cycleToNextAlbum() }
                    else         { albumViewModel.cycleToPreviousAlbum() }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        albumNameOffset = goingDown ? -12 : 12
                        withAnimation(.spring(duration: 0.2, bounce: 0.1)) {
                            albumNameOffset = 0
                            albumNameOpacity = 1
                        }
                    }
                }
                .onEnded { _ in
                    hasCycledAlbum = false
                    withAnimation(.spring(duration: 0.15)) {
                        albumNameOffset = 0
                        albumNameOpacity = 1
                    }
                }
        )
        .sheet(isPresented: $isShowingAlbumPicker) {
            AlbumPickerSheet(albumViewModel: albumViewModel, isPresented: $isShowingAlbumPicker)
        }
        .sheet(isPresented: $isShowingCreateAlbum) {
            AlbumCreationSheet { name, _, _ in
                albumViewModel.createAlbum(name: name)
            }
        }
    }

    // MARK: - Wiggle

    private func wigglePill() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        let spring = Animation.linear(duration: 0.06)
        withAnimation(spring, completionCriteria: .logicallyComplete) {
            pillShakeOffset = 10
        } completion: {
            withAnimation(spring, completionCriteria: .logicallyComplete) {
                pillShakeOffset = -10
            } completion: {
                withAnimation(spring, completionCriteria: .logicallyComplete) {
                    pillShakeOffset = 6
                } completion: {
                    withAnimation(spring, completionCriteria: .logicallyComplete) {
                        pillShakeOffset = -6
                    } completion: {
                        withAnimation(.spring(duration: 0.2, bounce: 0.4)) {
                            pillShakeOffset = 0
                        }
                    }
                }
            }
        }
    }

    // MARK: - Mode Toggle (glass segmented pill)

    private var modeToggle: some View {
        ZStack {
            // Sliding highlight behind the selected segment
            GeometryReader { geo in
                let segmentWidth = geo.size.width / 2
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: segmentWidth - 4, height: geo.size.height - 4)
                    .offset(
                        x: (captureMode == .photo ? 0 : segmentWidth) + 2,
                        y: 2
                    )
                    .animation(.spring(duration: 0.3, bounce: 0.15), value: captureMode)
            }

            // Two tappable labels
            HStack(spacing: 0) {
                ForEach(CaptureMode.allCases, id: \.self) { mode in
                    Button {
                        if isRecording && mode == .photo {
                            isRecording = false
                            stopTimer()
                            onVideoEnd()
                        }
                        withAnimation(.spring(duration: 0.3, bounce: 0.15)) { captureMode = mode }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 13, weight: captureMode == mode ? .bold : .medium))
                            .foregroundStyle(captureMode == mode ? Color.white : Color.white.opacity(0.45))
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 170, height: 40)
        .glassEffect(in: Capsule())
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(alignment: .center, spacing: 0) {
            // Gallery thumbnail
            Button(action: { onGalleryTap?() }) {
                if let thumbnail = lastPhotoThumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 46, height: 46)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 46, height: 46)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 18))
                                .foregroundStyle(.white.opacity(0.45))
                        )
                }
            }

            Spacer()

            // Shutter / Record
            CameraShutterButton(
                mode: captureMode,
                isRecording: isRecording,
                onTap: {
                    if captureMode == .photo {
                        onPhotoTaken()
                    } else {
                        if isRecording {
                            isRecording = false
                            stopTimer()
                            onVideoEnd()
                        } else {
                            isRecording = true
                            recordingDuration = 0
                            onVideoStart()
                            startTimer()
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        }
                    }
                }
            )

            Spacer()

            // Camera switch
            Button(action: onCameraSwitch) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Flash

    private func cycleFlash() {
        let next: AVCaptureDevice.FlashMode
        switch cameraService.flashMode {
        case .off:  next = .auto
        case .auto: next = .on
        case .on:   next = .off
        @unknown default: next = .off
        }
        cameraService.setFlashMode(next)
    }

    private var flashIconName: String {
        switch cameraService.flashMode {
        case .off:  return "bolt.slash.fill"
        case .auto: return "bolt.badge.automatic.fill"
        case .on:   return "bolt.fill"
        @unknown default: return "bolt.slash.fill"
        }
    }

    // MARK: - Timer

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func startTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            recordingDuration += 1
        }
    }

    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingDuration = 0
    }
}

// MARK: - CameraShutterButton

struct CameraShutterButton: View {
    let mode: CaptureMode
    let isRecording: Bool
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white, lineWidth: 3.5)
                .frame(width: 72, height: 72)

            Group {
                if mode == .photo {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 58, height: 58)
                } else if isRecording {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.red)
                        .frame(width: 26, height: 26)
                } else {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 58, height: 58)
                }
            }
            .animation(.spring(duration: 0.25, bounce: 0.1), value: isRecording)
            .animation(.easeInOut(duration: 0.18), value: mode)
        }
        .scaleEffect(isPressed ? 0.90 : 1.0)
        .animation(.easeInOut(duration: 0.08), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in
                    isPressed = false
                    onTap()
                    if mode == .photo {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                }
        )
    }
}


