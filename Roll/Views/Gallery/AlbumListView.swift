import SwiftUI
import SwiftData
import Photos

struct AlbumListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Album.sortOrder) private var albums: [Album]
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @State private var showCreateAlbum = false
    @State private var newAlbumName = ""

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
                                    Button(role: .destructive) {
                                        let albumName = album.name
                                        // Delete from SwiftData
                                        modelContext.delete(album)
                                        try? modelContext.save()
                                        // Delete from Photos library & invalidate cache
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
                #if DEBUG
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        // Save names BEFORE deleting so Keychain backup is preserved
                        iCloudBackupService.shared.saveAlbums(albums.map(\.name))
                        for album in albums {
                            modelContext.delete(album)
                        }
                        try? modelContext.save()
                        onboardingComplete = false
                    }
                    .foregroundStyle(.red)
                }
                #endif
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

/// A single album card: large cover thumbnail with the album name overlaid at the bottom.
struct AlbumGridCard: View {
    let albumName: String
    @State private var coverImage: UIImage?
    @State private var isEmpty = false

    private let thumbnailRequestSize = CGSize(width: 400, height: 400)

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Cover image or empty placeholder
            GeometryReader { geo in
                if let coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipped()
                } else if isEmpty {
                    // Empty album: icon on light grey background
                    Color(.systemGray6)
                        .frame(width: geo.size.width, height: geo.size.width)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.system(size: 36, weight: .light))
                                .foregroundStyle(Color(.systemGray3))
                        }
                } else {
                    // Loading
                    Color(.systemGray6)
                        .frame(width: geo.size.width, height: geo.size.width)
                        .overlay {
                            ProgressView()
                                .tint(.gray)
                        }
                }
            }
            .aspectRatio(1, contentMode: .fit)

            // Album name overlay with gradient scrim
            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .center,
                endPoint: .bottom
            )

            Text(albumName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear { loadCover() }
    }

    private func loadCover() {
        let assets = PhotoLibraryService.shared.fetchPhotosForAlbum(named: albumName)
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
