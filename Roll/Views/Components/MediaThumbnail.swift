import SwiftUI
import Photos

struct MediaThumbnail: View {
    let asset: PHAsset
    @State private var thumbnail: UIImage?
    @State private var isLoading = true
    private let thumbnailSize = CGSize(width: 200, height: 200)

    var body: some View {
        ZStack {
            Color.gray.opacity(0.2)

            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .drawingGroup() // Improves compositing performance
            } else if isLoading {
                ProgressView()
                    .tint(.gray)
            }

            if asset.mediaType == .video {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .padding(8)
                    }
                    Spacer()
                }
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, .black.opacity(0.3)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
        }
        .clipped()
        .onAppear {
            loadThumbnail()
        }
        .onDisappear {
            // Cancel in-flight requests when view disappears
            PhotoLibraryService.shared.cancelThumbnailRequest(for: asset, size: thumbnailSize)
        }
    }

    @MainActor
    private func loadThumbnail() {
        PhotoLibraryService.shared.getThumbnail(for: asset, size: thumbnailSize) { image in
            DispatchQueue.main.async {
                self.thumbnail = image
                self.isLoading = false
            }
        }
    }
}

#Preview {
    MediaThumbnail(asset: PHAsset())
        .frame(height: 150)
}
