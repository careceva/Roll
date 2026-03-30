import SwiftUI
import SwiftData

struct AlbumListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Album.sortOrder) private var albums: [Album]
    @State private var showCreateAlbum = false
    @State private var newAlbumName = ""

    var body: some View {
        NavigationStack {
            VStack {
                if albums.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No Albums")
                            .font(.headline)
                        Text("Create your first album to start organizing photos")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button(action: { showCreateAlbum = true }) {
                            Text("Create Album")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal, 40)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(albums) { album in
                            NavigationLink(destination: AlbumGridView(album: album)) {
                                HStack(spacing: 12) {
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 28))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(album.name)
                                            .font(.headline)
                                        Text("\(album.mediaItems.count) items")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                modelContext.delete(albums[index])
                            }
                            try? modelContext.save()
                        }

                        Button(action: { showCreateAlbum = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 28))
                                Text("Create Album")
                                    .font(.headline)
                                    .foregroundColor(.green)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .navigationTitle("Albums")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreateAlbum = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .alert("New Album", isPresented: $showCreateAlbum) {
            TextField("Album Name", text: $newAlbumName)
            Button("Create") {
                if !newAlbumName.isEmpty {
                    let newAlbum = Album(name: newAlbumName, sortOrder: albums.count)
                    modelContext.insert(newAlbum)
                    try? modelContext.save()
                    PhotoLibraryService.shared.createAlbum(named: newAlbumName) { _ in }
                    newAlbumName = ""
                }
            }
            Button("Cancel", role: .cancel) { newAlbumName = "" }
        }
    }
}

#Preview {
    AlbumListView()
}
