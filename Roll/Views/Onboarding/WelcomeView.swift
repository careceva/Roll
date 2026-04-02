import SwiftUI

struct WelcomeView: View {
    var onContinue: () -> Void

    var body: some View {
        ZStack {
            // ── iOS 26-style deep gradient background ─────────────────────
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.04, green: 0.04, blue: 0.14), location: 0),
                    .init(color: Color(red: 0.07, green: 0.04, blue: 0.18), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Subtle radial accent behind the icon
            RadialGradient(
                colors: [
                    Color.blue.opacity(0.22),
                    Color.clear,
                ],
                center: .init(x: 0.5, y: 0.22),
                startRadius: 0,
                endRadius: 260
            )
            .ignoresSafeArea()

            // ── Content ───────────────────────────────────────────────────
            VStack(spacing: 0) {
                Spacer()

                // App icon + wordmark
                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 96, height: 96)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 42, weight: .medium))
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 6) {
                        Text("Roll")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Organize before you shoot")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Spacer().frame(height: 48)

                // ── Feature cards — iOS 26 Liquid Glass ───────────────────
                VStack(spacing: 12) {
                    FeatureRow(
                        icon: "folder.badge.plus",
                        iconColor: .blue,
                        title: "Create Albums First",
                        description: "Organize photos into albums before you shoot"
                    )
                    FeatureRow(
                        icon: "camera.fill",
                        iconColor: .purple,
                        title: "Full-Screen Camera",
                        description: "Immersive, edge-to-edge capture experience"
                    )
                    FeatureRow(
                        icon: "photo.stack.fill",
                        iconColor: .cyan,
                        title: "Photos & Videos",
                        description: "Capture and organize both in one place"
                    )
                }
                .padding(.horizontal, 24)

                Spacer()

                // ── CTA ───────────────────────────────────────────────────
                Button(action: onContinue) {
                    Text("Get Started")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.blue)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(iconColor.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
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
        }
        .padding(16)
        // iOS 26 Liquid Glass card
        .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    WelcomeView(onContinue: {})
}
