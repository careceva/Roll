import SwiftUI
import SwiftData

struct RestoreAlbumsView: View {
    let albumNames: [String]
    let onRestore: () -> Void
    let onFreshStart: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.14)
                .ignoresSafeArea()

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
                colors: [Color.purple.opacity(0.25), .clear],
                center: .init(x: 0.5, y: 0.2),
                startRadius: 0,
                endRadius: 280
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Icon + heading
                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple, Color.blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 96, height: 96)
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 6) {
                        Text("Welcome back")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("We found \(albumNames.count) album\(albumNames.count == 1 ? "" : "s") from your previous install.")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }

                Spacer().frame(height: 36)

                // Album list
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(albumNames, id: \.self) { name in
                            HStack(spacing: 14) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.purple)
                                    .frame(width: 28)
                                Text(name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .glassEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .frame(maxHeight: 280)

                Spacer()

                // CTAs
                VStack(spacing: 12) {
                    Button(action: onRestore) {
                        Text("Restore Albums")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.purple)

                    Button(action: onFreshStart) {
                        Text("Fresh Start")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
    }
}
