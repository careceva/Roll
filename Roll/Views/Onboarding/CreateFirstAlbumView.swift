import SwiftUI
import SwiftData

struct CreateFirstAlbumView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var albumName = "My Photos"
    var onComplete: () -> Void

    @FocusState private var isTextFieldFocused: Bool

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
                colors: [Color.purple.opacity(0.18), Color.clear],
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
                                    colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 6) {
                        Text("Your First Album")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Give it a name — you can add more any time")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                }

                Spacer().frame(height: 44)

                // ── Album name input — glass card ─────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    Text("Album name")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 4)

                    TextField("", text: $albumName, prompt: Text("Album name").foregroundColor(.white.opacity(0.35)))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    isTextFieldFocused
                                        ? Color.blue.opacity(0.7)
                                        : Color.white.opacity(0.12),
                                    lineWidth: 1
                                )
                        )
                        .focused($isTextFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { if !albumName.trimmingCharacters(in: .whitespaces).isEmpty { createAlbum() } }
                        .tint(.blue)

                    Text("You can create more albums from the Gallery")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.horizontal, 4)
                }
                .padding(20)
                .glassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 24)

                Spacer()

                // ── CTA ───────────────────────────────────────────────────
                Button(action: createAlbum) {
                    Text("Start Shooting")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.blue)
                .disabled(albumName.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .onTapGesture { isTextFieldFocused = false }
    }

    private func createAlbum() {
        let trimmedName = albumName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let newAlbum = Album(name: trimmedName, sortOrder: 0)
        modelContext.insert(newAlbum)

        do {
            try modelContext.save()
            PhotoLibraryService.shared.createAlbum(named: trimmedName) { _, identifier in
                // PhotoLibraryService callbacks run on a background thread —
                // always hop to main before touching SwiftUI state.
                DispatchQueue.main.async {
                    newAlbum.photoLibraryIdentifier = identifier
                    try? self.modelContext.save()
                    onComplete()
                }
            }
        } catch {
            print("Error creating album: \(error)")
        }
    }
}

#Preview {
    CreateFirstAlbumView(onComplete: {})
}
