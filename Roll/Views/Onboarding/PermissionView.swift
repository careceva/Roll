import SwiftUI

struct PermissionView: View {
    @EnvironmentObject var permissionService: PermissionService
    var onContinue: () -> Void

    @State private var allPermissionsGranted = false

    var body: some View {
        ZStack {
            // ── Shared onboarding background ──────────────────────────────
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.04, green: 0.04, blue: 0.14), location: 0),
                    .init(color: Color(red: 0.07, green: 0.04, blue: 0.18), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.blue.opacity(0.18), Color.clear],
                center: .init(x: 0.5, y: 0.2),
                startRadius: 0,
                endRadius: 220
            )
            .ignoresSafeArea()

            // ── Content ───────────────────────────────────────────────────
            VStack(spacing: 0) {
                Spacer()

                // Header
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 6) {
                        Text("Permissions")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Roll needs a few permissions to work")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Spacer().frame(height: 40)

                // Permission rows — glass cards
                VStack(spacing: 10) {
                    PermissionRow(
                        icon: "camera.fill",
                        iconColor: .blue,
                        title: "Camera",
                        description: "To capture photos and videos",
                        isGranted: permissionService.hasCameraPermission
                    )
                    PermissionRow(
                        icon: "photo.on.rectangle.fill",
                        iconColor: .purple,
                        title: "Photo Library",
                        description: "To save your photos and videos",
                        isGranted: permissionService.hasPhotoLibraryPermission
                    )
                    PermissionRow(
                        icon: "mic.fill",
                        iconColor: .cyan,
                        title: "Microphone",
                        description: "To record video with audio",
                        isGranted: permissionService.hasMicrophonePermission
                    )
                }
                .padding(.horizontal, 24)

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    Button(action: requestAllPermissions) {
                        Text("Grant Permissions")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.blue)

                    if allPermissionsGranted {
                        Button(action: onContinue) {
                            Text("Continue")
                                .font(.system(size: 17, weight: .semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(.green)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
                .animation(.spring(duration: 0.35), value: allPermissionsGranted)
            }
        }
        .onAppear {
            permissionService.checkAllPermissions()
        }
        .onChange(of: permissionService.cameraPermissionStatus)      { checkAllPermissions() }
        .onChange(of: permissionService.photoLibraryPermissionStatus) { checkAllPermissions() }
        .onChange(of: permissionService.microphonePermissionStatus)   { checkAllPermissions() }
    }

    private func requestAllPermissions() {
        Task { @MainActor in
            async let cameraTask = permissionService.requestCameraPermission()
            async let photoTask  = permissionService.requestPhotoLibraryPermission()
            async let micTask    = permissionService.requestMicrophonePermission()
            let _ = await (cameraTask, photoTask, micTask)
            checkAllPermissions()
        }
    }

    private func checkAllPermissions() {
        allPermissionsGranted =
            permissionService.hasCameraPermission &&
            permissionService.hasPhotoLibraryPermission &&
            permissionService.hasMicrophonePermission
    }
}

// MARK: - Permission Row

struct PermissionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let isGranted: Bool

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(iconColor.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            // Status indicator
            Image(systemName: isGranted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(isGranted ? .green : .white.opacity(0.35))
                .contentTransition(.symbolEffect(.replace))
        }
        .padding(14)
        // iOS 26 Liquid Glass card
        .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    PermissionView(onContinue: {})
        .environmentObject(PermissionService())
}
