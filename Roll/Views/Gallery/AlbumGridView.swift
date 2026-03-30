import SwiftUI
import Photos

struct AlbumGridView: View {
    @Environment(\.dismiss) private var dismiss
    let album: Album
    @State private var photos: [PHAsset] = []
    @State private var selectedPhoto: PHAsset?
    @State private var showPhotoDetail = false

    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack {
            if photos.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)

                    Text("No Photos")
                        .font(.headline)

                    Text("Photos you take will appear here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(photos, id: \.localIdentifier) { asset in
                            NavigationLink(destination: PhotoDetailView(assets: photos, initialAsset: asset)) {
                                PhotoThumbnail(asset: asset)
                                    .aspectRatio(1, contentMode: .fill)
                                    .clipped()
                            }
                        }
                    }
                    .padding(2)
                }
            }
        }
        .navigationTitle(album.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fetchPhotos()
        }
    }

    private func fetchPhotos() {
        photos = PhotoLibraryService.shared.fetchPhotosForAlbum(named: album.name)
    }
}

struct PhotoThumbnail: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }

            if asset.mediaType == .video {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding(8)
                    }
                    Spacer()
                }
                .padding(8)
            }
        }
        .onAppear {
            PhotoLibraryService.shared.getThumbnail(for: asset, size: CGSize(width: 150, height: 150)) { thumbnail in
                image = thumbnail
            }
        }
    }
}

#Preview {
    NavigationStack {
        AlbumGridView(album: Album(name: "Test Album"))
    }
}
