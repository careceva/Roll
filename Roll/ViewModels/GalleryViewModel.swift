import Combine
import Photos
import SwiftData

class GalleryViewModel: ObservableObject {
    @Published var albums: [Album] = []
    @Published var selectedAlbum: Album?
    @Published var albumPhotos: [PHAsset] = []

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchAlbums()
    }

    func fetchAlbums() {
        let descriptor = FetchDescriptor<Album>(
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        )
        do {
            albums = try modelContext.fetch(descriptor)
            if selectedAlbum == nil && !albums.isEmpty {
                selectAlbum(albums[0])
            }
        } catch {
            print("Error fetching albums: \(error)")
        }
    }

    func selectAlbum(_ album: Album) {
        selectedAlbum = album
        fetchAlbumPhotos(album)
    }

    func fetchAlbumPhotos(_ album: Album) {
        let photos = PhotoLibraryService.shared.fetchPhotosForAlbum(named: album.name)
        DispatchQueue.main.async {
            self.albumPhotos = photos
        }
    }

    func deleteMedia(_ asset: PHAsset) {
        PhotoLibraryService.shared.deleteAsset(asset) { _ in
            if let album = self.selectedAlbum {
                self.fetchAlbumPhotos(album)
            }
        }
    }
}
