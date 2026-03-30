import SwiftUI

struct PermissionView: View {
    @EnvironmentObject var permissionService: PermissionService
    var onContinue: () -> Void

    @State private var allPermissionsGranted = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Permissions")
                    .font(.system(size: 28, weight: .bold))

                Text("Roll needs a few permissions to work")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
                PermissionRow(
                    icon: "camera.fill",
                    title: "Camera",
                    description: "To capture photos and videos",
                    isGranted: permissionService.hasCameraPermission
                )

                PermissionRow(
                    icon: "photos.fill",
                    title: "Photo Library",
                    description: "To save your photos and videos",
                    isGranted: permissionService.hasPhotoLibraryPermission
                )

                PermissionRow(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "To record video with audio",
                    isGranted: permissionService.hasMicrophonePermission
                )
            }
            .padding(16)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)

            Spacer()

            VStack(spacing: 12) {
                Button(action: requestAllPermissions) {
                    Text("Grant Permissions")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                if allPermissionsGranted {
                    Button(action: onContinue) {
                        Text("Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(24)
        .onAppear {
            permissionService.checkAllPermissions()
        }
        .onChange(of: permissionService.cameraPermissionStatus) {
            checkAllPermissions()
        }
        .onChange(of: permissionService.photoLibraryPermissionStatus) {
            checkAllPermissions()
        }
        .onChange(of: permissionService.microphonePermissionStatus) {
            checkAllPermissions()
        }
    }

    private func requestAllPermissions() {
        Task {
            async let cameraTask = permissionService.requestCameraPermission()
            async let photoTask = permissionService.requestPhotoLibraryPermission()
            async let micTask = permissionService.requestMicrophonePermission()

            let _ = await (cameraTask, photoTask, micTask)
            checkAllPermissions()
        }
    }

    private func checkAllPermissions() {
        allPermissionsGranted = permissionService.hasCameraPermission &&
            permissionService.hasPhotoLibraryPermission &&
            permissionService.hasMicrophonePermission
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: isGranted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundColor(isGranted ? .green : .gray)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(10)
    }
}

#Preview {
    PermissionView(onContinue: {})
        .environmentObject(PermissionService())
}
