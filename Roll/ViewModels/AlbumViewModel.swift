import Combine
import SwiftData
import Foundation

class AlbumViewModel: ObservableObject {
    @Published var albums: [Album] = []
    @Published var selectedAlbum: Album?
    @Published var isCreatingAlbum = false

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
                selectedAlbum = albums[0]
            }
        } catch {
            print("Error fetching albums: \(error)")
        }
    }

    func createAlbum(name: String) {
        let newAlbum = Album(name: name, sortOrder: albums.count)
        modelContext.insert(newAlbum)

        do {
            try modelContext.save()
            fetchAlbums()
            selectedAlbum = newAlbum
        } catch {
            print("Error creating album: \(error)")
        }

        PhotoLibraryService.shared.createAlbum(named: name) { _ in }
    }

    func deleteAlbum(_ album: Album) {
        modelContext.delete(album)
        do {
            try modelContext.save()
            fetchAlbums()
        } catch {
            print("Error deleting album: \(error)")
        }
    }

    func cycleToNextAlbum() {
        guard !albums.isEmpty else { return }

        if let currentIndex = albums.firstIndex(where: { $0.id == selectedAlbum?.id }) {
            let nextIndex = (currentIndex + 1) % albums.count
            selectedAlbum = albums[nextIndex]
        } else {
            selectedAlbum = albums[0]
        }
    }

    func cycleToPreviousAlbum() {
        guard !albums.isEmpty else { return }

        if let currentIndex = albums.firstIndex(where: { $0.id == selectedAlbum?.id }) {
            let nextIndex = currentIndex == 0 ? albums.count - 1 : currentIndex - 1
            selectedAlbum = albums[nextIndex]
        } else {
            selectedAlbum = albums[0]
        }
    }
}
