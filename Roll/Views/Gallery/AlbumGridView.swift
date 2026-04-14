import SwiftUI
import Photos

struct AlbumGridView: View {
    @Environment(\.dismiss) private var dismiss
    let album: Album
    @State private var photos: [PHAsset] = []

    // 3 columns, 2px gaps
    let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        Group {
            if photos.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 64, weight: .thin))
                        .foregroundStyle(.secondary)
                        .symbolEffect(.breathe)
                    Text("No Photos")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Photos you take will appear here")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(Array(photos.enumerated()), id: \.element.localIdentifier) { index, asset in
                            NavigationLink(
                                destination: PhotoDetailView(assets: photos, initialAsset: asset, albumName: album.name)
                            ) {
                                PhotoThumbnail(asset: asset)
                                    .aspectRatio(1, contentMode: .fit)
                                    .clipped()
                                    .onAppear { preheatAround(index: index) }
                                    .onDisappear { cooldownAround(index: index) }
                            }
                            .id(asset.localIdentifier)
                        }
                    }
                }
            }
        }
        .navigationTitle(album.name)
        .navigationBarTitleDisplayMode(.large)
        .onAppear { fetchPhotos() }
        .onDisappear { PhotoLibraryService.shared.resetCaching() }
    }

    private func fetchPhotos() {
        PhotoLibraryService.shared.invalidateAlbumCache(for: album.name)
        photos = PhotoLibraryService.shared.fetchPhotosForAlbum(named: album.name)

        // Pre-warm the first batch (roughly 4 rows × 3 cols = 12 assets)
        let firstBatch = Array(photos.prefix(12))
        PhotoLibraryService.shared.startCaching(assets: firstBatch)
    }

    // MARK: - Pre-heating window

    /// How many rows ahead/behind to pre-fetch (3 cols per row).
    private let preheatRowCount = 5
    private var preheatWindow: Int { preheatRowCount * 3 }

    private func preheatAround(index: Int) {
        let start = max(0, index - preheatWindow)
        let end = min(photos.count, index + preheatWindow)
        guard start < end else { return }
        let window = Array(photos[start..<end])
        PhotoLibraryService.shared.startCaching(assets: window)
    }

    private func cooldownAround(index: Int) {
        // Stop caching assets that are far behind
        let coolStart = max(0, index - preheatWindow * 2)
        let coolEnd = max(0, index - preheatWindow)
        guard coolStart < coolEnd else { return }
        let window = Array(photos[coolStart..<coolEnd])
        PhotoLibraryService.shared.stopCaching(assets: window)
    }
}

// MARK: - Photo Thumbnail

struct PhotoThumbnail: View {
    let asset: PHAsset
    @State private var image: UIImage?
    @State private var isHighQuality = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(.systemGray5))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipped()
                    .opacity(isHighQuality ? 1 : 0.92)
                    .animation(.easeIn(duration: 0.15), value: isHighQuality)
            }

            if asset.mediaType == .video {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                        Spacer()
                        Text(formatDuration(asset.duration))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 5)
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .padding(.top, -20)
                    )
                }
            }
        }
        .onAppear { loadThumbnail() }
        .onDisappear {
            PhotoLibraryService.shared.cancelThumbnailRequest(for: asset)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func loadThumbnail() {
        PhotoLibraryService.shared.getThumbnail(for: asset) { thumbnail, isDegraded in
            guard let thumbnail else { return }
            self.image = thumbnail
            if !isDegraded {
                self.isHighQuality = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        AlbumGridView(album: Album(name: "Test Album"))
    }
}
