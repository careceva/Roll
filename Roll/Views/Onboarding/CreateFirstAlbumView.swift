import SwiftUI
import SwiftData

struct CreateFirstAlbumView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var albumName = "My Photos"
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Create Your First Album")
                    .font(.system(size: 28, weight: .bold))

                Text("Give your first album a name")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
                TextField("Album name", text: $albumName)
                    .textFieldStyle(.roundedBorder)
                    .font(.headline)
                    .padding(.vertical, 4)

                Text("You can create more albums anytime")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)

            Spacer()

            Button(action: createAlbum) {
                Text("Start Shooting")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(albumName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(24)
    }

    private func createAlbum() {
        let trimmedName = albumName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let newAlbum = Album(name: trimmedName, sortOrder: 0)
        modelContext.insert(newAlbum)

        do {
            try modelContext.save()
            PhotoLibraryService.shared.createAlbum(named: trimmedName) { _ in
                onComplete()
            }
        } catch {
            print("Error creating album: \(error)")
        }
    }
}

#Preview {
    CreateFirstAlbumView(onComplete: {})
}
