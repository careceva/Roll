import SwiftUI
import AVFoundation

struct CameraControlsView: View {
    @ObservedObject var cameraService: CameraService
    @State private var isRecording = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?

    var onPhotoTaken: () -> Void
    var onVideoStart: () -> Void
    var onVideoEnd: () -> Void
    var onCameraSwitch: () -> Void
    var onGalleryTap: (() -> Void)?
    var lastPhotoThumbnail: UIImage?

    var body: some View {
        VStack(spacing: 0) {
            // Top: flash + recording indicator + camera switch
            HStack {
                // Flash toggle
                Button(action: cycleFlash) {
                    Image(systemName: flashIconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(cameraService.flashMode == .on ? .yellow : .white)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }

                Spacer()

                // Recording timer
                if isRecording {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text(formatDuration(recordingDuration))
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .transition(.opacity)
                }

                Spacer()

                // Camera switch
                Button(action: onCameraSwitch) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            // Bottom: gallery thumbnail + shutter + spacer
            HStack(alignment: .center) {
                // Gallery thumbnail
                Button(action: { onGalleryTap?() }) {
                    if let thumbnail = lastPhotoThumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.white.opacity(0.5))
                            )
                    }
                }

                Spacer()

                // Shutter button
                ShutterButton(
                    isRecording: $isRecording,
                    onTap: {
                        // Photo
                        onPhotoTaken()
                    },
                    onLongPressStart: {
                        // Start video
                        isRecording = true
                        recordingDuration = 0
                        onVideoStart()
                        startTimer()
                    },
                    onLongPressEnd: {
                        // Stop video
                        isRecording = false
                        stopTimer()
                        onVideoEnd()
                    }
                )

                Spacer()

                // Spacer to balance layout
                Color.clear
                    .frame(width: 50, height: 50)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }

    private func cycleFlash() {
        let next: AVCaptureDevice.FlashMode
        switch cameraService.flashMode {
        case .off: next = .auto
        case .auto: next = .on
        case .on: next = .off
        @unknown default: next = .off
        }
        cameraService.setFlashMode(next)
    }

    private var flashIconName: String {
        switch cameraService.flashMode {
        case .off: return "bolt.slash.fill"
        case .auto: return "bolt.badge.automatic.fill"
        case .on: return "bolt.fill"
        @unknown default: return "bolt.slash.fill"
        }
    }

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

struct ShutterButton: View {
    @Binding var isRecording: Bool
    let onTap: () -> Void
    let onLongPressStart: () -> Void
    let onLongPressEnd: () -> Void

    @State private var isPressed = false
    @State private var longPressTriggered = false

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(isRecording ? Color.red : Color.white, lineWidth: 4)
                .frame(width: 76, height: 76)
                .scaleEffect(isRecording ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isRecording)

            // Inner circle
            Circle()
                .fill(isRecording ? Color.red : Color.white)
                .frame(width: isRecording ? 30 : 62, height: isRecording ? 30 : 62)
                .cornerRadius(isRecording ? 6 : 31)
                .animation(.easeInOut(duration: 0.2), value: isRecording)
        }
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        longPressTriggered = false

                        // Schedule long press detection
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if isPressed {
                                longPressTriggered = true
                                onLongPressStart()
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            }
                        }
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    if longPressTriggered {
                        // Was recording video, stop it
                        onLongPressEnd()
                    } else {
                        // Quick tap = photo
                        onTap()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    longPressTriggered = false
                }
        )
    }
}

#Preview {
    CameraControlsView(
        cameraService: CameraService(),
        onPhotoTaken: {},
        onVideoStart: {},
        onVideoEnd: {},
        onCameraSwitch: {}
    )
    .frame(height: 200)
    .background(Color.black)
}
