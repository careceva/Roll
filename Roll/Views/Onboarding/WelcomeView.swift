import SwiftUI

struct WelcomeView: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                VStack(spacing: 12) {
                    Text("Roll")
                        .font(.system(size: 36, weight: .bold))
                        .tracking(0.5)

                    Text("Organize before you shoot")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Create Albums First")
                            .font(.headline)
                        Text("Organize photos into albums before you shoot")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                HStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Full-Screen Camera")
                            .font(.headline)
                        Text("Immersive camera experience with edge-to-edge view")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                HStack(spacing: 16) {
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Photos & Videos")
                            .font(.headline)
                        Text("Capture and organize both photos and videos")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
            .padding(24)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(16)

            Spacer()

            Button(action: onContinue) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding(24)
    }
}

#Preview {
    WelcomeView(onContinue: {})
}
