import SwiftUI
import SwiftData
import Photos

struct AlbumListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Album.sortOrder) private var albums: [Album]
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @State private var showCreateAlbum = false
    @State private var newAlbumName = ""
    @State private var albumToRename: Album?
    @State private var renameText = ""

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private func syncToiCloud() {
        guard onboardingComplete else { return }
        iCloudBackupService.shared.saveAlbums(albums.map(\.name))
    }

    /// Remove SwiftData albums whose iOS Photos album no longer exists.
    private func reconcileAlbums() {
        let iOSAlbums = PhotoLibraryService.shared.fetchiOSAlbums() // [id: title]
        let iOSTitles = Set(iOSAlbums.values)

        for album in albums {
            if !iOSTitles.contains(album.name) {
                modelContext.delete(album)
            }
        }
        try? modelContext.save()
    }

    var body: some View {
        NavigationStack {
            Group {
                if albums.isEmpty {
                    // ── Empty state ───────────────────────────────────────────
                    VStack(spacing: 24) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 64, weight: .thin))
                            .foregroundStyle(.secondary)
                            .symbolEffect(.breathe)

                        VStack(spacing: 8) {
                            Text("No Albums Yet")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("Create your first album to start\norganizing photos")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        Button(action: { showCreateAlbum = true }) {
                            Label("Create Album", systemImage: "plus")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else {
                    // ── Album grid (iOS Photos style) ────────────────────────
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(albums) { album in
                                NavigationLink(destination: AlbumGridView(album: album)) {
                                    AlbumGridCard(albumName: album.name)
                                }
                                .contextMenu {
                                    Button {
                                        renameText = album.name
                                        albumToRename = album
                                    } label: {
                                        Label("Rename", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        let albumName = album.name
                                        modelContext.delete(album)
                                        try? modelContext.save()
                                        PhotoLibraryService.shared.deleteAlbum(named: albumName) { _ in }
                                    } label: {
                                        Label("Delete Album", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showCreateAlbum = true }) {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .onAppear {
            reconcileAlbums()
            syncToiCloud()
        }
        .onChange(of: albums) { _, _ in
            syncToiCloud()
        }
        .onReceive(NotificationCenter.default.publisher(for: .photoLibraryDidChange)) { _ in
            reconcileAlbums()
        }
        .alert("Rename Album", isPresented: Binding(
            get: { albumToRename != nil },
            set: { if !$0 { albumToRename = nil } }
        )) {
            TextField("Album Name", text: $renameText)
            Button("Rename") {
                guard let album = albumToRename, !renameText.isEmpty, renameText != album.name else {
                    albumToRename = nil
                    return
                }
                let oldName = album.name
                album.name = renameText
                try? modelContext.save()
                PhotoLibraryService.shared.renameAlbum(from: oldName, to: renameText) { _ in }
                albumToRename = nil
            }
            Button("Cancel", role: .cancel) { albumToRename = nil }
        }
        .alert("New Album", isPresented: $showCreateAlbum) {
            TextField("Album Name", text: $newAlbumName)
            Button("Create") {
                if !newAlbumName.isEmpty {
                    let newAlbum = Album(name: newAlbumName, sortOrder: albums.count)
                    modelContext.insert(newAlbum)
                    try? modelContext.save()
                    PhotoLibraryService.shared.createAlbum(named: newAlbumName) { _, identifier in
                        DispatchQueue.main.async {
                            newAlbum.photoLibraryIdentifier = identifier
                            try? self.modelContext.save()
                        }
                    }
                    newAlbumName = ""
                }
            }
            Button("Cancel", role: .cancel) { newAlbumName = "" }
        }
    }
}

// MARK: - Album Grid Card

/// A single album card: square thumbnail, name and count below — iOS Photos style.
struct AlbumGridCard: View {
    let albumName: String
    @State private var coverImage: UIImage?
    @State private var isEmpty = false
    @State private var photoCount = 0

    private let thumbnailRequestSize = CGSize(width: 400, height: 400)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Square thumbnail
            ZStack {
                if let coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .scaledToFill()
                } else if isEmpty {
                    Color(.systemGray6)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.system(size: 36, weight: .light))
                                .foregroundStyle(Color(.systemGray3))
                        }
                } else {
                    Color(.systemGray6)
                        .overlay {
                            ProgressView().tint(.gray)
                        }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .clipped()

            // Name + count below image
            VStack(alignment: .leading, spacing: 2) {
                Text(albumName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(photoCount == 1 ? "1 item" : "\(photoCount) items")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)
        }
        .onAppear { loadCover() }
    }

    private func loadCover() {
        let assets = PhotoLibraryService.shared.fetchPhotosForAlbum(named: albumName)
        photoCount = assets.count
        guard let firstAsset = assets.first else {
            isEmpty = true
            return
        }

        PhotoLibraryService.shared.getThumbnail(for: firstAsset, size: thumbnailRequestSize) { image in
            DispatchQueue.main.async {
                if let image {
                    coverImage = image
                } else {
                    isEmpty = true
                }
            }
        }
    }
}

#Preview {
    AlbumListView()
}
