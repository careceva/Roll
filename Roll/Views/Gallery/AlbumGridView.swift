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
                        ForEach(photos, id: \.localIdentifier) { asset in
                            NavigationLink(
                                destination: PhotoDetailView(assets: photos, initialAsset: asset, albumName: album.name)
                            ) {
                                PhotoThumbnail(asset: asset)
                                    .aspectRatio(1, contentMode: .fit)
                                    .clipped()
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
    }

    private func fetchPhotos() {
        PhotoLibraryService.shared.invalidateAlbumCache(for: album.name)
        photos = PhotoLibraryService.shared.fetchPhotosForAlbum(named: album.name)
    }
}

// MARK: - Photo Thumbnail

struct PhotoThumbnail: View {
    let asset: PHAsset
    @State private var image: UIImage?
    private let thumbnailSize = CGSize(width: 200, height: 200)

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(.systemGray5))

            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipped()
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
            PhotoLibraryService.shared.cancelThumbnailRequest(for: asset, size: thumbnailSize)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    @MainActor
    private func loadThumbnail() {
        PhotoLibraryService.shared.getThumbnail(for: asset, size: thumbnailSize) { thumbnail in
            DispatchQueue.main.async { self.image = thumbnail }
        }
    }
}

#Preview {
    NavigationStack {
        AlbumGridView(album: Album(name: "Test Album"))
    }
}
